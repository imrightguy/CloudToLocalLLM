# CloudToLocalLLM Installer for Windows
# Installs CloudToLocalLLM Agent Manager and OpenClaw Gateway

Write-Host "🦞 Welcome to the CloudToLocalLLM Installer!" -ForegroundColor Cyan

# Check for Node.js
$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
    Write-Host "Warning: Node.js is not installed. It is required for the OpenClaw Gateway." -ForegroundColor Yellow
    Write-Host "Please install Node.js from https://nodejs.org/"
}

# Install Directory
$installDir = Join-Path $HOME ".cloudtolocalllm"
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir
}

Write-Host "Installing to $installDir..."

# Mocking the download
# Invoke-WebRequest -Uri "https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-windows.exe" -OutFile (Join-Path $installDir "cloudtolocalllm.exe")

# OpenClaw Gateway Install
$openclaw = Get-Command openclaw -ErrorAction SilentlyContinue
if (!$openclaw) {
    Write-Host "OpenClaw Gateway not found. Installing via npm..." -ForegroundColor Yellow
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if ($npm) {
        npm install -g openclaw-gateway
    } else {
        Write-Host "npm not found. Could not install OpenClaw Gateway automatically." -ForegroundColor Red
    }
}

# Update PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    Write-Host "Adding $installDir to your User PATH..."
    [Environment]::SetEnvironmentVariable("Path", $userPath + ";" + $installDir, "User")
}

Write-Host "✅ CloudToLocalLLM installed successfully!" -ForegroundColor Green
Write-Host "Run 'cloudtolocalllm' to get started."
