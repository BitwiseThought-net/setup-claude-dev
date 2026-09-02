# setup-claude-dev-client.ps1

$ConfigFile = "claude.config"
$ExampleFile = "claude.config.example"
$ExtensionFile = "vscode.extensions"

# 1. Check for Config File
if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERROR] Error: $ConfigFile not found!" -ForegroundColor Red
    Write-Host "-------------------------------------------------------"
    Write-Host "To fix this, please do the following:"
    Write-Host "  1. Copy the example: Copy-Item $ExampleFile $ConfigFile"
    Write-Host "  2. Edit $ConfigFile with your server's IP and settings."
    Write-Host "  3. Run this script again."
    Write-Host "-------------------------------------------------------"
    exit
}

# Load Configuration (Parse the bash-style config for PS)
Get-Content $ConfigFile | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $name, $value = $_.Split('=', 2)
    $value = $value.Trim('"').Trim("'")
    Set-Variable -Name $name -Value $value -Scope Script
}

# Default REMOTE_SERVER_PROTOCOL to http (matches the typical local LAN Ollama/LiteLLM setup).
# Set REMOTE_SERVER_PROTOCOL=https in claude.config if your server is behind a TLS-terminated
# reverse proxy - otherwise you'll see "plain HTTP request was sent to HTTPS port" errors.
if (-not $REMOTE_SERVER_PROTOCOL) { $REMOTE_SERVER_PROTOCOL = "http" }

# Normalize the URL: omit the port when it's the protocol's default (80 for http, 443 for https),
# since most servers/clients treat "https://host:443" and "https://host" identically, but some
# strict reverse-proxy configs are picky about an explicitly-specified default port.
$DefaultPorts = @{ "http" = "80"; "https" = "443" }
if ($DefaultPorts[$REMOTE_SERVER_PROTOCOL] -eq $REMOTE_SERVER_PORT) {
    $RemoteServerUrl = "${REMOTE_SERVER_PROTOCOL}://${REMOTE_SERVER_IP}"
} else {
    $RemoteServerUrl = "${REMOTE_SERVER_PROTOCOL}://${REMOTE_SERVER_IP}:$REMOTE_SERVER_PORT"
}

Write-Host "[*] Starting Windows Claude Dev Setup..." -ForegroundColor Cyan

# Helper: merge updates into a JSON file without clobbering unrelated existing keys
# (supports one level of nesting, e.g. an "env" sub-object)
function Set-JsonSettings {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [hashtable]$Updates
    )

    $Dir = Split-Path $Path -Parent
    if ($Dir -and -not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }

    $existing = @{}
    if (Test-Path $Path) {
        $raw = Get-Content $Path -Raw
        if ($raw -and $raw.Trim()) {
            try {
                $parsed = $raw | ConvertFrom-Json
                foreach ($prop in $parsed.PSObject.Properties) { $existing[$prop.Name] = $prop.Value }
            } catch {
                Write-Host "[WARN] $Path has invalid JSON. Backing it up to $Path.bak and starting fresh." -ForegroundColor Yellow
                Copy-Item $Path "$Path.bak" -Force
            }
        }
    }

    foreach ($key in $Updates.Keys) {
        $newVal = $Updates[$key]
        if ($newVal -is [hashtable] -and $existing.ContainsKey($key) -and $existing[$key] -is [System.Management.Automation.PSCustomObject]) {
            $existingSub = @{}
            foreach ($prop in $existing[$key].PSObject.Properties) { $existingSub[$prop.Name] = $prop.Value }
            foreach ($subKey in $newVal.Keys) { $existingSub[$subKey] = $newVal[$subKey] }
            $existing[$key] = $existingSub
        } else {
            $existing[$key] = $newVal
        }
    }

    $existing | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding utf8
}

# 2. Install VS Code via Winget
if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing VS Code..."
    winget install -e --id Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "[OK] VS Code is already installed."
}

# 3. Install VS Code Extensions
if (Test-Path $ExtensionFile) {
    Write-Host "[*] Installing VS Code extensions..."
    Get-Content $ExtensionFile | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object {
        Write-Host "Installing: $_"
        & code --install-extension $_ --force
    }
}

# 4. Install Claude Code CLI
Write-Host "[*] Installing Claude Code CLI..."
# Using the official Windows installer method (via iwr)
irm https://claude.ai/install.ps1 | iex

# 4b. Ensure claude CLI's install directory is on PATH
$ClaudeBinDir = "$HOME\.local\bin"
if (Test-Path $ClaudeBinDir) {
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$ClaudeBinDir*") {
        Write-Host "[*] Adding $ClaudeBinDir to your User PATH..."
        $NewUserPath = if ($UserPath) { "$UserPath;$ClaudeBinDir" } else { $ClaudeBinDir }
        [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
        Write-Host "[OK] PATH updated. Restart your terminal for it to take effect everywhere."
    } else {
        Write-Host "[OK] $ClaudeBinDir is already on your User PATH."
    }
    # Also patch the current session so the rest of this script (and this window) can see it now
    if ($env:Path -notlike "*$ClaudeBinDir*") {
        $env:Path += ";$ClaudeBinDir"
    }
} else {
    Write-Host "[WARN] $ClaudeBinDir not found - claude CLI may not have installed to the expected location."
}

# 5. Configure Claude CLI JSON
$ClaudeConfigDir = "$HOME\.claude"
if (-not (Test-Path $ClaudeConfigDir)) { New-Item -ItemType Directory -Path $ClaudeConfigDir }
$ConfigJson = @{
    autoConnectToEditor = $true
    defaultModel = $LOCAL_MODEL_NAME
    primaryModel = $LOCAL_MODEL_NAME
} | ConvertTo-Json
$ConfigJson | Out-File -FilePath "$ClaudeConfigDir\config.json" -Encoding utf8

# 5b. Configure the actual Claude Code settings.json (the file Claude Code reads for env vars)
Write-Host "[*] Configuring $ClaudeConfigDir\settings.json..."
$ClaudeSettingsPath = "$ClaudeConfigDir\settings.json"
Set-JsonSettings -Path $ClaudeSettingsPath -Updates @{
    env = @{
        ANTHROPIC_BASE_URL    = $RemoteServerUrl
        ANTHROPIC_AUTH_TOKEN  = $LOCAL_API_KEY
        LITELLM_PROXY_URL     = $RemoteServerUrl
        LITELLM_PROXY_API_KEY = $LOCAL_API_KEY
    }
}

# 5c. Configure VS Code's user settings.json for the Claude Code extension
$VSCodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
Write-Host "[*] Configuring $VSCodeSettingsPath..."
Set-JsonSettings -Path $VSCodeSettingsPath -Updates @{
    "claudeCode.disableLoginPrompt" = $true
    "claudeCode.selectedModel"      = $LOCAL_MODEL_NAME
}

# 6. Setup PowerShell Profile Aliases
$ProfileDir = Split-Path $PROFILE
if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir }

$AliasContent = @"

# --- Claude Dev Aliases ---
function claude-local {
    `$env:ANTHROPIC_BASE_URL = "$RemoteServerUrl"
    `$env:ANTHROPIC_API_KEY = "$LOCAL_API_KEY"
    `$env:ANTHROPIC_MODEL = "$LOCAL_MODEL_NAME"
    Write-Host "[OK] Mode: LOCAL (Server: $REMOTE_SERVER_IP)" -ForegroundColor Green
    claude `$args
}

function claude-official {
    `$env:ANTHROPIC_BASE_URL = `$null
    `$env:ANTHROPIC_MODEL = `$null
    `$env:ANTHROPIC_API_KEY = "$OFFICIAL_API_KEY"
    Write-Host "[*] Mode: OFFICIAL (Anthropic Cloud)" -ForegroundColor Cyan
    claude `$args
}
"@

if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE }
if (-not (Select-String -Pattern "claude-local" -Path $PROFILE)) {
    Write-Host "[*] Adding aliases to PowerShell Profile..."
    $AliasContent | Out-File -FilePath $PROFILE -Append
}

Write-Host "------------------------------------------------" -ForegroundColor Green
Write-Host "[OK] Setup Complete!" -ForegroundColor Green
Write-Host "------------------------------------------------"
Write-Host "1. Restart your terminal or run: . `$PROFILE"
Write-Host "2. Start coding: claude-local"
Write-Host "------------------------------------------------"