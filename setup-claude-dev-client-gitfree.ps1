# setup-claude-dev-client.ps1

$ConfigFile = "claude.config"
$ExampleFile = "https://raw.githubusercontent.com/BitwiseThought-net/setup-claude-dev/refs/heads/main/claude.config.example"

# 1. Check for Config File
if (-not (Test-Path $ConfigFile)) {
    Write-Host "❌ Error: $ConfigFile not found!" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------"
    Write-Host "To fix this, please do the following:"
    Write-Host "  1. Download $ExampleFile"
    Write-Host "  2. Rename claude.config.example to claude.config"
    Write-Host "  3. Update claude.config with the appropriate values."
    Write-Host "  4. Run this script again from the same location as claude.config."
    Write-Host "--------------------------------------------------------------------"
    exit
}

# Load Configuration (Parse the bash-style config for PS)
Get-Content $ConfigFile | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $name, $value = $_.Split('=', 2)
    $value = $value.Trim('"').Trim("'")
    Set-Variable -Name $name -Value $value -Scope Script
}

Write-Host "🚀 Starting Windows Claude Dev Setup..." -ForegroundColor Cyan

# 2. Install VS Code via Winget
if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing VS Code..."
    winget install -e --id Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "✅ VS Code is already installed."
}

# 3. Install VS Code Extensions
code --install-extension anthropic.claude-code --force
code --install-extension ms-vscode-remote.remote-ssh --force
code --install-extension ms-python.python --force

# 4. Install Claude Code CLI
Write-Host "📦 Installing Claude Code CLI..."
# Using the official Windows installer method (via iwr)
iwr -useb https://claude.ai | iex

# 5. Configure Claude CLI JSON
$ClaudeConfigDir = "$HOME\.claude"
if (-not (Test-Path $ClaudeConfigDir)) { New-Item -ItemType Directory -Path $ClaudeConfigDir }
$ConfigJson = @{
    autoConnectToEditor = $true
    defaultModel = $LOCAL_MODEL_NAME
    primaryModel = $LOCAL_MODEL_NAME
} | ConvertTo-Json
$ConfigJson | Out-File -FilePath "$ClaudeConfigDir\config.json" -Encoding utf8

# 6. Setup PowerShell Profile Aliases
$ProfileDir = Split-Path $PROFILE
if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir }

$AliasContent = @"

# --- Claude Dev Aliases ---
function claude-local {
    `$env:ANTHROPIC_BASE_URL = "http://$REMOTE_SERVER_IP:$REMOTE_SERVER_PORT"
    `$env:ANTHROPIC_API_KEY = "$LOCAL_API_KEY"
    `$env:ANTHROPIC_MODEL = "$LOCAL_MODEL_NAME"
    Write-Host "✅ Mode: LOCAL (Server: $REMOTE_SERVER_IP)" -ForegroundColor Green
    claude `$args
}

function claude-official {
    `$env:ANTHROPIC_BASE_URL = `$null
    `$env:ANTHROPIC_MODEL = `$null
    `$env:ANTHROPIC_API_KEY = "$OFFICIAL_API_KEY"
    Write-Host "🌐 Mode: OFFICIAL (Anthropic Cloud)" -ForegroundColor Cyan
    claude `$args
}
"@

if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE }
if (-not (Select-String -Pattern "claude-local" -Path $PROFILE)) {
    Write-Host "🔗 Adding aliases to PowerShell Profile..."
    $AliasContent | Out-File -FilePath $PROFILE -Append
}

Write-Host "------------------------------------------------" -ForegroundColor Green
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "------------------------------------------------"
Write-Host "1. Restart your terminal or run: . `$PROFILE"
Write-Host "2. Start coding: claude-local"
Write-Host "------------------------------------------------"
