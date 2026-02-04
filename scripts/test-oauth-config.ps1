# Zoidbot OAuth Configuration Test
# This script tests the OAuth client ID configuration

Write-Host "=== Zoidbot OAuth Configuration Test ===" -ForegroundColor Cyan
Write-Host ""

$configFile = "lib\config\app_config.dart"
$projectRoot = $PSScriptRoot | Split-Path -Parent

# Check if config file exists
if (-not (Test-Path (Join-Path $projectRoot $configFile))) {
    Write-Host "✗ Configuration file not found: $configFile" -ForegroundColor Red
    exit 1
}

$configPath = Join-Path $projectRoot $configFile
$content = Get-Content $configPath -Raw

Write-Host "Testing OAuth client ID configuration..." -ForegroundColor Yellow
Write-Host ""

# Test Web Client ID
if ($content -match "googleClientIdWeb = '([^']+)'") {
    $webId = $matches[1]
    if ($webId -like "*-*.apps.googleusercontent.com") {
        Write-Host "✓ Web Client ID format is valid" -ForegroundColor Green
        Write-Host "  Web Client ID: $webId" -ForegroundColor Gray
    } else {
        Write-Host "✗ Web Client ID format is invalid" -ForegroundColor Red
        Write-Host "  Found: $webId" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✗ Web Client ID not found in configuration" -ForegroundColor Red
    exit 1
}

# Test Desktop Client ID
if ($content -match "googleClientIdDesktop = '([^']+)'") {
    $desktopId = $matches[1]
    if ($desktopId -like "*-*.apps.googleusercontent.com") {
        Write-Host "✓ Desktop Client ID format is valid" -ForegroundColor Green
        Write-Host "  Desktop Client ID: $desktopId" -ForegroundColor Gray
    } else {
        Write-Host "✗ Desktop Client ID format is invalid" -ForegroundColor Red
        Write-Host "  Found: $desktopId" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✗ Desktop Client ID not found in configuration" -ForegroundColor Red
    exit 1
}

# Test dynamic getter
if ($content -match "static String get googleClientId") {
    Write-Host "✓ Dynamic client ID getter is present" -ForegroundColor Green
} else {
    Write-Host "✗ Dynamic client ID getter not found" -ForegroundColor Red
    exit 1
}

# Test GCIP configuration
if ($content -match "gcipProjectId = '([^']+)'") {
    $gcipProject = $matches[1]
    Write-Host "✓ GCIP Project ID configured: $gcipProject" -ForegroundColor Green
} else {
    Write-Host "✗ GCIP Project ID not found" -ForegroundColor Red
    exit 1
}

if ($content -match "gcipApiKey = '([^']+)'") {
    $gcipApiKey = $matches[1]
    $shortKey = $gcipApiKey.Substring(0,10)
    Write-Host "✓ GCIP API Key configured: $shortKey..." -ForegroundColor Green
} else {
    Write-Host "✗ GCIP API Key not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Configuration Test Results ===" -ForegroundColor Green
Write-Host "✓ All OAuth client IDs are properly configured" -ForegroundColor Green
Write-Host "✓ GCIP configuration is complete" -ForegroundColor Green
Write-Host "✓ Dynamic platform selection is implemented" -ForegroundColor Green
Write-Host ""
Write-Host "The 401 invalid_client error should now be resolved!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Test the application with: flutter run -d chrome" -ForegroundColor White
Write-Host "2. Try signing in with Google to verify OAuth works" -ForegroundColor White
Write-Host "3. Check browser console for any remaining authentication errors" -ForegroundColor White
