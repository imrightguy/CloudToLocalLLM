# Zoidbot - Google Cloud Run Deployment PowerShell Script
# Windows-friendly wrapper for Cloud Run deployment
#
# Prerequisites:
# - Google Cloud SDK installed and authenticated
# - Docker Desktop installed and running
# - Git Bash or WSL available for running bash scripts
#
# Usage: .\Deploy-CloudRun.ps1 [OPTIONS]

[CmdletBinding()]
param(
    [ValidateSet('setup', 'deploy', 'health-check', 'estimate-costs')]
    [string]$Action = 'deploy',
    
    [ValidateSet('web', 'api', 'streaming', 'all')]
    [string]$Service = 'all',
    
    [string]$ProjectId = '',
    [string]$Region = 'us-central1',
    
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$BuildOnly,
    [switch]$DeployOnly,
    [switch]$Continuous,
    
    [int]$Requests = 10000,
    [int]$Duration = 200,
    [int]$Interval = 30,
    
    [ValidateSet('table', 'json', 'csv')]
    [string]$Format = 'table'
)

# Configuration
$ScriptRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$CloudRunScriptsPath = Join-Path $ScriptRoot "scripts\cloudrun"

# Colors for output
$Colors = @{
    Red = 'Red'
    Green = 'Green'
    Yellow = 'Yellow'
    Blue = 'Blue'
    Cyan = 'Cyan'
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

function Write-Header {
    param([string]$Message)
    Write-Host $Message -ForegroundColor $Colors.Cyan
}

# Help function
function Show-Help {
    @"
Zoidbot - Google Cloud Run Deployment (PowerShell)

USAGE:
    .\Deploy-CloudRun.ps1 [OPTIONS]

ACTIONS:
    setup           Run initial Google Cloud setup
    deploy          Deploy services to Cloud Run (default)
    health-check    Check service health
    estimate-costs  Estimate monthly costs

OPTIONS:
    -Service        Service to deploy: web, api, streaming, all (default: all)
    -ProjectId      Google Cloud Project ID
    -Region         Google Cloud region (default: us-central1)
    -DryRun         Show what would be done without executing
    -Verbose        Show detailed output
    -BuildOnly      Only build container images
    -DeployOnly     Only deploy (skip build)
    -Continuous     Run continuous monitoring (health-check only)
    -Requests       Monthly requests for cost estimation (default: 10000)
    -Duration       Average request duration in ms (default: 200)
    -Interval       Monitoring interval in seconds (default: 30)
    -Format         Output format: table, json, csv (default: table)

EXAMPLES:
    .\Deploy-CloudRun.ps1 -Action setup
    .\Deploy-CloudRun.ps1 -Action deploy -Service web
    .\Deploy-CloudRun.ps1 -Action health-check -Continuous
    .\Deploy-CloudRun.ps1 -Action estimate-costs -Requests 100000

PREREQUISITES:
    - Google Cloud SDK: https://cloud.google.com/sdk/docs/install
    - Docker Desktop: https://docs.docker.com/desktop/install/windows/
    - Git for Windows (includes Git Bash): https://git-scm.com/download/win

"@ | Write-Host
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $missing = @()
    
    # Check gcloud
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        $missing += "Google Cloud SDK (gcloud)"
    }
    
    # Check docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $missing += "Docker"
    }
    
    # Check bash (Git Bash or WSL)
    $bashAvailable = $false
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        $bashAvailable = $true
    } elseif (Test-Path "C:\Program Files\Git\bin\bash.exe") {
        $bashAvailable = $true
        $env:PATH += ";C:\Program Files\Git\bin"
    }
    
    if (-not $bashAvailable) {
        $missing += "Bash (Git Bash or WSL)"
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing prerequisites:"
        foreach ($item in $missing) {
            Write-Host "  - $item" -ForegroundColor Red
        }
        Write-Host ""
        Write-Info "Please install the missing prerequisites and try again."
        Write-Info "See the help output for download links."
        exit 1
    }
    
    Write-Success "Prerequisites check completed"
}

# Execute bash script
function Invoke-BashScript {
    param(
        [string]$ScriptName,
        [string[]]$Arguments = @()
    )
    
    $scriptPath = Join-Path $CloudRunScriptsPath $ScriptName
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Script not found: $scriptPath"
        exit 1
    }
    
    # Convert Windows path to Unix-style path for bash
    $unixScriptPath = $scriptPath -replace '\\', '/' -replace '^([A-Z]):', '/mnt/$1'.ToLower()
    
    # Build command
    $bashArgs = @($unixScriptPath) + $Arguments
    
    Write-Info "Executing: bash $($bashArgs -join ' ')"
    
    # Execute with bash
    & bash @bashArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Script execution failed with exit code: $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

# Setup action
function Invoke-Setup {
    Write-Header "=== Zoidbot - Google Cloud Run Setup ==="
    
    $args = @()
    if ($ProjectId) { $args += $ProjectId }
    if ($Region) { $args += $Region }
    
    Invoke-BashScript "setup-cloudrun.sh" $args
    
    Write-Success "Setup completed successfully!"
    Write-Info "Next steps:"
    Write-Host "1. Review and update: config\cloudrun\.env.cloudrun"
    Write-Host "2. Deploy services: .\Deploy-CloudRun.ps1 -Action deploy"
}

# Deploy action
function Invoke-Deploy {
    Write-Header "=== Zoidbot - Google Cloud Run Deployment ==="
    
    $args = @()
    if ($Service -ne 'all') { $args += "--service"; $args += $Service }
    if ($DryRun) { $args += "--dry-run" }
    if ($Verbose) { $args += "--verbose" }
    if ($BuildOnly) { $args += "--build-only" }
    if ($DeployOnly) { $args += "--deploy-only" }
    
    Invoke-BashScript "deploy-to-cloudrun.sh" $args
    
    if (-not $DryRun -and -not $BuildOnly) {
        Write-Success "Deployment completed successfully!"
        Write-Info "Run health check: .\Deploy-CloudRun.ps1 -Action health-check"
    }
}

# Health check action
function Invoke-HealthCheck {
    Write-Header "=== Zoidbot - Health Check ==="
    
    $args = @()
    if ($ProjectId) { $args += "--project"; $args += $ProjectId }
    if ($Region) { $args += "--region"; $args += $Region }
    if ($Continuous) { $args += "--continuous" }
    if ($Interval -ne 30) { $args += "--interval"; $args += $Interval }
    if ($Format -ne 'table') { $args += "--format"; $args += $Format }
    if ($Verbose) { $args += "--verbose" }
    
    Invoke-BashScript "health-check.sh" $args
}

# Cost estimation action
function Invoke-CostEstimation {
    Write-Header "=== Zoidbot - Cost Estimation ==="
    
    $args = @()
    if ($Requests -ne 10000) { $args += "--requests"; $args += $Requests }
    if ($Duration -ne 200) { $args += "--duration"; $args += $Duration }
    if ($Region) { $args += "--region"; $args += $Region }
    if ($Verbose) { $args += "--verbose" }
    
    Invoke-BashScript "estimate-costs.sh" $args
}

# Main function
function Main {
    if ($PSBoundParameters.ContainsKey('Help') -or $args -contains '--help' -or $args -contains '-h') {
        Show-Help
        return
    }
    
    Write-Info "Zoidbot - Google Cloud Run Deployment (PowerShell)"
    Write-Info "Action: $Action"
    
    Test-Prerequisites
    
    # Change to project root directory
    Push-Location $ScriptRoot
    
    try {
        switch ($Action) {
            'setup' { Invoke-Setup }
            'deploy' { Invoke-Deploy }
            'health-check' { Invoke-HealthCheck }
            'estimate-costs' { Invoke-CostEstimation }
            default {
                Write-Error "Unknown action: $Action"
                Show-Help
                exit 1
            }
        }
    }
    finally {
        Pop-Location
    }
}

# Run main function
Main
