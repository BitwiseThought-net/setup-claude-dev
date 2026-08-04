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

# 7. Configure Claude CLI JSON
mkdir -p "$HOME/.claude"
cat <<EOF > "$HOME/.claude/config.json"
{
  "autoConnectToEditor": true,
  "defaultModel": "${LOCAL_MODEL_NAME}",
  "primaryModel": "${LOCAL_MODEL_NAME}"
}
EOF

cat <<EOF > "$HOME/.claude/settings.json"
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://${OLLAMA_HOST}:${OLLAMA_PORT}",
    "ANTHROPIC_AUTH_TOKEN": "ollama",
    "ANTHROPIC_API_KEY": "${API_KEY}"
  },
  "theme": "auto"
}
EOF


# 8. Setup Aliases from Template
ALIAS_DEST="$HOME/.claude_aliases"
if [ -f "$TEMPLATE_ALIASES" ]; then
    echo "✍️  Generating $ALIAS_DEST from template..."
    export REMOTE_SERVER_IP REMOTE_SERVER_PORT LOCAL_API_KEY OFFICIAL_API_KEY LOCAL_MODEL_NAME
    envsubst < "$TEMPLATE_ALIASES" > "$ALIAS_DEST"
else
    echo "❌ Error: Template $TEMPLATE_ALIASES not found!"
fi

# 9. Source in .bashrc
BASHRC="$HOME/.bashrc"
if ! grep -qF "source $ALIAS_DEST" "$BASHRC"; then
    echo -e "\n# Custom Claude Aliases\nsource $ALIAS_DEST" >> "$BASHRC"
fi

TMP_PATH='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -q "$TMP_PATH" your_file.txt; then
    echo "$TMP_PATH" >> ~/.bashrc && source ~/.bashrc
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
