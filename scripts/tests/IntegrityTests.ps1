# File Integrity Validation Test Suite for README.md Update Scripts (PowerShell)
# Comprehensive tests for file integrity, encoding preservation, and content accuracy

param(
    [switch]$Verbose = $false
)

# Set up test environment
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$VersionManager = Join-Path $ProjectRoot "scripts\powershell\version_manager.ps1"
$TestDir = Join-Path $ScriptDir "temp_integrity_tests_ps"

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Test logging functions
function Write-IntegrityInfo {
    param([string]$Message)
    Write-Host "[INTEGRITY] $Message" -ForegroundColor Blue
}

function Write-IntegritySuccess {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Write-IntegrityFailure {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:TestsFailed++
}

# Test setup and cleanup
function Setup-IntegrityTestEnvironment {
    Write-IntegrityInfo "Setting up integrity test environment..."
    
    # Create test directory
    if (-not (Test-Path $TestDir)) {
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    }
    
    # Create test files with different characteristics
    New-TestFiles
    
    Write-IntegrityInfo "Test environment ready at: $TestDir"
}

function Remove-IntegrityTestEnvironment {
    Write-IntegrityInfo "Cleaning up integrity test environment..."
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force
    }
}

# Create test files with various characteristics
function New-TestFiles {
    # Standard UTF-8 file with LF endings
    $contentLF = @"
# Zoidbot

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/Zoidbot-online/Zoidbot)

Test file with LF line endings.
"@
    Set-Content -Path (Join-Path $TestDir "readme_lf.md") -Value $contentLF -Encoding UTF8

    # UTF-8 file with CRLF endings
    $contentCRLF = $contentLF -replace "`n", "`r`n"
    Set-Content -Path (Join-Path $TestDir "readme_crlf.md") -Value $contentCRLF -Encoding UTF8

    # File without final newline
    $contentNoNewline = @"
# Zoidbot

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/Zoidbot-online/Zoidbot)

Test file without final newline.
"@
    Set-Content -Path (Join-Path $TestDir "readme_no_final_newline.md") -Value $contentNoNewline -Encoding UTF8 -NoNewline

    # File with Unicode characters
    $contentUnicode = @"
# Zoidbot

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/Zoidbot-online/Zoidbot)

Test file with Unicode:  �  �
Special characters: àáâãäåæçèéêë
Mathematical symbols: ∑ ∏ ∫ ∆ ∇
"@
    Set-Content -Path (Join-Path $TestDir "readme_unicode.md") -Value $contentUnicode -Encoding UTF8

    # Large file for performance testing
    $contentLarge = @"
# Zoidbot

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/Zoidbot-online/Zoidbot)

"@
    for ($i = 1; $i -le 1000; $i++) {
        $contentLarge += "Line $i`: This is a test line with some content to make the file larger.`n"
    }
    Set-Content -Path (Join-Path $TestDir "readme_large.md") -Value $contentLarge -Encoding UTF8
}

# Import the version manager functions for testing
function Import-VersionManagerForIntegrity {
    if (-not (Test-Path $VersionManager)) {
        Write-IntegrityFailure "Version manager script not found: $VersionManager"
        exit 1
    }
    
    # Import the script to get access to functions
    . $VersionManager
}

# Test file characteristics preservation
function Test-FileCharacteristicsPreservation {
    Write-IntegrityInfo "Testing file characteristics preservation..."
    $script:TestsRun++
    
    $testFiles = @(
        "readme_lf.md",
        "readme_crlf.md", 
        "readme_no_final_newline.md",
        "readme_unicode.md"
    )
    
    $failedTests = 0
    
    foreach ($testFile in $testFiles) {
        $filePath = Join-Path $TestDir $testFile
        Write-IntegrityInfo "Testing characteristics preservation for: $testFile"
        
        # Capture original characteristics
        $originalContent = Get-Content $filePath -Raw
        $originalLines = (Get-Content $filePath).Count
        $originalSize = (Get-Item $filePath).Length
        
        $hasOriginalNewline = $originalContent.EndsWith("`n") -or $originalContent.EndsWith("`r`n")
        $hasOriginalCRLF = $originalContent.Contains("`r`n")
        
        # Override ReadmeFile for this test
        $script:ReadmeFile = $filePath
        
        try {
            # Perform update
            Update-ReadmeVersion -NewVersion "5.1.0"
            
            # Check characteristics after update
            $newContent = Get-Content $filePath -Raw
            $newLines = (Get-Content $filePath).Count
            $newSize = (Get-Item $filePath).Length
            
            $hasNewNewline = $newContent.EndsWith("`n") -or $newContent.EndsWith("`r`n")
            $hasNewCRLF = $newContent.Contains("`r`n")
            
            # Verify characteristics preserved
            if ($newLines -eq $originalLines) {
                Write-IntegritySuccess "$testFile`: Line count preserved ($newLines)"
            } else {
                Write-IntegrityFailure "$testFile`: Line count changed ($originalLines -> $newLines)"
                $failedTests++
            }
            
            if ($hasOriginalNewline -eq $hasNewNewline) {
                Write-IntegritySuccess "$testFile`: Final newline behavior preserved"
            } else {
                Write-IntegrityFailure "$testFile`: Final newline behavior changed"
                $failedTests++
            }
            
            if ($hasOriginalCRLF -eq $hasNewCRLF) {
                Write-IntegritySuccess "$testFile`: Line ending style preserved"
            } else {
                Write-IntegrityFailure "$testFile`: Line ending style changed"
                $failedTests++
            }
            
            # Verify version was updated
            if ($newContent -match "version-5\.1\.0-blue") {
                Write-IntegritySuccess "$testFile`: Version correctly updated"
            } else {
                Write-IntegrityFailure "$testFile`: Version not updated correctly"
                $failedTests++
            }
            
        } catch {
            Write-IntegrityFailure "$testFile`: Update function failed - $($_.Exception.Message)"
            $failedTests++
        }
    }
    
    if ($failedTests -eq 0) {
        Write-IntegritySuccess "File characteristics preservation test passed"
    } else {
        Write-IntegrityFailure "File characteristics preservation test failed ($failedTests failures)"
    }
}

# Test UTF-8 encoding preservation
function Test-Utf8EncodingPreservation {
    Write-IntegrityInfo "Testing UTF-8 encoding preservation..."
    $script:TestsRun++
    
    $testFile = Join-Path $TestDir "readme_unicode.md"
    $originalContent = Get-Content $testFile -Raw
    
    # Override ReadmeFile for this test
    $script:ReadmeFile = $testFile
    
    try {
        # Perform update
        Update-ReadmeVersion -NewVersion "6.0.0"
        
        # Verify UTF-8 encoding is still valid
        Test-Utf8Encoding -FilePath $testFile
        Write-IntegritySuccess "UTF-8 encoding preserved after update"
        
        # Verify Unicode characters are intact
        $newContent = Get-Content $testFile -Raw
        if ($newContent -match "||�||�") {
            Write-IntegritySuccess "Unicode characters preserved"
        } else {
            Write-IntegrityFailure "Unicode characters corrupted"
        }
        
        if ($newContent -match "àáâãäåæçèéêë") {
            Write-IntegritySuccess "Accented characters preserved"
        } else {
            Write-IntegrityFailure "Accented characters corrupted"
        }
        
        if ($newContent -match "∑|∏|∫|∆|∇") {
            Write-IntegritySuccess "Mathematical symbols preserved"
        } else {
            Write-IntegrityFailure "Mathematical symbols corrupted"
        }
        
    } catch {
        Write-IntegrityFailure "UTF-8 encoding test failed: $($_.Exception.Message)"
    }
}

# Test content accuracy and structure preservation
function Test-ContentAccuracy {
    Write-IntegrityInfo "Testing content accuracy and structure preservation..."
    $script:TestsRun++
    
    $testFile = Join-Path $TestDir "readme_lf.md"
    $originalContent = Get-Content $testFile -Raw
    
    # Override ReadmeFile for this test
    $script:ReadmeFile = $testFile
    
    try {
        # Perform update
        Update-ReadmeVersion -NewVersion "7.0.0"
        
        $newContent = Get-Content $testFile -Raw
        
        # Verify only the version badge was changed
        $originalWithoutVersion = $originalContent -replace "version-[0-9]+\.[0-9]+\.[0-9]+-blue", "VERSION_PLACEHOLDER"
        $newWithoutVersion = $newContent -replace "version-[0-9]+\.[0-9]+\.[0-9]+-blue", "VERSION_PLACEHOLDER"
        
        if ($originalWithoutVersion -eq $newWithoutVersion) {
            Write-IntegritySuccess "Content structure preserved (only version changed)"
        } else {
            Write-IntegrityFailure "Content structure modified beyond version update"
        }
        
        # Verify specific version was set
        if ($newContent -match "version-7\.0\.0-blue") {
            Write-IntegritySuccess "Correct version set in badge"
        } else {
            Write-IntegrityFailure "Incorrect version in badge"
        }
        
        # Verify no duplicate badges were created
        $badgeMatches = [regex]::Matches($newContent, "img\.shields\.io/badge/version-")
        if ($badgeMatches.Count -eq 1) {
            Write-IntegritySuccess "No duplicate version badges created"
        } else {
            Write-IntegrityFailure "Multiple version badges found ($($badgeMatches.Count))"
        }
        
    } catch {
        Write-IntegrityFailure "Content accuracy test failed: $($_.Exception.Message)"
    }
}

# Test large file handling
function Test-LargeFileHandling {
    Write-IntegrityInfo "Testing large file handling..."
    $script:TestsRun++
    
    $testFile = Join-Path $TestDir "readme_large.md"
    $originalSize = (Get-Item $testFile).Length
    
    # Override ReadmeFile for this test
    $script:ReadmeFile = $testFile
    
    try {
        # Time the operation
        $startTime = Get-Date
        
        Update-ReadmeVersion -NewVersion "8.0.0"
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        # Verify file integrity
        $newSize = (Get-Item $testFile).Length
        
        if ((Test-Path $testFile) -and $newSize -gt 0) {
            Write-IntegritySuccess "Large file remains intact after update"
            
            # Check performance (should complete within reasonable time)
            if ($duration -le 10) {
                Write-IntegritySuccess "Large file update completed in reasonable time ($([math]::Round($duration, 2))s)"
            } else {
                Write-IntegrityFailure "Large file update took too long ($([math]::Round($duration, 2))s)"
            }
            
            # Verify version was updated
            $content = Get-Content $testFile -Raw
            if ($content -match "version-8\.0\.0-blue") {
                Write-IntegritySuccess "Version correctly updated in large file"
            } else {
                Write-IntegrityFailure "Version not updated in large file"
            }
            
        } else {
            Write-IntegrityFailure "Large file corrupted or deleted"
        }
    } catch {
        Write-IntegrityFailure "Large file test failed: $($_.Exception.Message)"
    }
}

# Test backup integrity
function Test-BackupIntegrity {
    Write-IntegrityInfo "Testing backup integrity..."
    $script:TestsRun++
    
    $testFile = Join-Path $TestDir "readme_lf.md"
    $originalContent = Get-Content $testFile -Raw
    
    # Override ReadmeFile for this test
    $script:ReadmeFile = $testFile
    
    try {
        # Perform update (this should create backups)
        Update-ReadmeVersion -NewVersion "9.0.0"
        
        # Find backup files
        $backupFiles = Get-ChildItem -Path $TestDir -Filter "*.backup.*" -File
        
        if ($backupFiles.Count -gt 0) {
            Write-IntegritySuccess "Backup files created ($($backupFiles.Count) found)"
            
            # Test the most recent backup
            $latestBackup = $backupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            
            # Verify backup integrity
            Test-BackupIntegrity -OriginalFile $testFile -BackupFile $latestBackup.FullName
            Write-IntegritySuccess "Backup integrity verification passed"
            
        } else {
            Write-IntegrityFailure "No backup files found"
        }
    } catch {
        Write-IntegrityFailure "Backup integrity test failed: $($_.Exception.Message)"
    }
}

# Main test runner
function Invoke-IntegrityTests {
    Write-IntegrityInfo "Starting README.md File Integrity Test Suite (PowerShell)"
    Write-IntegrityInfo "========================================================="
    
    try {
        # Set up test environment
        Setup-IntegrityTestEnvironment
        
        # Import the version manager functions
        Import-VersionManagerForIntegrity
        
        # Run all integrity tests
        Test-FileCharacteristicsPreservation
        Test-Utf8EncodingPreservation
        Test-ContentAccuracy
        Test-LargeFileHandling
        Test-BackupIntegrity
        
    } finally {
        # Cleanup
        Remove-IntegrityTestEnvironment
    }
    
    # Print summary
    Write-Host ""
    Write-IntegrityInfo "Integrity Test Summary"
    Write-IntegrityInfo "====================="
    Write-IntegrityInfo "Tests Run: $script:TestsRun"
    Write-IntegritySuccess "Tests Passed: $script:TestsPassed"
    
    if ($script:TestsFailed -gt 0) {
        Write-IntegrityFailure "Tests Failed: $script:TestsFailed"
        Write-Host ""
        Write-IntegrityFailure "FILE INTEGRITY TESTS FAILED"
        exit 1
    } else {
        Write-Host ""
        Write-IntegritySuccess "ALL FILE INTEGRITY TESTS PASSED"
        exit 0
    }
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-IntegrityTests
}
