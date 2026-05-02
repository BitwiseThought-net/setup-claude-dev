#!/bin/bash
# shellcheck disable=SC1091

CONFIG_FILE="claude.config"
EXAMPLE_FILE="claude.config.example"
EXTENSIONS_FILE="vscode.extensions"
TEMPLATE_ALIASES="claude-dev.aliases"

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
sudo apt-get update
sudo apt-get install -y curl git jq gpg apt-transport-https gettext

# 3. Install VS Code via APT
#if ! command -v code &> /dev/null; then
if ! which code > /dev/null 2>&1; then
    echo "📦 Installing VS Code..."
    sudo apt update
    sudo apt install software-properties-common apt-transport-https wget -y
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install code -y
    code --version
else
    echo "✅ VS Code is already installed."
fi

# 4. Install VS Code Extensions from file
if [ -f "$EXTENSIONS_FILE" ]; then
    echo "🧩 Installing VS Code extensions..."
    while IFS= read -r extension || [ -n "$extension" ]; do
        [[ -z "$extension" || "$extension" =~ ^# ]] && continue
        code --install-extension "$extension" --force
    done < "$EXTENSIONS_FILE"
fi

# 5. Install Claude Code CLI
echo "📦 Installing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

# 6. Configure Claude CLI JSON
mkdir -p "$HOME/.claude"
cat <<EOF > "$HOME/.claude/config.json"
{
  "autoConnectToEditor": true,
  "defaultModel": "${LOCAL_MODEL_NAME}",
  "primaryModel": "${LOCAL_MODEL_NAME}"
}
EOF

# 7. Setup Aliases from Template
ALIAS_DEST="$HOME/.claude_aliases"
if [ -f "$TEMPLATE_ALIASES" ]; then
    echo "✍️  Generating $ALIAS_DEST from template..."
    export REMOTE_SERVER_IP REMOTE_SERVER_PORT LOCAL_API_KEY OFFICIAL_API_KEY LOCAL_MODEL_NAME
    envsubst < "$TEMPLATE_ALIASES" > "$ALIAS_DEST"
else
    echo "❌ Error: Template $TEMPLATE_ALIASES not found!"
fi

# 8. Source in .bashrc
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
echo "1. Run 'source ~/.bashrc'. (Only necessary from THIS stale window.)"
echo "2. Open your project: 'code .'"
echo "3. Start coding: 'claude-local'"
echo "4. On first run of 'claude-local', confirm 'yes' to use the custom API key."
echo "----------------------------------------------------------------------------"
