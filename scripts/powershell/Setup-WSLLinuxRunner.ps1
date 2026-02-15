# Setup GitHub Actions Linux Runner in WSL
# This script helps set up a Linux runner in your WSL distribution

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$WslDistribution = "FedoraLinux-43",
    
    [switch]$TestOnly
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL Linux Runner Setup Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check WSL
Write-Host "Checking WSL installation..." -ForegroundColor Cyan
$wslList = wsl --list --verbose 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: WSL is not installed or not accessible" -ForegroundColor Red
    Write-Host "Install WSL: wsl --install" -ForegroundColor Yellow
    exit 1
}

Write-Host $wslList

# Detect WSL distribution
$runningDistros = wsl --list --running 2>&1 | Select-String -Pattern "^\s+\w" | ForEach-Object { $_.Line.Trim() }
if ($runningDistros) {
    Write-Host "`nRunning distributions:" -ForegroundColor Green
    $runningDistros | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    
    # Use first running distro if not specified
    if (-not $WslDistribution) {
        $WslDistribution = $runningDistros[0]
    }
} else {
    Write-Host "`nNo running WSL distributions found." -ForegroundColor Yellow
    Write-Host "Available distributions:" -ForegroundColor Yellow
    $allDistros = wsl --list 2>&1 | Select-String -Pattern "^\s+\w" | ForEach-Object { $_.Line.Trim() }
    $allDistros | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    
    if (-not $WslDistribution) {
        $WslDistribution = $allDistros[0] -replace '\s+.*$', ''
    }
}

Write-Host "`nUsing WSL distribution: $WslDistribution" -ForegroundColor Cyan

# Copy setup script to WSL
Write-Host "`nCopying setup script to WSL..." -ForegroundColor Cyan
$scriptPath = Join-Path $PSScriptRoot ".." "setup-wsl-linux-runner.sh"
$scriptPath = Resolve-Path $scriptPath

# Make script executable and copy to WSL
wsl -d $WslDistribution bash -c "chmod +x /mnt/d/dev/Zoidbot/scripts/setup-wsl-linux-runner.sh"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Instructions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run the setup script in WSL:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Run in current WSL session" -ForegroundColor Green
Write-Host "  wsl -d $WslDistribution" -ForegroundColor Cyan
Write-Host "  cd /mnt/d/dev/Zoidbot" -ForegroundColor Cyan
Write-Host "  bash scripts/setup-wsl-linux-runner.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "Option 2: Run directly from PowerShell" -ForegroundColor Green
Write-Host "  wsl -d $WslDistribution bash scripts/setup-wsl-linux-runner.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "The script will:" -ForegroundColor Yellow
Write-Host "  • Install Linux build dependencies" -ForegroundColor White
Write-Host "  • Install Flutter SDK" -ForegroundColor White
Write-Host "  • Set up GitHub Actions runner" -ForegroundColor White
Write-Host "  • Configure runner service" -ForegroundColor White
Write-Host ""
Write-Host "You'll need a runner registration token from:" -ForegroundColor Yellow
Write-Host "  https://github.com/Zoidbot-online/Zoidbot/settings/actions/runners/new" -ForegroundColor Cyan

