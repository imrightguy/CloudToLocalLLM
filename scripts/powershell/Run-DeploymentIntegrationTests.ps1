# Zoidbot Deployment Integration Tests Runner
# Master script to run all deployment workflow tests
#
# Version: 1.0.0
# Author: Zoidbot Development Team
# Last Updated: 2025-07-18
#
# This script implements task 12 from the automated deployment workflow specification:
# - Execute complete end-to-end deployment testing
# - Validate all error scenarios and rollback procedures
# - Test Kiro hook integration and execution
# - Perform performance optimization and final validation
# - Requirements: 1.1, 2.4, 3.4, 5.3

<#
.SYNOPSIS
    Master script to run all Zoidbot deployment workflow tests.

.DESCRIPTION
    This script orchestrates the execution of all deployment workflow tests,
    including basic functionality, error scenarios, and Kiro hook integration.

.PARAMETER TestSuite
    Test suite to run. Valid values: All, Basic, ErrorScenarios, KiroHook, Performance (default: All)

.PARAMETER Environment
    Target test environment. Valid values: Local, Staging (default: Staging)

.PARAMETER GenerateReport
    Generate a comprehensive HTML report of all test results

.PARAMETER Verbose
    Enable verbose logging output

.EXAMPLE
    .\Run-DeploymentIntegrationTests.ps1
    Run all tests in staging environment

.EXAMPLE
    .\Run-DeploymentIntegrationTests.ps1 -TestSuite Basic
    Run only basic functionality tests

.EXAMPLE
    .\Run-DeploymentIntegrationTests.ps1 -TestSuite ErrorScenarios -Environment Local
    Run error scenario tests in local environment

.NOTES
    This script is the master test runner for the Zoidbot deployment workflow.
    It orchestrates the execution of all test scripts and generates a comprehensive report.
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Test suite to run")]
    [ValidateSet('All', 'Basic', 'ErrorScenarios', 'KiroHook', 'Performance')]
    [string]$TestSuite = 'All',

    [Parameter(HelpMessage = "Target test environment")]
    [ValidateSet('Local', 'Staging')]
    [string]$Environment = 'Staging',

    [Parameter(HelpMessage = "Generate HTML report")]
    [switch]$GenerateReport,

    [Parameter(HelpMessage = "Display help information")]
    [switch]$Help
)

# Script configuration
$Script:ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$Script:LogsDir = Join-Path $Script:ProjectRoot "logs"
$Script:TestLogFile = Join-Path $Script:LogsDir "integration_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Script:ReportFile = Join-Path $Script:LogsDir "integration_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

# Test script paths
$Script:TestWorkflowScript = Join-Path $PSScriptRoot "Test-DeploymentWorkflow.ps1"
$Script:TestErrorScenariosScript = Join-Path $PSScriptRoot "Test-DeploymentErrorScenarios.ps1"
$Script:TestKiroHookScript = Join-Path $PSScriptRoot "Test-KiroHookIntegration.ps1"

# Test results tracking
$Script:TestResults = @{
    StartTime = Get-Date
    EndTime = $null
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Warnings = 0
    TestSuites = @()
}

# Ensure logs directory exists
if (-not (Test-Path $Script:LogsDir)) {
    New-Item -ItemType Directory -Path $Script:LogsDir -Force | Out-Null
}

# Initialize test log file
"Zoidbot Deployment Integration Tests - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $Script:TestLogFile -Encoding utf8
"Test Suite: $TestSuite" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
"Environment: $Environment" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
"=" * 80 | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append

# Logging functions
function Write-TestLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'TestSuite', 'Result')]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Add to log file
    $logMessage | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    
    # Output with appropriate formatting and colors
    switch ($Level) {
        'Info' { 
            Write-Host $Message -ForegroundColor White
        }
        'Success' { 
            Write-Host $Message -ForegroundColor Green
        }
        'Warning' { 
            Write-Host $Message -ForegroundColor Yellow
            $Script:TestResults.Warnings++
        }
        'Error' { 
            Write-Host $Message -ForegroundColor Red
        }
        'TestSuite' {
            Write-Host "`n=== TEST SUITE: $Message ===" -ForegroundColor Magenta
            $Script:TestResults.TestSuites += $Message
        }
        'Result' {
            if ($Message -match "^PASS") {
                Write-Host $Message -ForegroundColor Green
                $Script:TestResults.PassedTests++
                $Script:TestResults.TotalTests++
            } elseif ($Message -match "^FAIL") {
                Write-Host $Message -ForegroundColor Red
                $Script:TestResults.FailedTests++
                $Script:TestResults.TotalTests++
            }
        }
    }
}

# Run basic workflow tests
function Run-BasicWorkflowTests {
    Write-TestLog -Level TestSuite -Message "Basic Workflow Tests"
    
    try {
        Write-TestLog -Level Info -Message "Running basic workflow tests..."
        
        $testParams = @{
            TestEnvironment = $Environment
            TestMode = 'Basic'
        }
        
        if ($VerbosePreference -ne 'SilentlyContinue') {
            $testParams.Add('Verbose', $true)
        }
        
        $result = & $Script:TestWorkflowScript @testParams
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-TestLog -Level Success -Message "Basic workflow tests completed successfully"
            Write-TestLog -Level Result -Message "PASS: Basic workflow tests"
            return $true
        } else {
            Write-TestLog -Level Error -Message "Basic workflow tests failed with exit code $exitCode"
            Write-TestLog -Level Result -Message "FAIL: Basic workflow tests"
            return $false
        }
    } catch {
        Write-TestLog -Level Error -Message "Exception running basic workflow tests: $($_.Exception.Message)"
        Write-TestLog -Level Result -Message "FAIL: Basic workflow tests (exception)"
        return $false
    }
}

# Run error scenario tests
function Run-ErrorScenarioTests {
    Write-TestLog -Level TestSuite -Message "Error Scenario Tests"
    
    try {
        Write-TestLog -Level Info -Message "Running error scenario tests..."
        
        $testParams = @{
            TestMode = 'All'
        }
        
        if ($VerbosePreference -ne 'SilentlyContinue') {
            $testParams.Add('Verbose', $true)
        }
        
        $result = & $Script:TestErrorScenariosScript @testParams
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-TestLog -Level Success -Message "Error scenario tests completed successfully"
            Write-TestLog -Level Result -Message "PASS: Error scenario tests"
            return $true
        } else {
            Write-TestLog -Level Error -Message "Error scenario tests failed with exit code $exitCode"
            Write-TestLog -Level Result -Message "FAIL: Error scenario tests"
            return $false
        }
    } catch {
        Write-TestLog -Level Error -Message "Exception running error scenario tests: $($_.Exception.Message)"
        Write-TestLog -Level Result -Message "FAIL: Error scenario tests (exception)"
        return $false
    }
}

# Run Kiro hook integration tests
function Run-KiroHookTests {
    Write-TestLog -Level TestSuite -Message "Kiro Hook Integration Tests"
    
    try {
        Write-TestLog -Level Info -Message "Running Kiro hook integration tests..."
        
        $testParams = @{
            CreateHook = $true
            TestHookExecution = $true
        }
        
        if ($VerbosePreference -ne 'SilentlyContinue') {
            $testParams.Add('Verbose', $true)
        }
        
        $result = & $Script:TestKiroHookScript @testParams
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-TestLog -Level Success -Message "Kiro hook integration tests completed successfully"
            Write-TestLog -Level Result -Message "PASS: Kiro hook integration tests"
            return $true
        } else {
            Write-TestLog -Level Error -Message "Kiro hook integration tests failed with exit code $exitCode"
            Write-TestLog -Level Result -Message "FAIL: Kiro hook integration tests"
            return $false
        }
    } catch {
        Write-TestLog -Level Error -Message "Exception running Kiro hook integration tests: $($_.Exception.Message)"
        Write-TestLog -Level Result -Message "FAIL: Kiro hook integration tests (exception)"
        return $false
    }
}

# Run performance tests
function Run-PerformanceTests {
    Write-TestLog -Level TestSuite -Message "Performance Tests"
    
    try {
        Write-TestLog -Level Info -Message "Running performance tests..."
        
        $testParams = @{
            TestEnvironment = $Environment
            TestMode = 'Full'
        }
        
        if ($VerbosePreference -ne 'SilentlyContinue') {
            $testParams.Add('Verbose', $true)
        }
        
        # Measure execution time
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $result = & $Script:TestWorkflowScript @testParams
        $exitCode = $LASTEXITCODE
        
        $stopwatch.Stop()
        $executionTime = $stopwatch.Elapsed.TotalSeconds
        
        Write-TestLog -Level Info -Message "Performance test execution time: $executionTime seconds"
        
        if ($exitCode -eq 0) {
            Write-TestLog -Level Success -Message "Performance tests completed successfully"
            Write-TestLog -Level Result -Message "PASS: Performance tests"
            return $true
        } else {
            Write-TestLog -Level Error -Message "Performance tests failed with exit code $exitCode"
            Write-TestLog -Level Result -Message "FAIL: Performance tests"
            return $false
        }
    } catch {
        Write-TestLog -Level Error -Message "Exception running performance tests: $($_.Exception.Message)"
        Write-TestLog -Level Result -Message "FAIL: Performance tests (exception)"
        return $false
    }
}

# Generate HTML report
function Generate-HTMLReport {
    Write-TestLog -Level Info -Message "Generating HTML report..."
    
    $Script:TestResults.EndTime = Get-Date
    $duration = $Script:TestResults.EndTime - $Script:TestResults.StartTime
    $durationFormatted = "{0:hh\:mm\:ss}" -f $duration
    
    $passRate = if ($Script:TestResults.TotalTests -gt 0) {
        [math]::Round(($Script:TestResults.PassedTests / $Script:TestResults.TotalTests) * 100, 2)
    } else {
        0
    }
    
    $reportContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zoidbot Deployment Integration Test Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        h1, h2, h3 {
            color: #0066cc;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background-color: #f5f5f5;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .summary {
            display: flex;
            justify-content: space-between;
            margin-bottom: 20px;
        }
        .summary-box {
            background-color: #f9f9f9;
            border-radius: 5px;
            padding: 15px;
            width: 23%;
            text-align: center;
        }
        .pass {
            background-color: #dff0d8;
            color: #3c763d;
        }
        .fail {
            background-color: #f2dede;
            color: #a94442;
        }
        .warning {
            background-color: #fcf8e3;
            color: #8a6d3b;
        }
        .info {
            background-color: #d9edf7;
            color: #31708f;
        }
        .test-suite {
            margin-bottom: 30px;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
        }
        .test-suite h3 {
            margin-top: 0;
            border-bottom: 1px solid #eee;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f5f5f5;
        }
        tr:hover {
            background-color: #f9f9f9;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            font-size: 0.9em;
            color: #777;
        }
        .progress-bar {
            height: 20px;
            background-color: #f5f5f5;
            border-radius: 10px;
            margin-bottom: 20px;
            overflow: hidden;
        }
        .progress {
            height: 100%;
            background-color: #5cb85c;
            text-align: center;
            line-height: 20px;
            color: white;
            width: $passRate%;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Zoidbot Deployment Integration Test Report</h1>
            <p>Generated: $($Script:TestResults.EndTime.ToString("yyyy-MM-dd HH:mm:ss"))</p>
            <p>Test Suite: $TestSuite</p>
            <p>Environment: $Environment</p>
            <p>Duration: $durationFormatted</p>
        </div>
        
        <div class="progress-bar">
            <div class="progress">$passRate%</div>
        </div>
        
        <div class="summary">
            <div class="summary-box info">
                <h3>Total Tests</h3>
                <p>$($Script:TestResults.TotalTests)</p>
            </div>
            <div class="summary-box pass">
                <h3>Passed</h3>
                <p>$($Script:TestResults.PassedTests)</p>
            </div>
            <div class="summary-box fail">
                <h3>Failed</h3>
                <p>$($Script:TestResults.FailedTests)</p>
            </div>
            <div class="summary-box warning">
                <h3>Warnings</h3>
                <p>$($Script:TestResults.Warnings)</p>
            </div>
        </div>
        
        <h2>Test Suites</h2>
"@

    # Add test suite sections
    foreach ($testSuite in $Script:TestResults.TestSuites) {
        $reportContent += @"
        <div class="test-suite">
            <h3>$testSuite</h3>
            <p>See detailed logs for test case results.</p>
        </div>
"@
    }

    # Add log file reference
    $reportContent += @"
        <h2>Log Files</h2>
        <table>
            <tr>
                <th>Log Type</th>
                <th>Path</th>
            </tr>
            <tr>
                <td>Master Integration Test Log</td>
                <td>$Script:TestLogFile</td>
            </tr>
        </table>
        
        <div class="footer">
            <p>Zoidbot Deployment Integration Tests</p>
            <p>© $(Get-Date -Format "yyyy") Zoidbot Development Team</p>
        </div>
    </div>
</body>
</html>
"@

    # Write report to file
    Set-Content -Path $Script:ReportFile -Value $reportContent -Encoding UTF8
    
    Write-TestLog -Level Success -Message "HTML report generated: $Script:ReportFile"
}

# Generate test summary
function Generate-TestSummary {
    $Script:TestResults.EndTime = Get-Date
    $duration = $Script:TestResults.EndTime - $Script:TestResults.StartTime
    $durationFormatted = "{0:hh\:mm\:ss}" -f $duration
    
    $passRate = if ($Script:TestResults.TotalTests -gt 0) {
        [math]::Round(($Script:TestResults.PassedTests / $Script:TestResults.TotalTests) * 100, 2)
    } else {
        0
    }
    
    Write-Host "`n=== Zoidbot Deployment Integration Test Summary ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $($Script:TestResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "Test Suite: $TestSuite"
    Write-Host "Environment: $Environment"
    Write-Host "Duration: $durationFormatted"
    Write-Host "Total Tests: $($Script:TestResults.TotalTests)"
    Write-Host "Passed Tests: $($Script:TestResults.PassedTests)" -ForegroundColor Green
    Write-Host "Failed Tests: $($Script:TestResults.FailedTests)" -ForegroundColor Red
    Write-Host "Warnings: $($Script:TestResults.Warnings)" -ForegroundColor Yellow
    Write-Host "Pass Rate: $passRate%"
    Write-Host "Log File: $Script:TestLogFile"
    
    if ($GenerateReport) {
        Write-Host "HTML Report: $Script:ReportFile"
    }
    
    Write-Host ""
    
    # Add summary to log file
    "=== Zoidbot Deployment Integration Test Summary ===" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Timestamp: $($Script:TestResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Test Suite: $TestSuite" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Environment: $Environment" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Duration: $durationFormatted" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Total Tests: $($Script:TestResults.TotalTests)" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Passed Tests: $($Script:TestResults.PassedTests)" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Failed Tests: $($Script:TestResults.FailedTests)" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Warnings: $($Script:TestResults.Warnings)" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "Pass Rate: $passRate%" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    "" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
}

# Run all tests based on test suite
function Run-AllTests {
    Write-TestLog -Level Info -Message "Starting deployment integration tests in $TestSuite mode..."
    
    $allTestsPassed = $true
    
    # Run tests based on test suite
    switch ($TestSuite) {
        'Basic' {
            $allTestsPassed = $allTestsPassed -and (Run-BasicWorkflowTests)
        }
        'ErrorScenarios' {
            $allTestsPassed = $allTestsPassed -and (Run-ErrorScenarioTests)
        }
        'KiroHook' {
            $allTestsPassed = $allTestsPassed -and (Run-KiroHookTests)
        }
        'Performance' {
            $allTestsPassed = $allTestsPassed -and (Run-PerformanceTests)
        }
        'All' {
            $allTestsPassed = $allTestsPassed -and (Run-BasicWorkflowTests)
            $allTestsPassed = $allTestsPassed -and (Run-ErrorScenarioTests)
            $allTestsPassed = $allTestsPassed -and (Run-KiroHookTests)
            $allTestsPassed = $allTestsPassed -and (Run-PerformanceTests)
        }
    }
    
    return $allTestsPassed
}

# Main execution
if ($Help) {
    Write-Host "Zoidbot Deployment Integration Tests Runner" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Master script to run all Zoidbot deployment workflow tests."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\Run-DeploymentIntegrationTests.ps1 [Options]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TestSuite <All|Basic|ErrorScenarios|KiroHook|Performance>  Test suite to run (default: All)"
    Write-Host "  -Environment <Local|Staging>                              Target test environment (default: Staging)"
    Write-Host "  -GenerateReport                                          Generate HTML report"
    Write-Host "  -Verbose                                                 Enable verbose logging"
    Write-Host "  -Help                                                    Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\Run-DeploymentIntegrationTests.ps1                      # Run all tests"
    Write-Host "  .\Run-DeploymentIntegrationTests.ps1 -TestSuite Basic     # Run basic tests only"
    Write-Host "  .\Run-DeploymentIntegrationTests.ps1 -GenerateReport      # Run all tests and generate HTML report"
    Write-Host ""
    exit 0
}

try {
    Write-Host "=== Zoidbot Deployment Integration Tests ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Test Suite: $TestSuite"
    Write-Host "Environment: $Environment"
    Write-Host ""
    
    # Verify test scripts exist
    $missingScripts = @()
    
    if (-not (Test-Path $Script:TestWorkflowScript)) {
        $missingScripts += "Test-DeploymentWorkflow.ps1"
    }
    
    if (-not (Test-Path $Script:TestErrorScenariosScript)) {
        $missingScripts += "Test-DeploymentErrorScenarios.ps1"
    }
    
    if (-not (Test-Path $Script:TestKiroHookScript)) {
        $missingScripts += "Test-KiroHookIntegration.ps1"
    }
    
    if ($missingScripts.Count -gt 0) {
        Write-TestLog -Level Error -Message "Missing test scripts: $($missingScripts -join ', ')"
        Write-TestLog -Level Error -Message "Please ensure all test scripts are in the same directory as this script"
        exit 1
    }
    
    # Run all tests
    $allTestsPassed = Run-AllTests
    
    # Generate test summary
    Generate-TestSummary
    
    # Generate HTML report if requested
    if ($GenerateReport) {
        Generate-HTMLReport
    }
    
    # Exit with appropriate code
    if ($allTestsPassed) {
        Write-Host "All tests completed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Some tests failed. See summary and logs for details." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    "FATAL ERROR: $($_.Exception.Message)" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    exit 1
}