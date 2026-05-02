# Claude-Local-Dev 🚀

**The Pitch:** Run a private, enterprise-grade AI coding assistant on your own hardware for \$0.00. This project automates the orchestration between **Claude Code** and a local **Ollama** server, providing a full VS Code-integrated environment with zero data leakage and zero API costs.

---

## 🛠️ Key Features
- **Privacy First**: Your code stays on your local network.
- **Zero API Fees**: Reroutes all Claude CLI traffic to your local GPU via LiteLLM.
- **Total Automation**: A "one-click" installer for Ubuntu that handles VS Code, system dependencies, and CLI configuration.
- **Dual Mode**: Built-in shell functions to swap between your **Local GPU** and **Anthropic Cloud** instantly.

---

## 🏗️ Project Structure
```text
.
├── .github/workflows/lint.yml    # GitHub Actions CI (ShellCheck & YAML Lint)
├── docker-compose.yml            # Server-side stack (Ollama + LiteLLM + WebUI)
├── setup-claude-dev-client.sh    # The "Zero-Touch" client installer
├── claude.config.example         # Template for your server IP and model settings
└── vscode.extensions             # List of VS Code extensions to auto-install
```

---

## 🚀 Getting Started

### 1. Server-Side (The GPU Machine)
Ensure you have Docker and the NVIDIA Container Toolkit installed.

1. Copy `docker-compose.yml` to your server.
2. Create a `.env` file based on your preferences.
3. Start the stack:
   ```bash
   docker compose up -d
   ```

### 2. Client-Side (The Dev Machine / Ubuntu VM)
1. Clone this repo to your clean Ubuntu environment.
2. Initialize your config:
   ```bash
   cp claude.config.example claude.config
   ```
3. Edit `claude.config` and set your `REMOTE_SERVER_IP`.
4. Run the automated setup:
   ```bash
   chmod +x setup-claude-dev-client.sh
   ./setup-claude-dev-client.sh
   ```
5. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

---

## ⌨️ Usage

### Switching Modes
The setup script adds two powerful functions to your bash profile:

- **`claude-local`**: Points the Claude CLI to your GPU server. Use this for unlimited, free coding.
- **`claude-official`**: Points back to Anthropic's official servers (requires a paid API key).

### VS Code Integration
1. Open your project: `code /path/to/project`
2. Open the integrated terminal (`Ctrl + ~`).
3. Run `claude-local`.
4. Claude will automatically detect VS Code and allow you to approve code changes via side-by-side diffs.

---

## 🔧 Maintenance

### Adding VS Code Extensions
Want more extensions installed by default? Just add the Extension ID (e.g., `ms-python.python`) to `vscode.extensions` and re-run the setup script.

### Updating the AI Model
Change the `LOCAL_MODEL_NAME` in your `claude.config`. The next time you run `claude-local`, it will instruct your server to pull and use the new model.

---

## 🧪 Quality Assurance
This repo is protected by GitHub Actions:
- **ShellCheck**: Validates all bash scripts for POSIX compliance and safety.
- **Super-Linter**: Validates `docker-compose.yml` and all other YAML/Markdown files.

---

## 📄 License
MIT © [Your Name/GitHub Handle]
