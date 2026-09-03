#!/bin/bash
# shellcheck disable=SC1091

OLLAMA_HOST="server.lan"
OLLAMA_PORT="11434"
API_KEY="YOUR_UNIQUE_LONG_API_KEY_HERE"

CONFIG_FILE="claude.config"
EXAMPLE_FILE="claude.config.example"
TEMPLATE_ALIASES="claude-dev.aliases"
EXTENSIONS_FILE="vscode.extensions"

CONTINUE_EXTENSION_ID="Continue.continue"
CONTINUE_CONFIG_DIR="$HOME/.continue"
CONTINUE_CONFIG_FILE="$CONTINUE_CONFIG_DIR/config.json"

# 1. Check for Config File
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: $CONFIG_FILE not found!"
    echo "-------------------------------------------------------"
    echo "To fix this, please do the following:"
    echo " 1. Copy the example: cp $EXAMPLE_FILE $CONFIG_FILE"
    echo " 2. Edit $CONFIG_FILE with your server's IP and settings."
    echo " 3. Run this script again."
    echo "-------------------------------------------------------"
    exit 1
fi

source "$CONFIG_FILE"

# Default REMOTE_SERVER_PROTOCOL to http (matches the typical local LAN Ollama/LiteLLM setup).
# Set REMOTE_SERVER_PROTOCOL=https in claude.config if your server is behind a TLS-terminated
# reverse proxy - otherwise you'll see "plain HTTP request was sent to HTTPS port" errors.
REMOTE_SERVER_PROTOCOL="${REMOTE_SERVER_PROTOCOL:-http}"

# Normalize the URL: omit the port when it's the protocol's default (80 for http, 443 for https),
# since most servers/clients treat "https://host:443" and "https://host" identically, but some
# strict reverse-proxy configs are picky about an explicitly-specified default port.
if { [ "$REMOTE_SERVER_PROTOCOL" = "http" ] && [ "$REMOTE_SERVER_PORT" = "80" ]; } || \
   { [ "$REMOTE_SERVER_PROTOCOL" = "https" ] && [ "$REMOTE_SERVER_PORT" = "443" ]; }; then
    REMOTE_SERVER_URL="${REMOTE_SERVER_PROTOCOL}://${REMOTE_SERVER_IP}"
else
    REMOTE_SERVER_URL="${REMOTE_SERVER_PROTOCOL}://${REMOTE_SERVER_IP}:${REMOTE_SERVER_PORT}"
fi

# The 'code' CLI is a Node.js wrapper that emits a harmless but noisy DEP0169
# deprecation warning (url.parse) on every invocation. Suppress it for this script.
export NODE_NO_WARNINGS=1

echo "🚀 Starting Full Automation: Claude Dev + VS Code Setup..."

# 2. System Dependencies
sudo apt-get update && sudo apt upgrade -y
sudo apt-get install -y curl git jq gpg apt-transport-https gettext

# 3. Install VS Code 
# 3.a ... via APT
#if ! command -v code &> /dev/null; then
if ! which code > /dev/null 2>&1; then
    echo "📦 Installing VS Code via apt packages..."
    sudo apt update
    sudo apt install software-properties-common apt-transport-https wget -y
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install code -y
    code --version
else
    echo "✅ VS Code is already installed!"
fi

# 3.b ...via snap (if the official apt package route failed)
if ! command -v code &> /dev/null; then
    echo "VS Code not found. Installing via Snap..."
    sudo apt install -y snapd
    sudo snap install code --classic
else
    echo "✅ VS Code is already installed!!"
fi

# 4. Install VS Code Extensions from file
if [ -f "$EXTENSIONS_FILE" ]; then
    echo "🧩 Installing VS Code extensions..."
    while IFS= read -r extension || [ -n "$extension" ]; do
        [[ -z "$extension" || "$extension" =~ ^# ]] && continue
        code --install-extension "$extension" --force
    done < "$EXTENSIONS_FILE"
fi

# 5. Configure the Continue extension to use Ollama instance
# 5.a. Verify that VS Code's command line tool is available
if ! command -v code &> /dev/null; then
    echo "Error: 'code' command line tool is not installed or not in PATH."
    exit 1
fi

# 5.b. Check if the Continue extension is in the installed list
if code --list-extensions | grep -Fqx "$CONTINUE_EXTENSION_ID"; then
echo "Configuring Continue extension..."
mkdir -p "$CONTINUE_CONFIG_DIR"
cat <<EOF > "$CONTINUE_CONFIG_FILE"
{
  "models": [
    {
      "title": "Ollama (Remote)",
      "provider": "ollama",
      "model": "llama3",
      "apiBase": "http://${OLLAMA_HOST}:${OLLAMA_PORT}"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Ollama Autocomplete (Remote)",
    "provider": "ollama",
    "model": "nomic-embed-text",
    "apiBase": "http://${OLLAMA_HOST}:${OLLAMA_PORT}"
  },
  "embeddingsProvider": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "apiBase": "http://${OLLAMA_HOST}:${OLLAMA_PORT}"
  }
}
EOF
fi

# 6. Install Claude Code CLI
echo "📦 Installing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

# 6b. Ensure claude CLI's install directory is on PATH
CLAUDE_BIN_DIR="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"
if [ -d "$CLAUDE_BIN_DIR" ]; then
    PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
    if ! grep -qF "$PATH_LINE" "$BASHRC" 2>/dev/null; then
        echo "[*] Adding $CLAUDE_BIN_DIR to PATH in $BASHRC..."
        echo "$PATH_LINE" >> "$BASHRC"
    else
        echo "[OK] $CLAUDE_BIN_DIR is already on PATH in $BASHRC."
    fi
    # Also patch the current shell so the rest of this script can see it now
    case ":$PATH:" in
        *":$CLAUDE_BIN_DIR:"*) ;;
        *) export PATH="$CLAUDE_BIN_DIR:$PATH" ;;
    esac
else
    echo "[WARN] $CLAUDE_BIN_DIR not found - claude CLI may not have installed to the expected location."
fi

# 7. Configure Claude CLI JSON
mkdir -p "$HOME/.claude"
cat <<EOF > "$HOME/.claude/config.json"
{
  "autoConnectToEditor": true,
  "defaultModel": "${LOCAL_MODEL_NAME}",
  "primaryModel": "${LOCAL_MODEL_NAME}"
}
EOF

# Helper: merge a JSON fragment into a file without clobbering unrelated existing keys.
# Uses jq's recursive merge (*) so nested objects (like "env") merge key-by-key too.
merge_json_file() {
    local path="$1"
    local fragment="$2"

    mkdir -p "$(dirname "$path")"

    local existing="{}"
    if [ -s "$path" ]; then
        if ! existing="$(jq '.' "$path" 2>/dev/null)"; then
            echo "[WARN] $path has invalid JSON. Backing it up to $path.bak and starting fresh."
            cp "$path" "$path.bak"
            existing="{}"
        fi
    fi

    jq -n --argjson existing "$existing" --argjson fragment "$fragment" '$existing * $fragment' > "${path}.tmp" && mv "${path}.tmp" "$path"
}

# 7b. Configure the actual Claude Code settings.json (the file Claude Code reads for env vars)
CLAUDE_SETTINGS_PATH="$HOME/.claude/settings.json"
echo "[*] Configuring $CLAUDE_SETTINGS_PATH..."
SETTINGS_FRAGMENT=$(jq -n \
    --arg base_url "$REMOTE_SERVER_URL" \
    --arg auth_token "$LOCAL_API_KEY" \
    '{
        env: {
            ANTHROPIC_BASE_URL: $base_url,
            ANTHROPIC_AUTH_TOKEN: $auth_token,
            LITELLM_PROXY_URL: $base_url,
            LITELLM_PROXY_API_KEY: $auth_token
        },
        theme: "auto"
    }')
merge_json_file "$CLAUDE_SETTINGS_PATH" "$SETTINGS_FRAGMENT"

# 7c. Configure VS Code's user settings.json for the Claude Code extension
VSCODE_SETTINGS_PATH="$HOME/.config/Code/User/settings.json"
echo "[*] Configuring $VSCODE_SETTINGS_PATH..."
VSCODE_FRAGMENT=$(jq -n --arg model "$LOCAL_MODEL_NAME" '{
    "claudeCode.disableLoginPrompt": true,
    "claudeCode.selectedModel": $model
}')
merge_json_file "$VSCODE_SETTINGS_PATH" "$VSCODE_FRAGMENT"


# 8. Setup Aliases from Template
ALIAS_DEST="$HOME/.claude_aliases"
if [ -f "$TEMPLATE_ALIASES" ]; then
    echo "✍️  Generating $ALIAS_DEST from template..."
    export REMOTE_SERVER_URL REMOTE_SERVER_IP REMOTE_SERVER_PORT LOCAL_API_KEY OFFICIAL_API_KEY LOCAL_MODEL_NAME
    envsubst < "$TEMPLATE_ALIASES" > "$ALIAS_DEST"
else
    echo "❌ Error: Template $TEMPLATE_ALIASES not found!"
fi

# 9. Source in .bashrc
if ! grep -qF "source $ALIAS_DEST" "$BASHRC"; then
    echo -e "\n# Custom Claude Aliases\nsource $ALIAS_DEST" >> "$BASHRC"
fi

echo "----------------------------------------------------------------------------"
echo "✅ Setup Complete!"
echo "----------------------------------------------------------------------------"
echo ". Update '~/.claude/settings.json' with the appropriate settings."
echo ". Run 'source ~/.bashrc'. (Only necessary from THIS stale window.)"
echo ". Open your project: 'code .'"
echo ". Start coding: 'claude-local'"
echo ". On first run of 'claude-local', confirm 'yes' to use the custom API key."
echo ". Replace 'llama3' and 'nomic-embed-text' in "
echo "    ~/.continue/config.json with the exact models"
echo "    you have downloaded on ${OLLAMA_HOST} ."
echo "----------------------------------------------------------------------------"
