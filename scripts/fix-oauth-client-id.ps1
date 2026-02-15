# Zoidbot - Quick OAuth Client ID Fix
# This PowerShell script helps you quickly fix the OAuth client ID issue

param(
    [string]$WebClientId,
    [string]$DesktopClientId,
    [switch]$Interactive,
    [switch]$OpenBrowser
)

Write-Host "=== Zoidbot OAuth Client ID Fix ===" -ForegroundColor Cyan
Write-Host ""

$configFile = "lib\config\app_config.dart"
$projectRoot = Split-Path $PSScriptRoot -Parent

# Check if config file exists
if (-not (Test-Path (Join-Path $projectRoot $configFile))) {
    Write-Host "ERROR: Configuration file not found: $configFile" -ForegroundColor Red
    exit 1
}

# Open browser to Google Cloud Console
if ($OpenBrowser -or $Interactive) {
    Write-Host "Opening Google Cloud Console..." -ForegroundColor Yellow
    Start-Process "https://console.cloud.google.com/apis/credentials?project=zoidbot-468303"
    Write-Host ""
}

# Interactive mode to get client IDs
if ($Interactive -or (-not $WebClientId -and -not $DesktopClientId)) {
    Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "1. In the Google Cloud Console that just opened:" -ForegroundColor White
    Write-Host "   - Click '+ CREATE CREDENTIALS' > 'OAuth client ID'" -ForegroundColor Gray
    Write-Host "   - For Web: Select 'Web application', add origins:" -ForegroundColor Gray
    Write-Host "     * https://app.zoidbot.online" -ForegroundColor Gray
    Write-Host "     * http://localhost:3000" -ForegroundColor Gray
    Write-Host "   - For Desktop: Select 'Desktop application'" -ForegroundColor Gray
    Write-Host "2. Copy the client IDs and paste them below" -ForegroundColor White
    Write-Host ""

    if (-not $WebClientId) {
        $WebClientId = Read-Host "Enter Web OAuth Client ID"
    }

    if (-not $DesktopClientId) {
        $DesktopClientId = Read-Host "Enter Desktop OAuth Client ID"
    }
}

# Validate client IDs
if (-not $WebClientId -or -not $WebClientId.EndsWith(".apps.googleusercontent.com")) {
    Write-Host "ERROR: Invalid Web Client ID. Must end with .apps.googleusercontent.com" -ForegroundColor Red
    exit 1
}

if (-not $DesktopClientId -or -not $DesktopClientId.EndsWith(".apps.googleusercontent.com")) {
    Write-Host "ERROR: Invalid Desktop Client ID. Must end with .apps.googleusercontent.com" -ForegroundColor Red
    exit 1
}

# Update the configuration file
$configPath = Join-Path $projectRoot $configFile
$content = Get-Content $configPath -Raw

# Replace the client IDs
$content = $content -replace "googleClientIdWeb = '[^']*'", "googleClientIdWeb = '$WebClientId'"
$content = $content -replace "googleClientIdDesktop = '[^']*'", "googleClientIdDesktop = '$DesktopClientId'"

# Write back to file
Set-Content -Path $configPath -Value $content -NoNewline

Write-Host "✓ Configuration updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Updated client IDs:" -ForegroundColor Cyan
Write-Host "  Web: $WebClientId"
Write-Host "  Desktop: $DesktopClientId"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Rebuild your Flutter application: flutter clean; flutter pub get"
Write-Host "2. Test the authentication flow"
Write-Host "3. If still having issues, verify the OAuth consent screen is configured"
Write-Host ""
Write-Host "The 401 invalid_client error should now be resolved!" -ForegroundColor Green
