# Claude-Local-Dev Client 🚀

Run a private, enterprise-grade AI coding assistant on your own hardware for \$0.00. This project automates the orchestration between **Claude Code** and a local **Ollama** server, providing a full VS Code-integrated environment with zero data leakage and zero API costs.

---

## 🛠️ Key Features
- **Privacy First**: Your code stays on your local network.
- **Zero API Fees**: Reroutes all Claude CLI traffic to your local GPU via LiteLLM.
- **Total Automation**: One-click installers for Ubuntu and Windows that handle VS Code, extensions, and CLI configuration.
- **Dual Mode**: Built-in functions to swap between your **Local GPU** and **Anthropic Cloud** instantly.

---

## 🏗️ Repository Structure
```text
.
├── .github/workflows/lint.yml    # CI validation (Bash, PowerShell, Markdown)
├── setup-claude-dev-client.sh    # Linux/macOS installer
├── setup-claude-dev-client.ps1   # Windows PowerShell installer
├── run-claude-dev-client.sh      # Launcher script (Linux)
├── claude-dev.aliases            # Alias template
├── claude.config.example         # Shared config template
├── vscode.extensions             # List of VS Code extensions to install
├── README.md                     # Documentation
└── LICENSE.md                    # CC BY-NC-SA 4.0 License
```

---

## 🚀 Getting Started (Ubuntu / Linux)

1. Initialize your config:
   ```bash
   cp claude.config.example claude.config
   ```
2. Edit `claude.config` and set your `REMOTE_SERVER_IP`.
3. Run the automated setup:
   ```bash
   chmod +x *.sh && ./setup-claude-dev-client.sh
   ```
4. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

---

## 🪟 Getting Started (Windows)

1. Open **PowerShell** as Administrator.
2. Copy claude.config.example to claude.config
   ```powershell
   Copy-Item claude.config.example claude.config
   ```
3. Edit `claude.config` and set your `REMOTE_SERVER_IP`.
4. Run the script setup-claude-dev-client.ps1
---

## ⌨️ Usage

The installer adds two core commands to your terminal:

- **`claude-local`**: Points the Claude CLI to your GPU server for free, local coding.
- **`claude-official`**: Points to Anthropic's official servers (requires a paid API key).

### VS Code Integration
1. Open your project: `code /path/to/project`
2. Open the integrated terminal (`Ctrl + ~`) and run `claude-local`.
3. Claude will detect VS Code and allow for side-by-side diff reviews and automated file editing.

---

## 🔧 Maintenance

- **Extensions**: Add new VS Code Extension IDs to `vscode.extensions` and re-run the setup script.
- **Models**: Update `LOCAL_MODEL_NAME` in `claude.config` to change your local AI engine.

---

## 🧪 Quality Assurance
This repo uses **GitHub Actions** to maintain code health:
- **ShellCheck**: Validates bash script safety and portability.
- **PSScriptAnalyzer**: Validates PowerShell script quality.
- **Super-Linter**: Validates Markdown formatting and YAML syntax.

---

## 📄 License
This work is licensed under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](LICENSE.md).

