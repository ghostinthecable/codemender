#!/bin/bash
set -euo pipefail

#########################################
# CONFIGURATION & LOGGING SETUP
#########################################

VERBOSE=true
codemender_LOG="/opt/codemender/logs/codemender.log"
mkdir -p "$(dirname "$codemender_LOG")"

# Public output messages (minimal for demo)
public_msg() {
    echo "$@"
}

# Internal logging (records full details)
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $@" >> "$codemender_LOG"
}

# Debug output for internal logging; only minimal summary goes to stdout
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        # Write full details to log file only
        log_action "[DEBUG] $@"
    fi
}

#########################################
# PRE-REQUISITES & SERVER SELECTION
#########################################

if ! command -v jq >/dev/null 2>&1; then
    public_msg "jq is required. Please install it and try again."
    exit 1
fi
log_verbose "jq is installed."

public_msg "Please select the server to monitor:"
public_msg "1) Apache"
public_msg "2) Nginx"
read -p "Enter 1 or 2: " choice

if [ "$choice" == "1" ]; then
    LOG_FILE="/var/log/apache2/error.log"
elif [ "$choice" == "2" ]; then
    LOG_FILE="/var/log/nginx/error.log"
else
    public_msg "Invalid choice. Exiting."
    exit 1
fi
log_verbose "Selected log file: $LOG_FILE"

#########################################
# API CALL FUNCTIONS
#########################################

send_to_api() {
    local prompt="$1"
    local payload
    payload=$(jq -n \
        --arg model "llama3.2:latest" \
        --arg prompt "$prompt" \
        --argjson stream false \
        '{model: $model, prompt: $prompt, stream: $stream}')
    log_verbose "Sending payload to AI."
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" \
        http://localhost:11434/api/generate)
    log_verbose "Received AI response."
    echo "$response"
}

# extract_fix_code: removes markdown markers (```php and ```) from AI output.
extract_fix_code() {
    awk '/^```php/ {flag=1; next} /^```/ {flag=0; next} flag {print}'
}

get_fix() {
    local error_message="$1"
    local file_content="$2"
    local prompt_message="Error encountered: ${error_message}\n\nFile content:\n${file_content}\n\nPlease provide only the corrected code with no explanation or markdown formatting."
    local api_response
    api_response=$(send_to_api "$prompt_message")
    local full_fix
    full_fix=$(echo "$api_response" | jq -r '.response')
    local fix_code
    fix_code=$(echo "$full_fix" | extract_fix_code)
    if [ -z "$fix_code" ]; then
        fix_code="$full_fix"
    fi
    echo "$fix_code"
}

ai_satisfaction_check() {
    local error_message="$1"
    local file_content="$2"
    local proposed_fix="$3"
    local prompt_message="Chain-of-thought check:\nError: ${error_message}\n\nFile content:\n${file_content}\n\nProposed fix code:\n${proposed_fix}\n\nIs this fix code satisfactory? Please end your answer with 'yes' or 'no'."
    local api_response
    api_response=$(send_to_api "$prompt_message")
    local satisfaction
    satisfaction=$(echo "$api_response" | jq -r '.response')
    echo "$satisfaction"
}

#########################################
# FILE DETERMINATION FUNCTIONS
#########################################

find_candidate_file() {
    local hint="$1"
    local candidates=()
    mapfile -t candidates < <(find /var/www/html/ -type f -iname "*${hint}*")
    if [ "${#candidates[@]}" -eq 1 ]; then
        echo "${candidates[0]}"
    elif [ "${#candidates[@]}" -gt 1 ]; then
        log_verbose "Multiple candidate files for hint '$hint'."
        local candidate_list
        candidate_list=$(printf "%s\n" "${candidates[@]}")
        local prompt_message="Given the error hint '$hint' and the following candidate files:\n${candidate_list}\nPlease choose the file (provide full path) that is most likely affected."
        local api_response
        api_response=$(send_to_api "$prompt_message")
        local chosen_file
        chosen_file=$(echo "$api_response" | jq -r '.response' | tr -d '\n')
        log_verbose "AI selected file (redacted)."
        echo "$chosen_file"
    else
        echo ""
    fi
}

determine_affected_file() {
    local log_line="$1"
    local candidate
    candidate=$(echo "$log_line" | grep -o '/[^ ]*')
    if [ -n "$candidate" ]; then
        log_verbose "Extracted candidate file from log (redacted)."
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return
        fi
    fi
    local hint
    hint=$(echo "$log_line" | awk '{print $NF}')
    log_verbose "Using last word as hint (redacted)."
    if [ -f "$hint" ]; then
        echo "$hint"
        return
    fi
    local found_file
    found_file=$(find_candidate_file "$hint")
    if [ -n "$found_file" ] && [ -f "$found_file" ]; then
        echo "$found_file"
    else
        echo ""
    fi
}

#########################################
# APPLY FIX FUNCTION
#########################################

apply_fix() {
    local file_path="$1"
    local fixed_code="$2"
    if [ -f "$file_path" ]; then
        cp "$file_path" "$file_path.bak"
        log_verbose "Backup created for affected file."
        echo "$fixed_code" > "$file_path"
        log_verbose "Fix applied to affected file."
    else
        log_verbose "Affected file not found. Cannot apply fix."
    fi
}

#########################################
# MAIN LOG MONITORING LOOP
#########################################

public_msg "Monitoring log file for errors..."
log_verbose "Starting log monitoring using tail -n0 -F on log file."

tail -n0 -F "$LOG_FILE" | while read -r line; do
    # Minimal public output messages for demo purposes.
    if echo "$line" | grep -qi "error"; then
        public_msg "Error detected"
        log_action "Error detected: [redacted error details]"
        affected_file=$(determine_affected_file "$line")
        if [ -z "$affected_file" ]; then
            public_msg "No affected file determined. Skipping."
            log_action "No affected file determined for error."
            continue
        fi
        log_action "Determined affected file. [redacted]"
        file_content=$(cat "$affected_file")
        public_msg "Sending to AI"
        fix=$(get_fix "$line" "$file_content")
        public_msg "Received fix"
        log_action "Received fix for affected file. [redacted fix details]"
        satisfaction=$(ai_satisfaction_check "$line" "$file_content" "$fix")
        log_verbose "AI satisfaction check completed."
        if echo "$satisfaction" | grep -qi "no"; then
            public_msg "Fix not satisfactory. Requesting revised fix."
            log_action "Fix not satisfactory; requesting revised fix."
            fix=$(get_fix "$line" "$file_content")
            public_msg "Received revised fix"
            log_action "Received revised fix for affected file. [redacted]"
        fi
        public_msg "Applying fix"
        apply_fix "$affected_file" "$fix"
        public_msg "Applied fix"
        log_action "Applied fix to affected file."
    fi
done
