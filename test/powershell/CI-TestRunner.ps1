#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CI/CD optimized PowerShell test runner for Zoidbot

.DESCRIPTION
    This script runs PowerShell tests in a CI/CD environment with proper
    error handling, reporting, and cross-platform support.

.PARAMETER OutputFormat
    Format for test output (Minimal, Detailed, JUnit)

.PARAMETER ExportResults
    Export test results to files

.PARAMETER CodeCoverage
    Enable code coverage analysis

.PARAMETER FailFast
    Stop on first test failure

.EXAMPLE
    .\CI-TestRunner.ps1 -OutputFormat JUnit -ExportResults -CodeCoverage

.NOTES
    Optimized for GitHub Actions and other CI/CD platforms
#>

[CmdletBinding()]
param(
    [ValidateSet('Minimal', 'Detailed', 'JUnit')]
    [string]$OutputFormat = 'JUnit',
    
    [switch]$ExportResults,
    
    [switch]$CodeCoverage,
    
    [switch]$FailFast,
    
    [string]$TestResultsPath = "test-results/powershell"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
try {
    Import-Module Pester -MinimumVersion 5.0 -Force
    Write-Host " Pester module imported successfully" -ForegroundColor Green
} catch {
    Write-Error " Failed to import Pester module: $_"
    exit 1
}

# Create test results directory
if ($ExportResults) {
    $null = New-Item -Path $TestResultsPath -ItemType Directory -Force
    Write-Host "� Created test results directory: $TestResultsPath" -ForegroundColor Blue
}

# Configure Pester
$PesterConfig = New-PesterConfiguration

# Test discovery
$PesterConfig.Run.Path = @(
    "$PSScriptRoot\Deploy-Zoidbot.Tests.ps1",
    "$PSScriptRoot\BuildEnvironmentUtilities.Tests.ps1",
    "$PSScriptRoot\Integration\"
)

# Output configuration
$PesterConfig.Output.Verbosity = if ($OutputFormat -eq 'Detailed') { 'Detailed' } else { 'Normal' }
$PesterConfig.Run.PassThru = $true

# Fail fast configuration
if ($FailFast) {
    $PesterConfig.Run.Exit = $true
}

# Test results export
if ($ExportResults) {
    switch ($OutputFormat) {
        'JUnit' {
            $PesterConfig.TestResult.Enabled = $true
            $PesterConfig.TestResult.OutputFormat = 'JUnitXml'
            $PesterConfig.TestResult.OutputPath = "$TestResultsPath\pester-results.xml"
        }
        'Detailed' {
            $PesterConfig.TestResult.Enabled = $true
            $PesterConfig.TestResult.OutputFormat = 'NUnitXml'
            $PesterConfig.TestResult.OutputPath = "$TestResultsPath\pester-results.xml"
        }
    }
}

# Code coverage configuration
if ($CodeCoverage) {
    $PesterConfig.CodeCoverage.Enabled = $true
    $PesterConfig.CodeCoverage.Path = @(
        "$PSScriptRoot\..\..\scripts\powershell\*.ps1"
    )
    if ($ExportResults) {
        $PesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
        $PesterConfig.CodeCoverage.OutputPath = "$TestResultsPath\coverage.xml"
    }
}

# Run tests
Write-Host " Starting PowerShell tests..." -ForegroundColor Yellow
Write-Host " Configuration:" -ForegroundColor Blue
Write-Host "   - Output Format: $OutputFormat" -ForegroundColor Gray
Write-Host "   - Export Results: $ExportResults" -ForegroundColor Gray
Write-Host "   - Code Coverage: $CodeCoverage" -ForegroundColor Gray
Write-Host "   - Fail Fast: $FailFast" -ForegroundColor Gray

try {
    $TestResults = Invoke-Pester -Configuration $PesterConfig
    
    # Display results summary
    Write-Host "`n� Test Results Summary:" -ForegroundColor Blue
    Write-Host "   - Total Tests: $($TestResults.TotalCount)" -ForegroundColor Gray
    Write-Host "   - Passed: $($TestResults.PassedCount)" -ForegroundColor Green
    Write-Host "   - Failed: $($TestResults.FailedCount)" -ForegroundColor Red
    Write-Host "   - Skipped: $($TestResults.SkippedCount)" -ForegroundColor Yellow
    Write-Host "   - Duration: $($TestResults.Duration)" -ForegroundColor Gray
    
    # Code coverage summary
    if ($CodeCoverage -and $TestResults.CodeCoverage) {
        $CoveragePercent = [math]::Round($TestResults.CodeCoverage.CoveragePercent, 2)
        Write-Host "   - Code Coverage: $CoveragePercent%" -ForegroundColor Cyan
    }
    
    # Export additional CI-friendly outputs
    if ($ExportResults) {
        # Create GitHub Actions summary
        $SummaryPath = "$TestResultsPath\github-summary.md"
        @"
# PowerShell Test Results

## Summary
- **Total Tests**: $($TestResults.TotalCount)
- **Passed**: $($TestResults.PassedCount) 
- **Failed**: $($TestResults.FailedCount) 
- **Skipped**: $($TestResults.SkippedCount) ⏭
- **Duration**: $($TestResults.Duration)
$(if ($CodeCoverage -and $TestResults.CodeCoverage) { "- **Code Coverage**: $([math]::Round($TestResults.CodeCoverage.CoveragePercent, 2))%" })

## Status
$(if ($TestResults.FailedCount -eq 0) { " All tests passed!" } else { " $($TestResults.FailedCount) test(s) failed" })
"@ | Out-File -FilePath $SummaryPath -Encoding UTF8
        
        Write-Host "� GitHub summary exported to: $SummaryPath" -ForegroundColor Blue
    }
    
    # Exit with appropriate code
    if ($TestResults.FailedCount -gt 0) {
        Write-Host " Tests failed!" -ForegroundColor Red
        exit 1
    } else {
        Write-Host " All tests passed!" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Error " Test execution failed: $_"
    exit 1
}
