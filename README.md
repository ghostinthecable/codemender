# CodeMender

**CodeMender** is an automated AI-powered tool that monitors web server error logs in real-time, detects code issues, and automatically applies fixes. Designed for Linux hosts running Apache or Nginx, CodeMender integrates with Ollama’s local AI API to suggest and apply corrections on the fly—helping keep your applications running smoothly with minimal downtime.

---

## 🚀 Features

- ✅ **Real-time Error Detection**  
  Monitors Apache or Nginx error logs for new issues as they occur.

- 🤖 **AI-Powered Code Fixes**  
  Sends detected errors and source code to Ollama’s local Llama 3.2 model and retrieves an auto-generated fix.

- 📅 **Automatic Backups**  
  Before applying any fix, CodeMender creates a backup of the affected file with a `.bak` extension.

- 🛡️ **Satisfaction Check**  
  Performs an AI-driven chain-of-thought validation to ensure the fix is satisfactory before applying.

- 📜 **Detailed Logs**  
  All actions are logged to `/opt/codemender/logs/codemender.log` for transparency and auditing.

---

## ⚙️ Prerequisites

To run **CodeMender**, you’ll need the following:

- Linux-based system (tested on Ubuntu 22.04+)
- `bash` shell
- `jq` installed (JSON processor)
- Apache (`/var/log/apache2/error.log`) or Nginx (`/var/log/nginx/error.log`)
- Ollama installed and running locally on `localhost:11434`
- Ollama model `llama3.2:latest` installed and available

---

## 📦 Installation

1. **Download or clone the CodeMender script**  
   Create the folder and script file:

   ```bash
   mkdir -p /opt/codemender
   nano /opt/codemender/codemender.sh
   ```

2. **Paste in the CodeMender script contents**  
   _(Refer to the `codemender.sh` script in this repo or your latest working version.)_

3. **Make the script executable:**

   ```bash
   chmod +x /opt/codemender/codemender.sh
   ```

4. **Create the logs directory:**

   ```bash
   mkdir -p /opt/codemender/logs
   ```

---

## 🚀 Usage

1. **Start CodeMender by running:**

   ```bash
   bash /opt/codemender/codemender.sh
   ```

2. **Select your web server to monitor:**

   ```
   Please select the server to monitor:
   1) Apache
   2) Nginx
   ```

3. **CodeMender in action:**

   - Detects new errors in your selected log.
   - Determines the affected file by parsing the log message and searching `/var/www/html/`.
   - Sends error details and code to Ollama’s Llama 3.2 model.
   - Retrieves corrected code (clean output—no explanations or markdown).
   - Validates the fix through an AI satisfaction check.
   - Creates a backup (`.bak` extension) of the affected file.
   - Applies the validated fix.

---

## 📂 Logs

- CodeMender maintains detailed logs in:
  ```
  /opt/codemender/logs/codemender.log
  ```

- These logs include:
  - Timestamps for each action
  - Redacted error summaries
  - AI interaction (input/output redacted where necessary)
  - File modification events (backups, fixes)

---

## ✅ Example Workflow (Demo Output)

```plaintext
Monitoring log file for errors...
Error detected
Sending to AI
Received fix
Applying fix
Applied fix
```

The actual file paths and sensitive data are hidden from public display during live runs, but everything is logged in detail within `codemender.log`.

---

## 🛠️ Customisation

### Change the AI Model
Modify the `send_to_api()` function in `codemender.sh` if you want to:
- Change the AI model (e.g. `llama3.2:latest`)
- Use another endpoint from Ollama if needed

### Adjust the File Search Directory
The script currently scans `/var/www/html/` for matching files.  
You can adjust this path in the `find_candidate_file()` function.

### Run as a Service
If you want CodeMender to run continuously on startup, consider creating a `systemd` service.

---

## 🧰️ Troubleshooting

- **No Fix Applied?**
  - Ensure Ollama is running:
    ```bash
    ollama serve
    ```
  - Verify the model is available:
    ```bash
    ollama list
    ```

- **jq Not Found?**  
  Install it via:
  ```bash
  sudo apt-get install jq
  ```

- **No Errors Detected?**
  - Confirm the Apache/Nginx error logs are generating new errors.
  - Double-check log paths and permissions.

---

## 📜 License

MIT License.  
Free to use, modify, and distribute. Attribution appreciated but not required.

---

## 👨‍💻 Author

**Daniel Ward**  
[@ghostinthecable](https://github.com/ghostinthecable) // X: [@ghostinthecable](https://x.com/ghostinthecable)  
Built with ❤️ to keep your code running, error-free.

---

## 🌐 Links

- [Ollama](https://ollama.ai/)
- [jq](https://stedolan.github.io/jq/)

