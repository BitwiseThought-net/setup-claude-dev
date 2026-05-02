# setup-claude-dev-client-gitfree.ps1

$ConfigFile = "claude.config"
$ExampleUrl = "https://githubusercontent.com"
$ExtensionUrl = "https://githubusercontent.com"
$ClaudeConfigDir = "$HOME\.claude"

# 1. Check for Local Config File
if (-not (Test-Path $ConfigFile)) {
    Write-Host "❌ Error: $ConfigFile not found!" -ForegroundColor Red
    Write-Host "-------------------------------------------------------"
    Write-Host "To fix this, please do the following:"
    Write-Host "  1. Download the template from: $ExampleUrl"
    Write-Host "  2. Save it as '$ConfigFile' in this directory."
    Write-Host "  3. Edit it with your server's IP and settings."
    Write-Host "  4. Run this script again."
    Write-Host "-------------------------------------------------------"
    exit
}

# Load Configuration (Parse the bash-style config for PS)
Get-Content $ConfigFile | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $name, $value = $_.Split('=', 2)
    $value = $value.Trim('"').Trim("'")
    Set-Variable -Name $name -Value $value -Scope Script
}

Write-Host "🚀 Starting Git-Free Windows Claude Dev Setup..." -ForegroundColor Cyan

# 2. Install VS Code via Winget
if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing VS Code..."
    winget install -e --id Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "✅ VS Code is already installed."
}

# 3. Install VS Code Extensions (Pulling remotely)
Write-Host "🧩 Fetching and Installing VS Code extensions from GitHub..." -ForegroundColor Yellow
try {
    $Extensions = Invoke-RestMethod -Uri $ExtensionUrl
    $Extensions -split "`n" | ForEach-Object {
        $ext = $_.Trim()
        if ($ext -and -not $ext.StartsWith("#")) {
            Write-Host "Installing: $ext"
            & code --install-extension $ext --force
        }
    }
} catch {
    Write-Host "⚠️  Failed to fetch extensions from GitHub" -ForegroundColor Red
}

# 4. Install Claude Code CLI
Write-Host "📦 Installing Claude Code CLI..."
iwr -useb https://claude.ai | iex

# 5. Configure Claude CLI JSON
if (-not (Test-Path $ClaudeConfigDir)) { New-Item -ItemType Directory -Path $ClaudeConfigDir -Force }
$ConfigJson = @{
    autoConnectToEditor = $true
    defaultModel = $LOCAL_MODEL_NAME
    primaryModel = $LOCAL_MODEL_NAME
} | ConvertTo-Json
$ConfigJson | Out-File -FilePath "$ClaudeConfigDir\config.json" -Encoding utf8 -Force

# 6. Setup PowerShell Profile Aliases
$ProfileDir = Split-Path $PROFILE
if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir -Force }

# Use a Template with placeholders to avoid ":" variable reference errors
$AliasTemplate = @'

# --- Claude Dev Aliases ---
function claude-local {
    $env:ANTHROPIC_BASE_URL = "http://{0}:{1}"
    $env:ANTHROPIC_API_KEY = "{2}"
    $env:ANTHROPIC_MODEL = "{3}"
    Write-Host "✅ Mode: LOCAL (Server: {0})" -ForegroundColor Green
    claude $args
}

function claude-official {
    $env:ANTHROPIC_BASE_URL = $null
    $env:ANTHROPIC_MODEL = $null
    $env:ANTHROPIC_API_KEY = "{4}"
    Write-Host "🌐 Mode: OFFICIAL (Anthropic Cloud)" -ForegroundColor Cyan
    claude $args
}
'@

# Safe Injection using the -f (format) operator
$AliasContent = $AliasTemplate -f $REMOTE_SERVER_IP, $REMOTE_SERVER_PORT, $LOCAL_API_KEY, $LOCAL_MODEL_NAME, $OFFICIAL_API_KEY

if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
if (-not (Select-String -Pattern "claude-local" -Path $PROFILE)) {
    Write-Host "🔗 Adding aliases to PowerShell Profile..."
    $AliasContent | Out-File -FilePath $PROFILE -Append -Encoding utf8
}

Write-Host "------------------------------------------------" -ForegroundColor Green
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "------------------------------------------------"
Write-Host "1. Restart your terminal or run: . `$PROFILE"
Write-Host "2. Start coding: claude-local"
Write-Host "------------------------------------------------"

