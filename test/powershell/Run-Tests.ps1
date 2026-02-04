# PowerShell Test Runner for Zoidbot Deployment Scripts
# Executes Pester tests with comprehensive reporting and coverage analysis

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Specific test file to run (optional)")]
    [string]$TestFile,
    
    [Parameter(HelpMessage = "Test tag to filter by (optional)")]
    [string]$Tag,
    
    [Parameter(HelpMessage = "Generate code coverage report")]
    [switch]$CodeCoverage,
    
    [Parameter(HelpMessage = "Output format for test results")]
    [ValidateSet('Normal', 'Detailed', 'Diagnostic', 'Minimal')]
    [string]$OutputFormat = 'Detailed',
    
    [Parameter(HelpMessage = "Export test results to file")]
    [switch]$ExportResults,
    
    [Parameter(HelpMessage = "Show only failed tests")]
    [switch]$FailedOnly,
    
    [Parameter(HelpMessage = "Enable verbose test output")]
    [switch]$Verbose
)

# Ensure Pester module is available
function Install-PesterModule {
    [CmdletBinding()]
    param()
    
    Write-Host "[SETUP] Checking Pester module availability..." -ForegroundColor Cyan
    
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $pesterModule) {
        Write-Host "[SETUP] Pester module not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
            Write-Host "[SETUP] Pester module installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install Pester module: $($_.Exception.Message)"
            return $false
        }
    }
    elseif ($pesterModule.Version -lt [Version]"5.0.0") {
        Write-Host "[SETUP] Updating Pester to version 5.x..." -ForegroundColor Yellow
        try {
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
            Write-Host "[SETUP] Pester module updated successfully" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to update Pester module: $($_.Exception.Message)"
            return $false
        }
    }
    else {
        Write-Host "[SETUP] Pester module available (Version: $($pesterModule.Version))" -ForegroundColor Green
    }
    
    # Import Pester module
    try {
        Import-Module Pester -Force
        return $true
    }
    catch {
        Write-Error "Failed to import Pester module: $($_.Exception.Message)"
        return $false
    }
}

# Configure test environment
function Initialize-TestEnvironment {
    [CmdletBinding()]
    param()
    
    Write-Host "[SETUP] Initializing test environment..." -ForegroundColor Cyan
    
    # Set up test directories
    $testResultsDir = Join-Path $PSScriptRoot "..\..\test-results\powershell"
    if (-not (Test-Path $testResultsDir)) {
        New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
        Write-Host "[SETUP] Created test results directory: $testResultsDir" -ForegroundColor Green
    }
    
    # Set up coverage directory
    $coverageDir = Join-Path $PSScriptRoot "..\..\coverage\powershell"
    if (-not (Test-Path $coverageDir)) {
        New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
        Write-Host "[SETUP] Created coverage directory: $coverageDir" -ForegroundColor Green
    }
    
    # Set environment variables for tests
    $env:PESTER_TEST_MODE = "true"
    $env:PESTER_TEST_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
    
    Write-Host "[SETUP] Test environment initialized successfully" -ForegroundColor Green
    return @{
        TestResultsDir = $testResultsDir
        CoverageDir = $coverageDir
    }
}

# Get list of test files to execute
function Get-TestFiles {
    [CmdletBinding()]
    param(
        [string]$SpecificFile
    )
    
    $testDir = $PSScriptRoot
    
    if ($SpecificFile) {
        $testPath = Join-Path $testDir $SpecificFile
        if (Test-Path $testPath) {
            return @($testPath)
        }
        else {
            Write-Error "Test file not found: $testPath"
            return @()
        }
    }
    else {
        # Get all .Tests.ps1 files
        $testFiles = Get-ChildItem -Path $testDir -Filter "*.Tests.ps1" -Recurse | Select-Object -ExpandProperty FullName
        return $testFiles
    }
}

# Configure Pester settings
function Get-PesterConfiguration {
    [CmdletBinding()]
    param(
        [string[]]$TestFiles,
        [string]$OutputFormat,
        [string]$TestResultsDir,
        [string]$CoverageDir,
        [bool]$CodeCoverage,
        [bool]$ExportResults,
        [string]$Tag
    )
    
    $config = New-PesterConfiguration
    
    # Test discovery and execution
    $config.Run.Path = $TestFiles
    $config.Run.PassThru = $true
    
    # Filter by tag if specified
    if ($Tag) {
        $config.Filter.Tag = $Tag
    }
    
    # Output configuration
    switch ($OutputFormat) {
        'Minimal' { 
            $config.Output.Verbosity = 'Minimal'
        }
        'Normal' { 
            $config.Output.Verbosity = 'Normal'
        }
        'Detailed' { 
            $config.Output.Verbosity = 'Detailed'
        }
        'Diagnostic' { 
            $config.Output.Verbosity = 'Diagnostic'
        }
    }
    
    # Test results export
    if ($ExportResults) {
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = Join-Path $TestResultsDir "TestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"
    }
    
    # Code coverage configuration
    if ($CodeCoverage) {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
        $config.CodeCoverage.OutputPath = Join-Path $CoverageDir "Coverage_$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"
        
        # Include PowerShell scripts for coverage analysis
        $scriptsDir = Join-Path $PSScriptRoot "..\..\scripts\powershell"
        $config.CodeCoverage.Path = @(
            (Join-Path $scriptsDir "Deploy-Zoidbot.ps1"),
            (Join-Path $scriptsDir "BuildEnvironmentUtilities.ps1")
        )
    }
    
    return $config
}

# Display test summary
function Show-TestSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TestResult,
        
        [bool]$FailedOnly
    )
    
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "TEST EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    # Overall statistics
    Write-Host "Total Tests: $($TestResult.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($TestResult.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($TestResult.FailedCount)" -ForegroundColor Red
    Write-Host "Skipped: $($TestResult.SkippedCount)" -ForegroundColor Yellow
    Write-Host "Duration: $($TestResult.Duration.ToString('mm\:ss\.fff'))" -ForegroundColor White
    
    # Test containers summary
    if ($TestResult.Containers) {
        Write-Host ""
        Write-Host "TEST CONTAINERS:" -ForegroundColor Cyan
        foreach ($container in $TestResult.Containers) {
            $status = if ($container.Passed) { "PASSED" } else { "FAILED" }
            $color = if ($container.Passed) { "Green" } else { "Red" }
            Write-Host "  [$status] $($container.Name) ($($container.Tests.Count) tests)" -ForegroundColor $color
        }
    }
    
    # Failed tests details
    if ($TestResult.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "FAILED TESTS:" -ForegroundColor Red
        $failedTests = $TestResult.Tests | Where-Object { $_.Result -eq 'Failed' }
        foreach ($test in $failedTests) {
            Write-Host "  [FAILED] $($test.ExpandedName)" -ForegroundColor Red
            if ($test.ErrorRecord) {
                Write-Host "    Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            }
        }
    }
    
    # Show only failed tests if requested
    if ($FailedOnly -and $TestResult.FailedCount -eq 0) {
        Write-Host ""
        Write-Host "No failed tests to display." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
}

# Display code coverage summary
function Show-CoverageSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TestResult
    )
    
    if ($TestResult.CodeCoverage) {
        Write-Host ""
        Write-Host "CODE COVERAGE SUMMARY:" -ForegroundColor Cyan
        Write-Host "Covered Lines: $($TestResult.CodeCoverage.CoveredPercent.ToString('F2'))%" -ForegroundColor Green
        Write-Host "Total Lines: $($TestResult.CodeCoverage.AnalyzedFiles.Count)" -ForegroundColor White
        
        if ($TestResult.CodeCoverage.MissedCommands.Count -gt 0) {
            Write-Host ""
            Write-Host "UNCOVERED CODE:" -ForegroundColor Yellow
            $missedByFile = $TestResult.CodeCoverage.MissedCommands | Group-Object File
            foreach ($fileGroup in $missedByFile) {
                Write-Host "  $($fileGroup.Name):" -ForegroundColor Yellow
                foreach ($missed in $fileGroup.Group | Select-Object -First 5) {
                    Write-Host "    Line $($missed.Line): $($missed.Command)" -ForegroundColor DarkYellow
                }
                if ($fileGroup.Group.Count -gt 5) {
                    Write-Host "    ... and $($fileGroup.Group.Count - 5) more lines" -ForegroundColor DarkYellow
                }
            }
        }
    }
}

# Main execution
function Main {
    Write-Host "Zoidbot PowerShell Test Runner" -ForegroundColor Magenta
    Write-Host "=====================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Install and configure Pester
    if (-not (Install-PesterModule)) {
        exit 1
    }
    
    # Initialize test environment
    $testEnv = Initialize-TestEnvironment
    
    # Get test files to execute
    $testFiles = Get-TestFiles -SpecificFile $TestFile
    if ($testFiles.Count -eq 0) {
        Write-Error "No test files found to execute"
        exit 1
    }
    
    Write-Host "[EXECUTION] Found $($testFiles.Count) test file(s) to execute:" -ForegroundColor Cyan
    foreach ($file in $testFiles) {
        Write-Host "  - $(Split-Path -Leaf $file)" -ForegroundColor White
    }
    Write-Host ""
    
    # Configure Pester
    $pesterConfig = Get-PesterConfiguration -TestFiles $testFiles -OutputFormat $OutputFormat -TestResultsDir $testEnv.TestResultsDir -CoverageDir $testEnv.CoverageDir -CodeCoverage $CodeCoverage.IsPresent -ExportResults $ExportResults.IsPresent -Tag $Tag
    
    # Execute tests
    Write-Host "[EXECUTION] Running tests..." -ForegroundColor Cyan
    $testStartTime = Get-Date
    
    try {
        $testResult = Invoke-Pester -Configuration $pesterConfig
    }
    catch {
        Write-Error "Test execution failed: $($_.Exception.Message)"
        exit 1
    }
    
    $testEndTime = Get-Date
    $totalDuration = $testEndTime - $testStartTime
    
    # Display results
    Show-TestSummary -TestResult $testResult -FailedOnly $FailedOnly.IsPresent
    
    if ($CodeCoverage.IsPresent) {
        Show-CoverageSummary -TestResult $testResult
    }
    
    # Export additional reports if requested
    if ($ExportResults.IsPresent) {
        Write-Host ""
        Write-Host "[EXPORT] Test results exported to: $($pesterConfig.TestResult.OutputPath)" -ForegroundColor Green
        
        if ($CodeCoverage.IsPresent) {
            Write-Host "[EXPORT] Coverage report exported to: $($pesterConfig.CodeCoverage.OutputPath)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "Test execution completed in $($totalDuration.ToString('mm\:ss\.fff'))" -ForegroundColor Magenta
    
    # Exit with appropriate code
    if ($testResult.FailedCount -gt 0) {
        Write-Host "Tests failed. Exiting with code 1." -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "All tests passed successfully." -ForegroundColor Green
        exit 0
    }
}

# Execute main function
Main