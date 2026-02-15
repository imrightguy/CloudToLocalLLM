# Zoidbot Build-Time Version Injector (PowerShell)
# Injects actual build timestamp into version files at the moment of build execution
# Ensures build numbers reflect true build creation time

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('inject', 'restore', 'cleanup', 'help')]
    [string]$Command = 'help',
    
    [switch]$Help
)

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}
else {
    Write-Error "BuildEnvironmentUtilities module not found at $utilsPath"
    exit 1
}

# Show help
if ($Help -or $Command -eq 'help') {
    Write-Host "Zoidbot Build-Time Version Injector (PowerShell)" -ForegroundColor Blue
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Injects actual build timestamp into version files at build execution time" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\build_time_version_injector.ps1 <command>" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  inject    Inject current timestamp into all version files"
    Write-Host "  restore   Restore all version files from backups"
    Write-Host "  cleanup   Clean up backup files"
    Write-Host "  help      Show this help message"
    Write-Host ""
    Write-Host "This script is designed to be called during the build process" -ForegroundColor White
    Write-Host "to ensure build numbers reflect actual build execution time." -ForegroundColor White
    exit 0
}

# Configuration
$ProjectRoot = Get-ProjectRoot

# File paths
$PubspecFile = Join-Path $ProjectRoot "pubspec.yaml"
$AssetsVersionFile = Join-Path $ProjectRoot "assets\version.json"
$SharedVersionFile = Join-Path $ProjectRoot "lib\shared\lib\version.dart"
$SharedPubspecFile = Join-Path $ProjectRoot "lib\shared\pubspec.yaml"
$AppConfigFile = Join-Path $ProjectRoot "lib\config\app_config.dart"

# Generate build timestamp in YYYYMMDDHHMM format
function Get-BuildTimestamp {
    return Get-Date -Format "yyyyMMddHHmm"
}

# Generate ISO timestamp for build_date fields
function Get-ISOTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Get current semantic version from pubspec.yaml
function Get-SemanticVersion {
    if (-not (Test-Path $PubspecFile)) {
        Write-LogError "pubspec.yaml not found: $PubspecFile"
        exit 1
    }
    
    $versionLine = Get-Content $PubspecFile | Where-Object { $_ -match '^version:' } | Select-Object -First 1
    if (-not $versionLine) {
        Write-LogError "No version found in pubspec.yaml"
        exit 1
    }
    
    # Extract semantic version (before +)
    $version = ($versionLine -replace 'version:\s*', '').Trim()
    return ($version -split '\+')[0]
}

# Create backup of a file
function New-Backup {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        $backupPath = "$FilePath.build-backup"
        Copy-Item $FilePath $backupPath -Force
        Write-LogInfo "Created backup: $backupPath"
    }
}

# Restore backup of a file
function Restore-Backup {
    param([string]$FilePath)
    
    $backupPath = "$FilePath.build-backup"
    if (Test-Path $backupPath) {
        Move-Item $backupPath $FilePath -Force
        Write-LogInfo "Restored backup: $FilePath"
    }
}

# Update pubspec.yaml with build timestamp
function Update-PubspecVersion {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp
    )
    
    $fullVersion = "$SemanticVersion+$BuildTimestamp"
    
    Write-LogInfo "Updating pubspec.yaml to $fullVersion"
    
    New-Backup -FilePath $PubspecFile
    
    # Update version line
    $content = Get-Content $PubspecFile
    $updatedContent = $content -replace '^version:.*', "version: $fullVersion"
    Set-Content -Path $PubspecFile -Value $updatedContent -Encoding UTF8
    
    Write-LogSuccess "Updated pubspec.yaml to $fullVersion"
}

# Update assets/version.json with build timestamp
function Update-AssetsVersionJson {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp,
        [string]$ISOTimestamp
    )
    
    Write-LogInfo "Updating assets/version.json"
    
    if (-not (Test-Path $AssetsVersionFile)) {
        Write-LogWarning "assets/version.json not found, creating new file"
        $assetsDir = Split-Path $AssetsVersionFile -Parent
        if (-not (Test-Path $assetsDir)) {
            New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
        }
    }
    else {
        New-Backup -FilePath $AssetsVersionFile
    }
    
    # Get git commit hash
    $gitCommit = "unknown"
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $gitCommit = & git rev-parse --short HEAD 2>$null
            if ($LASTEXITCODE -ne 0) {
                $gitCommit = "unknown"
            }
        }
    }
    catch {
        $gitCommit = "unknown"
    }
    
    # Create/update the JSON file
    $versionJson = @{
        version = $SemanticVersion
        build_number = $BuildTimestamp
        build_date = $ISOTimestamp
        git_commit = $gitCommit
    } | ConvertTo-Json -Depth 2
    
    Set-Content -Path $AssetsVersionFile -Value $versionJson -Encoding UTF8
    
    Write-LogSuccess "Updated assets/version.json"
}

# Update shared/lib/version.dart with build timestamp
function Update-SharedVersionFile {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp,
        [string]$ISOTimestamp
    )
    
    Write-LogInfo "Updating lib/shared/lib/version.dart"
    
    if (-not (Test-Path $SharedVersionFile)) {
        Write-LogWarning "lib/shared/lib/version.dart not found, skipping"
        return
    }
    
    New-Backup -FilePath $SharedVersionFile
    
    # Update all version constants
    $content = Get-Content $SharedVersionFile -Raw
    $content = $content -replace "static const String mainAppVersion = '[^']*';", "static const String mainAppVersion = '$SemanticVersion';"
    $content = $content -replace "static const int mainAppBuildNumber = (\d+|BUILD_TIME_PLACEHOLDER);", "static const int mainAppBuildNumber = $BuildTimestamp;"
    $content = $content -replace "static const String tunnelManagerVersion = '[^']*';", "static const String tunnelManagerVersion = '$SemanticVersion';"
    $content = $content -replace "static const int tunnelManagerBuildNumber = (\d+|BUILD_TIME_PLACEHOLDER);", "static const int tunnelManagerBuildNumber = $BuildTimestamp;"
    $content = $content -replace "static const String sharedLibraryVersion = '[^']*';", "static const String sharedLibraryVersion = '$SemanticVersion';"
    $content = $content -replace "static const int sharedLibraryBuildNumber = (\d+|BUILD_TIME_PLACEHOLDER);", "static const int sharedLibraryBuildNumber = $BuildTimestamp;"
    $content = $content -replace "static const String buildTimestamp = '[^']*';", "static const String buildTimestamp = '$ISOTimestamp';"
    
    Set-Content -Path $SharedVersionFile -Value $content -Encoding UTF8 -NoNewline
    
    Write-LogSuccess "Updated lib/shared/lib/version.dart"
}

# Update shared/pubspec.yaml with build timestamp
function Update-SharedPubspecVersion {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp
    )
    
    $fullVersion = "$SemanticVersion+$BuildTimestamp"
    
    Write-LogInfo "Updating lib/shared/pubspec.yaml"
    
    if (-not (Test-Path $SharedPubspecFile)) {
        Write-LogWarning "lib/shared/pubspec.yaml not found, skipping"
        return
    }
    
    New-Backup -FilePath $SharedPubspecFile
    
    # Update version line
    $content = Get-Content $SharedPubspecFile
    $updatedContent = $content -replace '^version:.*', "version: $fullVersion"
    Set-Content -Path $SharedPubspecFile -Value $updatedContent -Encoding UTF8
    
    Write-LogSuccess "Updated lib/shared/pubspec.yaml to $fullVersion"
}

# Update app_config.dart with semantic version
function Update-AppConfigVersion {
    param([string]$SemanticVersion)
    
    Write-LogInfo "Updating lib/config/app_config.dart"
    
    if (-not (Test-Path $AppConfigFile)) {
        Write-LogWarning "lib/config/app_config.dart not found, skipping"
        return
    }
    
    New-Backup -FilePath $AppConfigFile
    
    # Update version constant
    $content = Get-Content $AppConfigFile -Raw
    $content = $content -replace "static const String appVersion = '[^']*';", "static const String appVersion = '$SemanticVersion';"
    
    Set-Content -Path $AppConfigFile -Value $content -Encoding UTF8 -NoNewline
    
    Write-LogSuccess "Updated lib/config/app_config.dart to $SemanticVersion"
}

# Inject build timestamp into all version files
function Invoke-BuildTimestampInjection {
    Write-LogInfo "� Injecting build timestamp at build execution time..."

    # Generate timestamps
    $buildTimestamp = Get-BuildTimestamp
    $isoTimestamp = Get-ISOTimestamp
    $semanticVersion = Get-SemanticVersion

    Write-LogInfo "Build timestamp: $buildTimestamp"
    Write-LogInfo "ISO timestamp: $isoTimestamp"
    Write-LogInfo "Semantic version: $semanticVersion"

    # Update all version files
    Update-PubspecVersion -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp
    Update-AssetsVersionJson -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp -ISOTimestamp $isoTimestamp
    Update-SharedVersionFile -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp -ISOTimestamp $isoTimestamp
    Update-SharedPubspecVersion -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp
    Update-AppConfigVersion -SemanticVersion $semanticVersion

    # Validate that all placeholders have been replaced
    Test-PlaceholderRemoval

    Write-LogSuccess " Build timestamp injection completed: $semanticVersion+$buildTimestamp"
}

# Restore all backups (for cleanup after build)
function Restore-AllBackups {
    Write-LogInfo " Restoring version files from backups..."

    Restore-Backup -FilePath $PubspecFile
    Restore-Backup -FilePath $AssetsVersionFile
    Restore-Backup -FilePath $SharedVersionFile
    Restore-Backup -FilePath $SharedPubspecFile
    Restore-Backup -FilePath $AppConfigFile

    Write-LogSuccess " All version files restored from backups"
}

# Clean up backup files
function Remove-BackupFiles {
    Write-LogInfo "� Cleaning up backup files..."

    $backupFiles = @(
        "$PubspecFile.build-backup",
        "$AssetsVersionFile.build-backup",
        "$SharedVersionFile.build-backup",
        "$SharedPubspecFile.build-backup",
        "$AppConfigFile.build-backup"
    )

    foreach ($backupFile in $backupFiles) {
        if (Test-Path $backupFile) {
            Remove-Item $backupFile -Force
        }
    }

    Write-LogSuccess " Backup files cleaned up"
}

# Validate that no BUILD_TIME_PLACEHOLDER remains in version files
function Test-PlaceholderRemoval {
    Write-LogInfo "Validating that all BUILD_TIME_PLACEHOLDER instances have been replaced"

    $filesToCheck = @($PubspecFile, $SharedPubspecFile, $SharedVersionFile, $AssetsVersionFile)
    $placeholderFound = $false

    foreach ($file in $filesToCheck) {
        if (Test-Path $file) {
            $content = Get-Content $file -Raw
            if ($content -match "BUILD_TIME_PLACEHOLDER") {
                Write-LogError "BUILD_TIME_PLACEHOLDER found in: $file"
                $placeholderFound = $true
            } else {
                Write-LogInfo "No placeholders in: $file"
            }
        }
    }

    if ($placeholderFound) {
        Write-LogError "Validation failed: BUILD_TIME_PLACEHOLDER instances remain in version files"
        exit 1
    } else {
        Write-LogSuccess "Validation passed: All BUILD_TIME_PLACEHOLDER instances have been replaced"
    }
}

# Main command dispatcher
function Invoke-Main {
    # Change to project root
    Set-Location $ProjectRoot

    switch ($Command) {
        'inject' {
            Invoke-BuildTimestampInjection
        }
        'restore' {
            Restore-AllBackups
        }
        'cleanup' {
            Remove-BackupFiles
        }
        default {
            Write-LogError "Unknown command: $Command"
            Write-Host "Use '.\build_time_version_injector.ps1 help' for usage information" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
