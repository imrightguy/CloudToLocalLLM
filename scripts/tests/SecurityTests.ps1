# Security Test Suite for README.md Update Scripts (PowerShell)
# Tests all identified vulnerabilities and security improvements

param(
    [switch]$Verbose = $false
)

# Set up test environment
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$VersionManager = Join-Path $ProjectRoot "scripts\powershell\version_manager.ps1"
$TestDir = Join-Path $ScriptDir "temp_test_files_ps"
$TestReadme = Join-Path $TestDir "README.md"

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Test logging functions
function Write-TestInfo {
    param([string]$Message)
    Write-Host "[TEST INFO] $Message" -ForegroundColor Blue
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "[TEST PASS] $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Write-TestFailure {
    param([string]$Message)
    Write-Host "[TEST FAIL] $Message" -ForegroundColor Red
    $script:TestsFailed++
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "[TEST WARN] $Message" -ForegroundColor Yellow
}

# Test setup and cleanup
function Setup-TestEnvironment {
    Write-TestInfo "Setting up test environment..."
    
    # Create test directory
    if (-not (Test-Path $TestDir)) {
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    }
    
    # Create a test README.md with version badge
    $readmeContent = @"
# Zoidbot

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/Zoidbot-online/Zoidbot)

A sophisticated Flutter-based application that bridges cloud-based AI services with local AI models.

## Features

- Hybrid AI model support
- Real-time streaming
- Cross-platform compatibility

## Installation

Follow the installation guide in the docs directory.
"@
    
    Set-Content -Path $TestReadme -Value $readmeContent -Encoding UTF8
    Write-TestInfo "Test environment ready at: $TestDir"
}

function Cleanup-TestEnvironment {
    Write-TestInfo "Cleaning up test environment..."
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force
    }
}

# Source the version manager functions for testing
function Import-VersionManager {
    if (-not (Test-Path $VersionManager)) {
        Write-TestFailure "Version manager script not found: $VersionManager"
        exit 1
    }
    
    # Import the script to get access to functions
    . $VersionManager
    
    # Override the ReadmeFile variable for testing
    $script:ReadmeFile = $TestReadme
}

# Test 1: Input Validation Tests
function Test-InputValidation {
    Write-TestInfo "Running input validation tests..."
    $script:TestsRun++
    
    $maliciousVersions = @(
        "1.0.0]/[![Malicious](http://evil.com/badge.svg)]",
        "1.0.0`"; Remove-Item -Recurse C:\; Write-Host `"",
        "..\..\..\Windows\System32\config\SAM",
        "1.0.0`n`n## Injected Content",
        "999999.999999.999999",
        "",
        "1.0",
        "1.0.0.0",
        "v1.0.0",
        "1.0.0-beta",
        "1.0.0+build"
    )
    
    $failedTests = 0
    
    foreach ($version in $maliciousVersions) {
        Write-TestInfo "Testing malicious/invalid version: '$version'"
        
        try {
            Test-VersionString -Version $version
            Write-TestFailure "SECURITY FAILURE: Malicious/invalid version passed validation: '$version'"
            $failedTests++
        } catch {
            Write-TestSuccess "Malicious/invalid version correctly rejected: '$version'"
        }
    }
    
    # Test valid versions
    $validVersions = @("1.0.0", "0.0.1", "999.999.999", "10.20.30")
    
    foreach ($version in $validVersions) {
        Write-TestInfo "Testing valid version: '$version'"
        
        try {
            Test-VersionString -Version $version
            Write-TestSuccess "Valid version correctly accepted: '$version'"
        } catch {
            Write-TestFailure "Valid version incorrectly rejected: '$version'"
            $failedTests++
        }
    }
    
    if ($failedTests -eq 0) {
        Write-TestSuccess "Input validation test suite passed"
    } else {
        Write-TestFailure "Input validation test suite failed ($failedTests failures)"
    }
}

# Test 2: Regex Injection Prevention
function Test-RegexInjectionPrevention {
    Write-TestInfo "Running regex injection prevention tests..."
    $script:TestsRun++
    
    Setup-TestEnvironment
    
    # Test the ConvertTo-RegexSafe function
    $testStrings = @(
        "1.0.0[malicious]",
        "1.0.0`$injection",
        "1.0.0.*wildcard",
        "1.0.0^anchor",
        "1.0.0(group)"
    )
    
    $failedTests = 0
    
    foreach ($testString in $testStrings) {
        Write-TestInfo "Testing regex escaping for: '$testString'"
        
        try {
            $escaped = ConvertTo-RegexSafe -InputString $testString
            
            # Verify that the escaped string is safe
            if ($escaped -match '[^\\][\[\.*\^\$\(\)\+\?\{\|]') {
                Write-TestFailure "Regex escaping may be incomplete for: '$testString' -> '$escaped'"
                $failedTests++
            } else {
                Write-TestSuccess "Regex escaping successful for: '$testString' -> '$escaped'"
            }
        } catch {
            Write-TestFailure "Regex escaping failed for: '$testString' - $($_.Exception.Message)"
            $failedTests++
        }
    }
    
    if ($failedTests -eq 0) {
        Write-TestSuccess "Regex injection prevention test suite passed"
    } else {
        Write-TestFailure "Regex injection prevention test suite failed ($failedTests failures)"
    }
}

# Test 3: File Integrity Tests
function Test-FileIntegrity {
    Write-TestInfo "Running file integrity tests..."
    $script:TestsRun++
    
    Setup-TestEnvironment
    
    # Test that README update preserves file integrity
    $testVersion = "5.0.0"
    $originalContent = Get-Content $TestReadme -Raw
    $originalLines = (Get-Content $TestReadme).Count
    
    try {
        # Perform update
        Update-ReadmeVersion -NewVersion $testVersion
        
        # Verify file still exists and has content
        if ((Test-Path $TestReadme) -and (Get-Item $TestReadme).Length -gt 0) {
            $newContent = Get-Content $TestReadme -Raw
            $newLines = (Get-Content $TestReadme).Count
            
            # Check that version was updated
            if ($newContent -match "version-$([regex]::Escape($testVersion))-blue") {
                Write-TestSuccess "Version badge correctly updated to $testVersion"
                
                # Check that file structure is preserved
                if ($newLines -eq $originalLines) {
                    Write-TestSuccess "File line count preserved ($newLines lines)"
                } else {
                    Write-TestFailure "File line count changed: $originalLines -> $newLines"
                }
                
                # Check that file is still valid UTF-8
                try {
                    Test-Utf8Encoding -FilePath $TestReadme
                    Write-TestSuccess "File UTF-8 encoding preserved"
                } catch {
                    Write-TestFailure "File UTF-8 encoding corrupted: $($_.Exception.Message)"
                }
                
            } else {
                Write-TestFailure "Version badge was not updated correctly"
            }
        } else {
            Write-TestFailure "README file was corrupted or deleted"
        }
    } catch {
        Write-TestFailure "README update function failed: $($_.Exception.Message)"
    }
}

# Test 4: Concurrent Access Tests
function Test-ConcurrentAccess {
    Write-TestInfo "Running concurrent access tests..."
    $script:TestsRun++
    
    Setup-TestEnvironment
    
    try {
        # Test file locking mechanism
        $lockFile = Lock-File -FilePath $TestReadme -TimeoutSeconds 5
        
        if ($lockFile -and (Test-Path $lockFile)) {
            Write-TestSuccess "File lock acquired successfully: $lockFile"
            
            # Test that second lock attempt fails quickly
            $startTime = Get-Date
            try {
                Lock-File -FilePath $TestReadme -TimeoutSeconds 3 | Out-Null
                Write-TestFailure "Second lock attempt should have failed but succeeded"
            } catch {
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalSeconds
                
                if ($duration -le 5) {
                    Write-TestSuccess "Second lock attempt correctly failed within timeout ($duration seconds)"
                } else {
                    Write-TestFailure "Second lock attempt took too long to fail ($duration seconds)"
                }
            }
            
            # Release the lock
            if (Unlock-File -LockFile $lockFile) {
                Write-TestSuccess "File lock released successfully"
            } else {
                Write-TestFailure "Failed to release file lock"
            }
        } else {
            Write-TestFailure "Failed to acquire initial file lock"
        }
    } catch {
        Write-TestFailure "Concurrent access test failed: $($_.Exception.Message)"
    }
}

# Test 5: Backup and Recovery Tests
function Test-BackupRecovery {
    Write-TestInfo "Running backup and recovery tests..."
    $script:TestsRun++
    
    Setup-TestEnvironment
    
    $originalContent = Get-Content $TestReadme -Raw
    
    try {
        # Test backup creation
        $backupFile = New-TimestampedBackup -FilePath $TestReadme
        
        if ($backupFile -and (Test-Path $backupFile)) {
            Write-TestSuccess "Backup created successfully: $backupFile"
            
            # Verify backup integrity
            try {
                Test-BackupIntegrity -OriginalFile $TestReadme -BackupFile $backupFile
                Write-TestSuccess "Backup integrity verification passed"
            } catch {
                Write-TestFailure "Backup integrity verification failed: $($_.Exception.Message)"
            }
            
            # Test backup content
            $backupContent = Get-Content $backupFile -Raw
            if ($originalContent -eq $backupContent) {
                Write-TestSuccess "Backup content matches original"
            } else {
                Write-TestFailure "Backup content differs from original"
            }
        } else {
            Write-TestFailure "Failed to create backup"
        }
    } catch {
        Write-TestFailure "Backup and recovery test failed: $($_.Exception.Message)"
    }
}

# Main test runner
function Invoke-AllTests {
    Write-TestInfo "Starting README.md Script Security Test Suite (PowerShell)"
    Write-TestInfo "============================================================"
    
    try {
        # Import the version manager functions
        Import-VersionManager
        
        # Run all test suites
        Test-InputValidation
        Test-RegexInjectionPrevention
        Test-FileIntegrity
        Test-ConcurrentAccess
        Test-BackupRecovery
        
    } finally {
        # Cleanup
        Cleanup-TestEnvironment
    }
    
    # Print summary
    Write-Host ""
    Write-TestInfo "Test Summary"
    Write-TestInfo "============"
    Write-TestInfo "Tests Run: $script:TestsRun"
    Write-TestSuccess "Tests Passed: $script:TestsPassed"
    
    if ($script:TestsFailed -gt 0) {
        Write-TestFailure "Tests Failed: $script:TestsFailed"
        Write-Host ""
        Write-TestFailure "SECURITY TEST SUITE FAILED - CRITICAL ISSUES DETECTED"
        exit 1
    } else {
        Write-Host ""
        Write-TestSuccess "ALL SECURITY TESTS PASSED - SCRIPTS ARE SECURE"
        exit 0
    }
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-AllTests
}
