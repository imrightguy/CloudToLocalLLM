#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates the Zoidbot CI/CD pipeline setup

.DESCRIPTION
    This script validates that all components of the CI/CD pipeline are properly
    configured and can execute successfully. It checks test configurations,
    dependencies, and pipeline components.

.PARAMETER Verbose
    Enable verbose output for detailed validation information

.PARAMETER FixIssues
    Attempt to automatically fix common issues

.EXAMPLE
    .\validate-cicd-setup.ps1
    Run basic validation

.EXAMPLE
    .\validate-cicd-setup.ps1 -Verbose -FixIssues
    Run detailed validation and fix issues

.NOTES
    This script should be run before committing CI/CD changes to ensure
    the pipeline will work correctly.
#>

[CmdletBinding()]
param(
    [switch]$DetailedOutput,
    [switch]$FixIssues
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Continue on errors to show all issues

# Script metadata
$ScriptVersion = "1.0.0"
$ScriptName = "Zoidbot CI/CD Validation"

# Validation results
$ValidationResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
    Fixed = @()
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
    $ValidationResults.Passed += $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
    $ValidationResults.Warnings += $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $ValidationResults.Failed += $Message
}

function Write-Fixed {
    param([string]$Message)
    Write-Host "[FIXED] $Message" -ForegroundColor Cyan
    $ValidationResults.Fixed += $Message
}

function Write-DetailedOutput {
    param([string]$Message)
    if ($DetailedOutput) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Gray
    }
}

# Validation functions
function Test-ProjectStructure {
    Write-Info "Validating project structure..."
    
    $requiredFiles = @(
        "pubspec.yaml",
        ".github/workflows/ci-cd.yml",
        "playwright.config.js",
        "package.json",
        "test/flutter_test_config.dart",
        "test/powershell/CI-TestRunner.ps1",
        "services/api-backend/package.json",
        "services/api-backend/jest.config.js"
    )
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-DetailedOutput "Found required file: $file"
        } else {
            Write-Error "Missing required file: $file"
        }
    }
    
    $requiredDirs = @(
        "test/api-backend",
        "test/powershell",
        "test/e2e",
        "services/api-backend",
        "scripts/deploy"
    )
    
    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir -PathType Container) {
            Write-DetailedOutput "Found required directory: $dir"
        } else {
            Write-Error "Missing required directory: $dir"
        }
    }
    
    Write-Success "Project structure validation completed"
}

function Test-Dependencies {
    Write-Info "Validating dependencies..."
    
    # Check Flutter
    try {
        $flutterVersion = flutter --version 2>$null
        if ($flutterVersion) {
            Write-DetailedOutput "Flutter is available: $($flutterVersion[0])"
            Write-Success "Flutter dependency check passed"
        } else {
            Write-Error "Flutter is not available or not in PATH"
        }
    } catch {
        Write-Error "Flutter check failed: $_"
    }
    
    # Check Node.js
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-DetailedOutput "Node.js is available: $nodeVersion"
            if ([version]($nodeVersion -replace 'v', '') -ge [version]"18.0.0") {
                Write-Success "Node.js version check passed"
            } else {
                Write-Warning "Node.js version is below recommended 18.0.0"
            }
        } else {
            Write-Error "Node.js is not available or not in PATH"
        }
    } catch {
        Write-Error "Node.js check failed: $_"
    }
    
    # Check npm
    try {
        $npmVersion = npm --version 2>$null
        if ($npmVersion) {
            Write-DetailedOutput "npm is available: $npmVersion"
            Write-Success "npm dependency check passed"
        } else {
            Write-Error "npm is not available or not in PATH"
        }
    } catch {
        Write-Error "npm check failed: $_"
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion -ge [version]"7.0.0") {
        Write-Success "PowerShell version check passed: $($PSVersionTable.PSVersion)"
    } else {
        Write-Warning "PowerShell version is below recommended 7.0.0: $($PSVersionTable.PSVersion)"
    }
}

function Test-TestConfigurations {
    Write-Info "Validating test configurations..."
    
    # Validate Flutter test config
    if (Test-Path "test/flutter_test_config.dart") {
        $content = Get-Content "test/flutter_test_config.dart" -Raw
        if ($content -match "testExecutable" -and $content -match "TestWidgetsFlutterBinding") {
            Write-Success "Flutter test configuration is valid"
        } else {
            Write-Error "Flutter test configuration appears incomplete"
        }
    }
    
    # Validate Jest config
    if (Test-Path "services/api-backend/jest.config.js") {
        $content = Get-Content "services/api-backend/jest.config.js" -Raw
        if ($content -match "testEnvironment" -and $content -match "coverage") {
            Write-Success "Jest configuration is valid"
        } else {
            Write-Error "Jest configuration appears incomplete"
        }
    }
    
    # Validate Playwright config
    if (Test-Path "playwright.config.js") {
        $content = Get-Content "playwright.config.js" -Raw
        if ($content -match "testDir" -and $content -match "reporter") {
            Write-Success "Playwright configuration is valid"
        } else {
            Write-Error "Playwright configuration appears incomplete"
        }
    }
    
    # Validate PowerShell test runner
    if (Test-Path "test/powershell/CI-TestRunner.ps1") {
        $content = Get-Content "test/powershell/CI-TestRunner.ps1" -Raw
        if ($content -match "Pester" -and $content -match "OutputFormat") {
            Write-Success "PowerShell test runner configuration is valid"
        } else {
            Write-Error "PowerShell test runner configuration appears incomplete"
        }
    }
}

function Test-GitHubActionsWorkflow {
    Write-Info "Validating GitHub Actions workflow..."
    
    if (Test-Path ".github/workflows/ci-cd.yml") {
        $content = Get-Content ".github/workflows/ci-cd.yml" -Raw
        
        $requiredJobs = @("flutter-tests", "nodejs-tests", "powershell-tests", "playwright-tests", "test-results", "deploy")
        $missingJobs = @()
        
        foreach ($job in $requiredJobs) {
            if ($content -match "${job}:") {
                Write-DetailedOutput "Found required job: $job"
            } else {
                $missingJobs += $job
            }
        }
        
        if ($missingJobs.Count -eq 0) {
            Write-Success "GitHub Actions workflow contains all required jobs"
        } else {
            Write-Error "GitHub Actions workflow missing jobs: $($missingJobs -join ', ')"
        }
        
        # Check for quality gates
        if ($content -match "deployment_ready" -and $content -match "critical_failures") {
            Write-Success "Quality gates are configured in workflow"
        } else {
            Write-Error "Quality gates are not properly configured"
        }
        
    } else {
        Write-Error "GitHub Actions workflow file not found"
    }
}

function Test-DeploymentScripts {
    Write-Info "Validating deployment scripts..."
    
    $deploymentScripts = @(
        "scripts/deploy/complete_deployment.sh",
        "scripts/deploy/deploy-with-tests.sh",
        "scripts/deploy/Deploy-WithTests.ps1"
    )
    
    foreach ($script in $deploymentScripts) {
        if (Test-Path $script) {
            Write-DetailedOutput "Found deployment script: $script"
            Write-Success "Deployment script exists: $script"
        } else {
            Write-Warning "Deployment script not found: $script"
        }
    }
}

function Test-PackageConfigurations {
    Write-Info "Validating package configurations..."
    
    # Check root package.json
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" | ConvertFrom-Json
        if ($packageJson.devDependencies.'@playwright/test') {
            Write-Success "Playwright dependency found in root package.json"
        } else {
            Write-Error "Playwright dependency missing from root package.json"
        }
    }
    
    # Check API backend package.json
    if (Test-Path "services/api-backend/package.json") {
        $packageJson = Get-Content "services/api-backend/package.json" | ConvertFrom-Json
        if ($packageJson.devDependencies.jest -and $packageJson.devDependencies.'jest-junit') {
            Write-Success "Jest dependencies found in API backend package.json"
        } else {
            Write-Error "Jest dependencies missing from API backend package.json"
        }
    }
    
    # Check pubspec.yaml
    if (Test-Path "pubspec.yaml") {
        $content = Get-Content "pubspec.yaml" -Raw
        if ($content -match "flutter_test:" -and $content -match "integration_test:") {
            Write-Success "Flutter test dependencies found in pubspec.yaml"
        } else {
            Write-Warning "Flutter test dependencies may be missing from pubspec.yaml"
        }
    }
}

function Invoke-AutoFix {
    if (-not $FixIssues) {
        return
    }
    
    Write-Info "Attempting to fix common issues..."
    
    # Create missing directories
    $requiredDirs = @("test-results", "test-results/powershell", "test-results/html-report")
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Fixed "Created missing directory: $dir"
            } catch {
                Write-Error "Failed to create directory ${dir}: $($_.Exception.Message)"
            }
        }
    }
    
    # Install missing PowerShell modules
    try {
        if (-not (Get-Module -ListAvailable -Name Pester)) {
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
            Write-Fixed "Installed Pester PowerShell module"
        }
    } catch {
        Write-Error "Failed to install Pester module: $($_.Exception.Message)"
    }
}

function Show-ValidationSummary {
    Write-Info "`nValidation Summary:"
    Write-Host "==================" -ForegroundColor Blue
    
    Write-Host " Passed: $($ValidationResults.Passed.Count)" -ForegroundColor Green
    Write-Host " Failed: $($ValidationResults.Failed.Count)" -ForegroundColor Red
    Write-Host "  Warnings: $($ValidationResults.Warnings.Count)" -ForegroundColor Yellow
    
    if ($FixIssues) {
        Write-Host " Fixed: $($ValidationResults.Fixed.Count)" -ForegroundColor Cyan
    }
    
    if ($ValidationResults.Failed.Count -gt 0) {
        Write-Host "`nFailed Validations:" -ForegroundColor Red
        foreach ($failure in $ValidationResults.Failed) {
            Write-Host "  - $failure" -ForegroundColor Red
        }
    }
    
    if ($ValidationResults.Warnings.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        foreach ($warning in $ValidationResults.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
    }
    
    if ($ValidationResults.Fixed.Count -gt 0) {
        Write-Host "`nFixed Issues:" -ForegroundColor Cyan
        foreach ($fix in $ValidationResults.Fixed) {
            Write-Host "  - $fix" -ForegroundColor Cyan
        }
    }
    
    # Overall status
    if ($ValidationResults.Failed.Count -eq 0) {
        Write-Host "`n� CI/CD pipeline validation PASSED!" -ForegroundColor Green
        Write-Host "The pipeline is ready for use." -ForegroundColor Green
        return $true
    } else {
        Write-Host "`n CI/CD pipeline validation FAILED!" -ForegroundColor Red
        Write-Host "Please fix the issues above before using the pipeline." -ForegroundColor Red
        return $false
    }
}

# Main execution
function Main {
    Write-Info "Starting $ScriptName v$ScriptVersion"
    Write-Info "Validating Zoidbot CI/CD pipeline setup..."
    
    # Run all validations
    Test-ProjectStructure
    Test-Dependencies
    Test-TestConfigurations
    Test-GitHubActionsWorkflow
    Test-DeploymentScripts
    Test-PackageConfigurations
    
    # Attempt fixes if requested
    Invoke-AutoFix
    
    # Show summary and return result
    $success = Show-ValidationSummary
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}

# Execute main function
Main
