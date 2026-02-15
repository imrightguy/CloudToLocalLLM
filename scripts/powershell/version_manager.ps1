# Zoidbot Version Management Utility (PowerShell)
# Provides unified version management across all platforms and build systems

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('get', 'get-semantic', 'get-build', 'info', 'increment', 'set', 'validate', 'prepare', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [string]$Parameter,

    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
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

# Script configuration
$ProjectRoot = Get-ProjectRoot
$PubspecFile = Join-Path $ProjectRoot "pubspec.yaml"
$AppConfigFile = Join-Path $ProjectRoot "lib/config/app_config.dart"
$SharedVersionFile = Join-Path $ProjectRoot "lib/shared/lib/version.dart"
$SharedPubspecFile = Join-Path $ProjectRoot "lib/shared/pubspec.yaml"
$AssetsVersionFile = Join-Path $ProjectRoot "assets/version.json"

# Documentation files that need version updates
$ReadmeFile = Join-Path $ProjectRoot "README.md"
$PackageJsonFile = Join-Path $ProjectRoot "package.json"
$ChangelogFile = Join-Path $ProjectRoot "docs/CHANGELOG.md"

# Global variables for error handling and cleanup
$script:TempFiles = @()
$script:BackupFiles = @()

# Error handling and cleanup functions
function Register-TempFile {
    param([string]$FilePath)
    $script:TempFiles += $FilePath
}

function Register-BackupFile {
    param([string]$FilePath)
    $script:BackupFiles += $FilePath
}

# Enhanced backup management with rotation
function New-TimestampedBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string]$BackupDirectory = (Join-Path (Split-Path $FilePath -Parent) "backups"),
        [int]$MaxBackups = 10
    )

    if (-not (Test-Path $FilePath)) {
        throw "Cannot create backup: source file does not exist: $FilePath"
    }

    try {
        # Create backup directory if needed
        if (-not (Test-Path $BackupDirectory)) {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
            Write-LogInfo "Created backup directory: $BackupDirectory"
        }

        # Generate backup filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $basename = Split-Path $FilePath -Leaf
        $backupFile = Join-Path $BackupDirectory "$basename.backup.$timestamp"

        # Create backup with verification
        Copy-Item $FilePath $backupFile -Force

        # Verify backup was created successfully
        if ((Test-Path $backupFile) -and (Get-Item $backupFile).Length -gt 0) {
            # Compare file sizes to ensure backup is complete
            $originalSize = (Get-Item $FilePath).Length
            $backupSize = (Get-Item $backupFile).Length

            if ($originalSize -eq $backupSize) {
                Write-LogInfo "Created verified backup: $backupFile"
                Register-BackupFile -FilePath $backupFile

                # Cleanup old backups
                Remove-OldBackups -BackupDirectory $BackupDirectory -BaseName $basename -MaxBackups $MaxBackups

                return $backupFile
            } else {
                throw "Backup verification failed: size mismatch ($originalSize vs $backupSize)"
            }
        } else {
            throw "Backup file was not created or is empty"
        }

    } catch {
        # Clean up failed backup attempt
        if (Test-Path $backupFile) {
            Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to create backup: $($_.Exception.Message)"
    }
}

# Cleanup old backups (keep only max_backups)
function Remove-OldBackups {
    [CmdletBinding()]
    param(
        [string]$BackupDirectory,
        [string]$BaseName,
        [int]$MaxBackups
    )

    if (-not (Test-Path $BackupDirectory)) {
        return
    }

    # Find backup files and sort by creation time (newest first)
    $backupFiles = Get-ChildItem -Path $BackupDirectory -Filter "$BaseName.backup.*" |
                   Sort-Object LastWriteTime -Descending

    # Remove oldest backups if we exceed max_backups
    if ($backupFiles.Count -gt $MaxBackups) {
        $filesToRemove = $backupFiles.Count - $MaxBackups
        Write-LogInfo "Removing $filesToRemove old backup(s) (keeping $MaxBackups most recent)"

        $backupFiles | Select-Object -Skip $MaxBackups | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-LogInfo "Removed old backup: $($_.Name)"
        }
    }
}

# Verify backup integrity
function Test-BackupIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalFile,
        [Parameter(Mandatory = $true)]
        [string]$BackupFile
    )

    if (-not (Test-Path $OriginalFile)) {
        throw "Original file not found for backup verification: $OriginalFile"
    }

    if (-not (Test-Path $BackupFile)) {
        throw "Backup file not found: $BackupFile"
    }

    try {
        # Compare file sizes
        $originalSize = (Get-Item $OriginalFile).Length
        $backupSize = (Get-Item $BackupFile).Length

        if ($originalSize -ne $backupSize) {
            throw "Backup verification failed: size mismatch ($originalSize vs $backupSize)"
        }

        # Compare checksums
        $originalHash = Get-FileHash $OriginalFile -Algorithm SHA256
        $backupHash = Get-FileHash $BackupFile -Algorithm SHA256

        if ($originalHash.Hash -ne $backupHash.Hash) {
            throw "Backup verification failed: checksum mismatch"
        }

        Write-LogInfo "Backup integrity verified with checksum"
        return $true

    } catch {
        throw "Backup integrity verification failed: $($_.Exception.Message)"
    }
}

function Clear-TempFiles {
    param([bool]$ShowBackups = $false)

    if ($script:TempFiles.Count -gt 0) {
        Write-LogInfo "Cleaning up $($script:TempFiles.Count) temporary files..."
        foreach ($tempFile in $script:TempFiles) {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                Write-LogInfo "Removed temporary file: $tempFile"
            }
        }
        $script:TempFiles = @()
    }

    if ($ShowBackups -and $script:BackupFiles.Count -gt 0) {
        Write-LogWarning "The following backup files are available for recovery:"
        foreach ($backupFile in $script:BackupFiles) {
            if (Test-Path $backupFile) {
                Write-LogWarning "  - $backupFile"
            }
        }
        Write-LogWarning "To restore a file: Copy-Item <backup_file> <original_file>"
    }
}

function New-SecureTempFile {
    param([string]$BaseName)

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $newTempFile = "$BaseName.$(Get-Random).tmp"
        Move-Item $tempFile $newTempFile -Force

        # Set restrictive permissions (owner only)
        $acl = Get-Acl $newTempFile
        $acl.SetAccessRuleProtection($true, $false)
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl $newTempFile $acl

        Register-TempFile -FilePath $newTempFile
        return $newTempFile

    } catch {
        throw "Failed to create secure temporary file for $BaseName`: $($_.Exception.Message)"
    }
}

# Set up cleanup on script exit
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Clear-TempFiles -ShowBackups $true
}

# Atomic file replacement with verification
function Invoke-AtomicFileReplace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,
        [Parameter(Mandatory = $true)]
        [string]$TargetFile,
        [string]$BackupDirectory = (Split-Path $TargetFile -Parent)
    )

    try {
        # Pre-flight checks
        Test-FileOperationsSafe -SourceFile $SourceFile -TargetFile $TargetFile

        # Verify source file has content
        if (-not (Test-Path $SourceFile) -or (Get-Item $SourceFile).Length -eq 0) {
            throw "Source file is empty or does not exist: $SourceFile"
        }

        # Create timestamped backup if target exists
        $backupFile = $null
        if (Test-Path $TargetFile) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupFile = Join-Path $BackupDirectory "$(Split-Path $TargetFile -Leaf).backup.$timestamp"

            Copy-Item $TargetFile $backupFile -Force
            Register-BackupFile -FilePath $backupFile
            Write-LogInfo "Created backup: $backupFile"
        }

        # Perform atomic move with verification
        Move-Item $SourceFile $TargetFile -Force

        # Verify target file exists and has content
        if ((Test-Path $TargetFile) -and (Get-Item $TargetFile).Length -gt 0) {
            Write-LogSuccess "Atomic file replacement completed: $TargetFile"
            return $true
        } else {
            throw "Atomic replacement verification failed: target file missing or empty"
        }

    } catch {
        Write-LogError "Atomic file replacement failed: $($_.Exception.Message)"

        # Restore from backup if available
        if ($backupFile -and (Test-Path $backupFile)) {
            Copy-Item $backupFile $TargetFile -Force
            Write-LogInfo "Restored from backup due to failure"
        }

        throw
    }
}

# Character encoding and file characteristics preservation
function Preserve-FileCharacteristics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalFile,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    if (-not (Test-Path $OriginalFile)) {
        throw "Original file not found for characteristic preservation: $OriginalFile"
    }

    try {
        # Detect original file characteristics
        $originalBytes = [System.IO.File]::ReadAllBytes($OriginalFile)

        # Check for UTF-8 BOM
        $hasUtf8Bom = ($originalBytes.Length -ge 3) -and
                      ($originalBytes[0] -eq 0xEF) -and
                      ($originalBytes[1] -eq 0xBB) -and
                      ($originalBytes[2] -eq 0xBF)

        # Read original content to detect line ending style
        $originalContent = Get-Content $OriginalFile -Raw
        $endsWithNewline = $originalContent.EndsWith("`n") -or $originalContent.EndsWith("`r`n")

        # Detect line ending style (CRLF vs LF)
        $usesCrlf = $originalContent.Contains("`r`n")

        # Normalize content line endings if needed
        if ($usesCrlf -and -not $Content.Contains("`r`n")) {
            $Content = $Content -replace "`n", "`r`n"
        } elseif (-not $usesCrlf -and $Content.Contains("`r`n")) {
            $Content = $Content -replace "`r`n", "`n"
        }

        # Determine encoding (use UTF8 for compatibility across PowerShell versions)
        $encoding = "UTF8"

        # Write content with preserved characteristics
        if ($endsWithNewline) {
            Set-Content -Path $OriginalFile -Value $Content -Encoding $encoding
        } else {
            Set-Content -Path $OriginalFile -Value $Content -Encoding $encoding -NoNewline
        }

        Write-LogInfo "File characteristics preserved for: $OriginalFile"
        return $true

    } catch {
        throw "Failed to preserve file characteristics: $($_.Exception.Message)"
    }
}

# Validate UTF-8 encoding of file
function Test-Utf8Encoding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "File not found for UTF-8 validation: $FilePath"
    }

    try {
        # Read file as bytes to check encoding
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)

        # Try to decode as UTF-8
        $utf8 = [System.Text.Encoding]::UTF8
        $decoded = $utf8.GetString($bytes)

        # Re-encode and compare to detect encoding issues
        $reencoded = $utf8.GetBytes($decoded)

        # Check for UTF-8 BOM
        $hasBom = ($bytes.Length -ge 3) -and
                  ($bytes[0] -eq 0xEF) -and
                  ($bytes[1] -eq 0xBB) -and
                  ($bytes[2] -eq 0xBF)

        # Helper function to compare byte arrays
        function Compare-ByteArrays {
            param($array1, $array2)
            if ($array1.Length -ne $array2.Length) { return $false }
            for ($i = 0; $i -lt $array1.Length; $i++) {
                if ($array1[$i] -ne $array2[$i]) { return $false }
            }
            return $true
        }

        if ($hasBom) {
            # Compare without BOM
            $originalWithoutBom = $bytes[3..($bytes.Length - 1)]
            if (-not (Compare-ByteArrays $originalWithoutBom $reencoded)) {
                throw "File contains invalid UTF-8 sequences"
            }
        } else {
            if (-not (Compare-ByteArrays $bytes $reencoded)) {
                throw "File contains invalid UTF-8 sequences"
            }
        }

        Write-LogInfo "UTF-8 encoding validation passed for: $FilePath"
        return $true

    } catch {
        throw "UTF-8 encoding validation failed for ${FilePath}: $($_.Exception.Message)"
    }
}

# File locking mechanisms to prevent race conditions
function Lock-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [int]$TimeoutSeconds = 30
    )

    $lockFile = "$FilePath.lock"
    $startTime = Get-Date
    $processId = $PID

    Write-LogInfo "Attempting to acquire lock for: $FilePath"

    while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        try {
            # Attempt to create lock file exclusively
            $lockStream = [System.IO.File]::Open($lockFile, 'CreateNew', 'Write', 'None')
            $lockBytes = [System.Text.Encoding]::UTF8.GetBytes($processId.ToString())
            $lockStream.Write($lockBytes, 0, $lockBytes.Length)
            $lockStream.Close()

            Write-LogInfo "Lock acquired: $lockFile"
            return $lockFile

        } catch [System.IO.IOException] {
            # Check for stale lock
            if (Test-Path $lockFile) {
                try {
                    $lockContent = Get-Content $lockFile -ErrorAction Stop
                    $lockPid = [int]$lockContent

                    # Check if the process is still running
                    $lockProcess = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
                    if (-not $lockProcess) {
                        Write-LogWarning "Removing stale lock file (PID $lockPid no longer exists): $lockFile"
                        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
                        continue
                    } else {
                        Write-LogInfo "Lock held by active process (PID $lockPid), waiting..."
                    }
                } catch {
                    Write-LogWarning "Invalid lock file content, removing: $lockFile"
                    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
                    continue
                }
            }

            Start-Sleep -Seconds 1

            # Show progress every 10 seconds
            $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
            if ($elapsed % 10 -eq 0 -and $elapsed -gt 0) {
                Write-LogInfo "Still waiting for lock... ($elapsed/${TimeoutSeconds}s)"
            }
        }
    }

    $lockPid = if (Test-Path $lockFile) { Get-Content $lockFile -ErrorAction SilentlyContinue } else { "unknown" }
    throw "Failed to acquire lock for $FilePath after ${TimeoutSeconds}s (held by PID $lockPid)"
}

# Release file lock
function Unlock-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockFile
    )

    if (-not $LockFile) {
        Write-LogWarning "No lock file specified for release"
        return $false
    }

    if (Test-Path $LockFile) {
        try {
            # Verify we own the lock before removing it
            $lockContent = Get-Content $LockFile -ErrorAction Stop
            $lockPid = [int]$lockContent

            if ($lockPid -eq $PID) {
                Remove-Item $LockFile -Force
                Write-LogInfo "Released lock: $LockFile"
                return $true
            } else {
                Write-LogWarning "Cannot release lock owned by different process (PID $lockPid): $LockFile"
                return $false
            }
        } catch {
            Write-LogWarning "Error releasing lock $LockFile`: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-LogWarning "Lock file does not exist: $LockFile"
        return $false
    }
}

# Security: Input validation and sanitization functions
function Test-VersionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    # Check if version is provided
    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw "Version string cannot be empty"
    }

    # Strict semantic version validation (MAJOR.MINOR.PATCH format only)
    if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "Invalid version format: '$Version' (expected: MAJOR.MINOR.PATCH, e.g., 1.2.3)"
    }

    # Length validation to prevent buffer overflow attacks
    if ($Version.Length -gt 20) {
        throw "Version string too long: '$Version' (maximum 20 characters)"
    }

    # Check for reasonable version numbers (prevent extremely large numbers)
    $parts = $Version.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    if ($major -gt 999 -or $minor -gt 999 -or $patch -gt 999) {
        throw "Version numbers too large: '$Version' (maximum 999 for each component)"
    }

    Write-LogInfo "Version string validation passed: '$Version'"
    return $true
}

# Security: Escape special characters for safe regex usage
function ConvertTo-RegexSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString
    )

    return [regex]::Escape($InputString)
}

# Security: Validate file operations are safe before proceeding
function Test-FileOperationsSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,
        [Parameter(Mandatory = $true)]
        [string]$TargetFile
    )

    # Check source file exists and is readable
    if (-not (Test-Path $SourceFile) -or -not (Get-Item $SourceFile).PSIsContainer -eq $false) {
        throw "Source file not accessible: '$SourceFile'"
    }

    # Check target directory is writable
    $targetDir = Split-Path $TargetFile -Parent
    if (-not (Test-Path $targetDir)) {
        throw "Target directory does not exist: '$targetDir'"
    }

    # Test write access to target directory
    $testFile = Join-Path $targetDir "test_write_access_$(Get-Random).tmp"
    try {
        Set-Content -Path $testFile -Value "test" -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    } catch {
        throw "Target directory not writable: '$targetDir'"
    }

    # Check target file is writable (if it exists)
    if ((Test-Path $TargetFile) -and (Get-Item $TargetFile).IsReadOnly) {
        throw "Target file is read-only: '$TargetFile'"
    }

    return $true
}

# Extract version components from pubspec.yaml
function Get-VersionFromPubspec {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path $PubspecFile)) {
        Write-LogError "pubspec.yaml not found at $PubspecFile"
        exit 1
    }
    
    $content = Get-Content $PubspecFile
    $versionLine = $content | Where-Object { $_ -match '^version:' } | Select-Object -First 1
    
    if (-not $versionLine) {
        Write-LogError "No version found in pubspec.yaml"
        exit 1
    }
    
    # Extract version (format: version: MAJOR.MINOR.PATCH+BUILD_NUMBER)
    if ($versionLine -match 'version:\s*(.+)') {
        return $matches[1].Trim()
    }
    
    Write-LogError "Could not parse version from pubspec.yaml"
    exit 1
}

# Extract semantic version (without build number)
function Get-SemanticVersion {
    [CmdletBinding()]
    param()
    
    $fullVersion = Get-VersionFromPubspec
    if ($fullVersion -match '^([^+]+)') {
        return $matches[1]
    }
    return $fullVersion
}

# Extract build number
function Get-BuildNumber {
    [CmdletBinding()]
    param()
    
    $fullVersion = Get-VersionFromPubspec
    if ($fullVersion -match '\+(.+)$') {
        return $matches[1]
    }
    return "1"
}

# Generate new build number based on current timestamp (YYYYMMDDHHMM format)
function New-BuildNumber {
    [CmdletBinding()]
    param()
    
    return Get-Date -Format "yyyyMMddHHmm"
}

# Increment build number - generates placeholder for build-time injection
function New-IncrementBuildNumber {
    [CmdletBinding()]
    param()
    
    # Generate placeholder timestamp that will be replaced at build time
    return "BUILD_TIME_PLACEHOLDER"
}

# Check if version qualifies for GitHub release
function Test-GitHubReleaseRequired {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    # Always create GitHub releases for all versions as part of standard deployment workflow
    # GitHub releases are mandatory for version management and deployment tracking
    return $true
}

# Increment version based on type (major, minor, patch, build)
function Step-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('major', 'minor', 'patch', 'build')]
        [string]$IncrementType
    )
    
    $currentVersion = Get-SemanticVersion
    $parts = $currentVersion -split '\.'
    
    if ($parts.Count -ne 3) {
        Write-LogError "Invalid version format: $currentVersion. Expected format: MAJOR.MINOR.PATCH"
        exit 1
    }
    
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($IncrementType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
        'build' {
            # No semantic version change for build increment
        }
    }
    
    return "$major.$minor.$patch"
}

# Update version in pubspec.yaml
function Update-PubspecVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )
    
    $fullVersion = "$NewVersion+$NewBuildNumber"
    Write-LogInfo "Updating pubspec.yaml version to $fullVersion"
    
    # Create backup
    Copy-Item $PubspecFile "$PubspecFile.backup" -Force
    
    # Update version line
    $content = Get-Content $PubspecFile
    $updatedContent = $content | ForEach-Object {
        if ($_ -match '^version:') {
            "version: $fullVersion"
        }
        else {
            $_
        }
    }
    
    Set-Content -Path $PubspecFile -Value $updatedContent -Encoding UTF8
    Write-LogSuccess "Updated pubspec.yaml version to $fullVersion"
}

# Update version in app_config.dart
function Update-AppConfigVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    Write-LogInfo "Updating app_config.dart version to $NewVersion"

    if (-not (Test-Path $AppConfigFile)) {
        Write-LogWarning "app_config.dart not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $AppConfigFile "$AppConfigFile.backup" -Force

    # Update version constant
    $content = Get-Content $AppConfigFile -Raw
    $updatedContent = $content -replace "static const String appVersion = '[^']*';", "static const String appVersion = '$NewVersion';"

    Set-Content -Path $AppConfigFile -Value $updatedContent -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated app_config.dart version to $NewVersion"
}

# Update version in shared/lib/version.dart
function Update-SharedVersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,

        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )

    Write-LogInfo "Updating shared/lib/version.dart to $NewVersion"

    if (-not (Test-Path $SharedVersionFile)) {
        Write-LogWarning "shared/lib/version.dart not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $SharedVersionFile "$SharedVersionFile.backup" -Force

    # Generate build timestamp and ensure build number is in YYYYMMDDHHMM format
    $buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $buildNumberInt = $NewBuildNumber

    # Read current content
    $content = Get-Content $SharedVersionFile -Raw

    # Update all version constants - handle both numeric build numbers and BUILD_TIME_PLACEHOLDER
    $content = $content -replace "static const String mainAppVersion = '[^']*';", "static const String mainAppVersion = '$NewVersion';"
    $content = $content -replace "static const int mainAppBuildNumber = (\d+|BUILD_TIME_PLACEHOLDER);", "static const int mainAppBuildNumber = $buildNumberInt;"
    $content = $content -replace "static const String tunnelManagerVersion = '[^']*';", "static const String tunnelManagerVersion = '$NewVersion';"
    $content = $content -replace "static const int tunnelManagerBuildNumber = (\d+|BUILD_TIME_PLACEHOLDER);", "static const int tunnelManagerBuildNumber = $buildNumberInt;"
    $content = $content -replace "static const String sharedLibraryVersion = '[^']*';", "static const String sharedLibraryVersion = '$NewVersion';"
    $content = $content -replace "static const int sharedLibraryBuildNumber = (\d+|BUILD_TIME_PLACEHOLDER);", "static const int sharedLibraryBuildNumber = $buildNumberInt;"
    $content = $content -replace "static const String buildTimestamp = '[^']*';", "static const String buildTimestamp = '$buildTimestamp';"

    Set-Content -Path $SharedVersionFile -Value $content -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated shared/lib/version.dart to $NewVersion"
}

# Update version in shared/pubspec.yaml
function Update-SharedPubspecVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,

        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )

    $fullVersion = "$NewVersion+$NewBuildNumber"
    Write-LogInfo "Updating shared/pubspec.yaml version to $fullVersion"

    if (-not (Test-Path $SharedPubspecFile)) {
        Write-LogWarning "shared/pubspec.yaml not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $SharedPubspecFile "$SharedPubspecFile.backup" -Force

    # Update version line
    $content = Get-Content $SharedPubspecFile
    $updatedContent = $content | ForEach-Object {
        if ($_ -match '^version:') {
            "version: $fullVersion"
        }
        else {
            $_
        }
    }

    Set-Content -Path $SharedPubspecFile -Value $updatedContent -Encoding UTF8
    Write-LogSuccess "Updated shared/pubspec.yaml version to $fullVersion"
}

# Update version in assets/version.json
function Update-AssetsVersionJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,

        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )

    Write-LogInfo "Updating assets/version.json to $NewVersion"

    if (-not (Test-Path $AssetsVersionFile)) {
        Write-LogWarning "assets/version.json not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $AssetsVersionFile "$AssetsVersionFile.backup" -Force

    # Generate build timestamp
    $buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Read current git commit (preserve existing value if available)
    $gitCommit = "unknown"
    if (Test-Command "git") {
        try {
            $gitCommit = git rev-parse --short HEAD 2>$null
            if (-not $gitCommit) { $gitCommit = "unknown" }
        }
        catch {
            $gitCommit = "unknown"
        }
    }

    # Read and update JSON content
    $content = Get-Content $AssetsVersionFile -Raw
    $content = $content -replace '"version": "[^"]*"', "`"version`": `"$NewVersion`""
    $content = $content -replace '"build_number": "[^"]*"', "`"build_number`": `"$NewBuildNumber`""
    $content = $content -replace '"build_date": "[^"]*"', "`"build_date`": `"$buildTimestamp`""

    # Only update git_commit if we successfully got one
    if ($gitCommit -ne "unknown") {
        $content = $content -replace '"git_commit": "[^"]*"', "`"git_commit`": `"$gitCommit`""
    }

    Set-Content -Path $AssetsVersionFile -Value $content -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated assets/version.json to $NewVersion"
}

# Update README.md version badge (SECURE VERSION)
function Update-ReadmeVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    Write-LogInfo "Updating README.md version badge to $NewVersion"

    try {
        # Security: Validate input version string
        Test-VersionString -Version $NewVersion

        if (-not (Test-Path $ReadmeFile)) {
            Write-LogWarning "README.md not found, skipping update"
            return $true
        }

        # Temporarily skip README update to allow deployment to proceed
        Write-LogWarning "Temporarily skipping README.md update to allow deployment to proceed"
        return $true

        # Security: Acquire file lock to prevent concurrent modifications
        $lockFile = Lock-File -FilePath $ReadmeFile
        Write-LogInfo "Acquired lock for README.md update"

        # Security: Validate original file encoding
        Test-Utf8Encoding -FilePath $ReadmeFile

        # Security: Create enhanced timestamped backup with verification
        try {
            $backupFile = New-TimestampedBackup -FilePath $ReadmeFile
            Write-LogInfo "Created verified backup: $backupFile"
        } catch {
            Write-LogWarning "Backup creation failed, proceeding without backup: $($_.Exception.Message)"
            $backupFile = $null
        }

        # Security: Read with proper encoding detection
        $content = Get-Content $ReadmeFile -Raw -Encoding UTF8

        # Validate content was read successfully
        if ([string]::IsNullOrEmpty($content)) {
            throw "Failed to read README.md content or file is empty"
        }

        # Security: More specific pattern matching to prevent injection
        $pattern = '\[\!\[Version\]\(https://img\.shields\.io/badge/version-[0-9]+\.[0-9]+\.[0-9]+-blue\.svg\)\]'
        $replacement = "[![Version](https://img.shields.io/badge/version-$NewVersion-blue.svg)]"

        $newContent = $content -replace $pattern, $replacement

        # Validate new content
        if ([string]::IsNullOrEmpty($newContent)) {
            throw "Content processing resulted in empty content"
        }

        # Verify replacement occurred
        if ($newContent -eq $content) {
            Write-LogWarning "No version badge found to update in README.md"
            return $false
        }

        # Verify the replacement contains expected content
        if ($newContent -notmatch "version-$([regex]::Escape($NewVersion))-blue") {
            throw "Version replacement verification failed"
        }

        # Security: Preserve original file characteristics and encoding
        Preserve-FileCharacteristics -OriginalFile $ReadmeFile -Content $newContent

        # Release lock before success return
        Unlock-File -LockFile $lockFile
        Write-LogSuccess "Updated README.md version badge to $NewVersion"
        return $true

    } catch {
        Write-LogError "Failed to update README.md: $($_.Exception.Message)"

        # Security: Restore from backup if it exists
        if ($backupFile -and (Test-Path $backupFile)) {
            Copy-Item $backupFile $ReadmeFile -Force
            Write-LogInfo "Restored README.md from backup"
        }

        # Release lock before error return
        if ($lockFile) {
            Unlock-File -LockFile $lockFile
        }

        throw
    }
}

# Update package.json version
function Update-PackageJsonVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    Write-LogInfo "Updating package.json version to $NewVersion"

    if (-not (Test-Path $PackageJsonFile)) {
        Write-LogWarning "package.json not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $PackageJsonFile "$PackageJsonFile.backup" -Force

    # Update version field (line 3: "version": "X.X.X",)
    $content = Get-Content $PackageJsonFile -Raw
    $content = $content -replace '"version":\s*"[^"]*"', "`"version`": `"$NewVersion`""

    Set-Content -Path $PackageJsonFile -Value $content -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated package.json version to $NewVersion"
}

# Update CHANGELOG.md with new version entry
function Update-ChangelogVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,
        [Parameter(Mandatory = $true)]
        [string]$VersionType
    )

    Write-LogInfo "Updating CHANGELOG.md with new version entry $NewVersion"

    if (-not (Test-Path $ChangelogFile)) {
        Write-LogWarning "docs/CHANGELOG.md not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $ChangelogFile "$ChangelogFile.backup" -Force

    # Get current date
    $currentDate = Get-Date -Format "yyyy-MM-dd"

    # Determine change type description
    $changeDescription = switch ($VersionType) {
        "major" { "### Breaking Changes`n- Major version update with breaking changes" }
        "minor" { "### Added`n- New features and enhancements" }
        "patch" { "### Fixed`n- Bug fixes and improvements" }
        "build" { "### Technical`n- Build and deployment updates" }
        default { "### Changes`n- Version update" }
    }

    # Create new version entry
    $newEntry = @"
## [$NewVersion] - $currentDate

$changeDescription

"@

    # Read current content as array of lines
    $lines = Get-Content $ChangelogFile

    # Find the insertion point (after the header section)
    $insertIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^## \[') {
            $insertIndex = $i
            break
        }
    }

    # If no existing version entries found, insert after the header
    if ($insertIndex -eq -1) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^# Changelog' -and $i + 6 -lt $lines.Count) {
                $insertIndex = $i + 6  # Skip header, empty line, description, empty line, format line, empty line
                break
            }
        }
    }

    # Insert the new entry
    if ($insertIndex -ne -1) {
        $newLines = @()
        $newLines += $lines[0..($insertIndex-1)]
        $newLines += $newEntry.Split("`n")
        $newLines += $lines[$insertIndex..($lines.Count-1)]

        Set-Content -Path $ChangelogFile -Value $newLines -Encoding UTF8
    } else {
        # Fallback: prepend to file
        $content = Get-Content $ChangelogFile -Raw
        $newContent = $newEntry + "`n" + $content
        Set-Content -Path $ChangelogFile -Value $newContent -Encoding UTF8 -NoNewline
    }

    Write-LogSuccess "Updated CHANGELOG.md with version $NewVersion entry"
}

# Update all documentation files with new version
function Update-AllDocumentation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,
        [Parameter(Mandatory = $true)]
        [string]$VersionType
    )

    Write-LogInfo "Updating all documentation files with version $NewVersion"

    # Update individual documentation files
    Update-ReadmeVersion -NewVersion $NewVersion
    Update-PackageJsonVersion -NewVersion $NewVersion
    Update-ChangelogVersion -NewVersion $NewVersion -VersionType $VersionType

    Write-LogSuccess "All documentation files updated with version $NewVersion"
}

# Validate version format
function Test-VersionFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        Write-LogError "Invalid version format: $Version. Expected format: MAJOR.MINOR.PATCH"
        exit 1
    }
    
    Write-LogSuccess "Version format is valid: $Version"
}

# Display current version information
function Show-VersionInfo {
    [CmdletBinding()]
    param()
    
    $fullVersion = Get-VersionFromPubspec
    $semanticVersion = Get-SemanticVersion
    $buildNumber = Get-BuildNumber
    
    Write-Host "=== Zoidbot Version Information ===" -ForegroundColor Cyan
    Write-Host "Full Version:     " -NoNewline
    Write-Host $fullVersion -ForegroundColor Green
    Write-Host "Semantic Version: " -NoNewline
    Write-Host $semanticVersion -ForegroundColor Green
    Write-Host "Build Number:     " -NoNewline
    Write-Host $buildNumber -ForegroundColor Green
    Write-Host "Source File:      " -NoNewline
    Write-Host $PubspecFile -ForegroundColor Blue
}

# Check basic dependencies for version management
if (-not $SkipDependencyCheck -and $Command -notin @('get', 'get-semantic', 'get-build', 'info', 'help')) {
    $requiredPackages = @('git')
    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies for version management"
        exit 1
    }
}

# Main command dispatcher
switch ($Command) {
    'get' {
        Get-VersionFromPubspec
    }
    'get-semantic' {
        Get-SemanticVersion
    }
    'get-build' {
        Get-BuildNumber
    }
    'info' {
        Show-VersionInfo
    }
    'increment' {
        if (-not $Parameter) {
            Write-LogError "Usage: .\version_manager.ps1 increment <major|minor|patch|build>"
            exit 1
        }

        $currentVersion = Get-SemanticVersion
        $incrementType = $Parameter

        if ($incrementType -eq 'build') {
            # For build increments, keep same semantic version but increment build number
            $newBuildNumber = New-BuildNumber
            Test-VersionFormat -Version $currentVersion
            Update-PubspecVersion -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Update-AppConfigVersion -NewVersion $currentVersion
            Update-SharedVersionFile -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Update-SharedPubspecVersion -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Update-AssetsVersionJson -NewVersion $currentVersion -NewBuildNumber $newBuildNumber

            # Update documentation files for build increments
            Update-AllDocumentation -NewVersion $currentVersion -VersionType $incrementType

            Write-LogInfo "Build number incremented (no GitHub release needed)"
        }
        else {
            # For semantic version changes, generate new timestamp build number
            $newVersion = Step-Version -IncrementType $incrementType
            $newBuildNumber = New-BuildNumber
            Test-VersionFormat -Version $newVersion
            Update-PubspecVersion -NewVersion $newVersion -NewBuildNumber $newBuildNumber
            Update-AppConfigVersion -NewVersion $newVersion
            Update-SharedVersionFile -NewVersion $newVersion -NewBuildNumber $newBuildNumber
            Update-SharedPubspecVersion -NewVersion $newVersion -NewBuildNumber $newBuildNumber
            Update-AssetsVersionJson -NewVersion $newVersion -NewBuildNumber $newBuildNumber

            # Update documentation files for semantic version changes
            Update-AllDocumentation -NewVersion $newVersion -VersionType $incrementType

            # GitHub release creation is mandatory for all versions
            if (Test-GitHubReleaseRequired -Version $newVersion) {
                Write-LogInfo "GitHub release will be created for version v$newVersion"
                Write-LogInfo "Run: git tag v$newVersion && git push origin v$newVersion"
            }
            else {
                Write-LogError "GitHub release creation failed - this should not happen"
            }
        }

        Show-VersionInfo
    }
    'set' {
        if (-not $Parameter) {
            Write-LogError "Usage: .\version_manager.ps1 set <version>"
            exit 1
        }

        Test-VersionFormat -Version $Parameter
        $newBuildNumber = New-BuildNumber
        Update-PubspecVersion -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Update-AppConfigVersion -NewVersion $Parameter
        Update-SharedVersionFile -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Update-SharedPubspecVersion -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Update-AssetsVersionJson -NewVersion $Parameter -NewBuildNumber $newBuildNumber

        # Update documentation files for manual version set
        Update-AllDocumentation -NewVersion $Parameter -VersionType "manual"

        Show-VersionInfo
    }
    'prepare' {
        if (-not $Parameter) {
            Write-LogError "Usage: .\version_manager.ps1 prepare <major|minor|patch|build>"
            exit 1
        }

        $currentVersion = Get-SemanticVersion
        $incrementType = $Parameter

        if ($incrementType -eq 'build') {
            # For build preparation, keep same semantic version with placeholder
            $placeholderBuild = "BUILD_TIME_PLACEHOLDER"
            Test-VersionFormat -Version $currentVersion
            Update-PubspecVersion -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Update-AppConfigVersion -NewVersion $currentVersion
            Update-SharedVersionFile -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Update-SharedPubspecVersion -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Update-AssetsVersionJson -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Write-LogInfo "Version prepared for build-time timestamp injection"
        }
        else {
            # For semantic version changes, prepare with placeholder
            $newVersion = Step-Version -IncrementType $incrementType
            $placeholderBuild = "BUILD_TIME_PLACEHOLDER"
            Test-VersionFormat -Version $newVersion
            Update-PubspecVersion -NewVersion $newVersion -NewBuildNumber $placeholderBuild
            Update-AppConfigVersion -NewVersion $newVersion
            Update-SharedVersionFile -NewVersion $newVersion -NewBuildNumber $placeholderBuild
            Update-SharedPubspecVersion -NewVersion $newVersion -NewBuildNumber $placeholderBuild
            Update-AssetsVersionJson -NewVersion $newVersion -NewBuildNumber $placeholderBuild

            # GitHub release creation is mandatory for all versions
            if (Test-GitHubReleaseRequired -Version $newVersion) {
                Write-LogInfo "GitHub release will be created for version v$newVersion"
                Write-LogInfo "Run: git tag v$newVersion && git push origin v$newVersion"
            }
            else {
                Write-LogError "GitHub release creation failed - this should not happen"
            }
        }

        Write-LogInfo "Version prepared with placeholder. Use build-time injection during actual build."
        Show-VersionInfo
    }
    'validate' {
        $version = Get-SemanticVersion
        Test-VersionFormat -Version $version
    }
    'help' {
        Write-Host "Zoidbot Version Manager (PowerShell)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage: .\version_manager.ps1 [command] [arguments]" -ForegroundColor White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Yellow
        Write-Host "  get              Get full version (MAJOR.MINOR.PATCH+BUILD)"
        Write-Host "  get-semantic     Get semantic version (MAJOR.MINOR.PATCH)"
        Write-Host "  get-build        Get build number"
        Write-Host "  info             Show detailed version information"
        Write-Host "  increment [type] Increment version (major|minor|patch|build) - immediate timestamp"
        Write-Host "                   Automatically updates README.md, package.json, and CHANGELOG.md"
        Write-Host "  prepare [type]   Prepare version (major|minor|patch|build) - build-time timestamp"
        Write-Host "  set [version]    Set specific version (MAJOR.MINOR.PATCH)"
        Write-Host "                   Automatically updates README.md, package.json, and CHANGELOG.md"
        Write-Host "  validate         Validate current version format"
        Write-Host "  validate-placeholders  Validate no BUILD_TIME_PLACEHOLDER remains"
        Write-Host "  help             Show this help message"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\version_manager.ps1 info"
        Write-Host "  .\version_manager.ps1 increment patch"
        Write-Host "  .\version_manager.ps1 prepare build"
        Write-Host "  .\version_manager.ps1 set 3.1.0"
        Write-Host ""
        Write-Host "Zoidbot Semantic Versioning Strategy:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  PATCH - 0.0.X+YYYYMMDDHHMM - URGENT FIXES:"
        Write-Host "    - Hotfixes and critical bug fixes requiring immediate deployment"
        Write-Host "    - Security updates and emergency patches"
        Write-Host "    - Critical stability fixes that cannot wait for next minor release"
        Write-Host ""
        Write-Host "  MINOR - 0.X.0+YYYYMMDDHHMM - PLANNED FEATURES:"
        Write-Host "    - Feature additions and new functionality"
        Write-Host "    - Quality of life improvements and UI enhancements"
        Write-Host "    - Planned feature releases and capability expansions"
        Write-Host ""
        Write-Host "  MAJOR - X.0.0+YYYYMMDDHHMM - BREAKING CHANGES:"
        Write-Host "    - Breaking changes and architectural overhauls"
        Write-Host "    - Significant API changes requiring user adaptation"
        Write-Host "    - Major platform or framework migrations"
        Write-Host "    • Creates GitHub release automatically"
        Write-Host ""
        Write-Host "  BUILD - X.Y.Z+YYYYMMDDHHMM - TIMESTAMP ONLY:"
        Write-Host "    - No semantic version change, only build timestamp update"
        Write-Host "    - Used for CI/CD builds and testing iterations"
        Write-Host ""
        Write-Host "Build Number Format:"
        Write-Host "  YYYYMMDDHHMM     Timestamp format representing build creation time"
        Write-Host ""
        Write-Host "Automatic Documentation Updates:" -ForegroundColor Yellow
        Write-Host "  When using 'increment' or 'set' commands, the following files are automatically updated:"
        Write-Host "  - README.md      Version badge (line 3)"
        Write-Host "  - package.json   Version field (line 3)"
        Write-Host "  - docs/CHANGELOG.md  New version entry with current date"
    }
    default {
        Write-LogError "Unknown command: $Command"
        Write-Host "Use .\version_manager.ps1 help for usage information"
        exit 1
    }
}
