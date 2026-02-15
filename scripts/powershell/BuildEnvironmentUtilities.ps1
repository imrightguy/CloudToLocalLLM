# Zoidbot PowerShell Utilities
# Common functions for WSL integration, logging, and cross-platform operations

[CmdletBinding()]
param()

# Color constants for console output
$Script:Colors = @{
    Red    = 'Red'
    Green  = 'Green'
    Yellow = 'Yellow'
    Blue   = 'Blue'
    Cyan   = 'Cyan'
    White  = 'White'
}

# Logging functions with colored output
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Script:Colors.Blue
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Script:Colors.Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Script:Colors.Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Script:Colors.Red
}

# Test if WSL is available on the system
function Test-WSLAvailable {
    [CmdletBinding()]
    param()
    
    try {
        $null = wsl --list --quiet 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# Get list of installed WSL distributions
function Get-WSLDistributions {
    [CmdletBinding()]
    param()

    if (-not (Test-WSLAvailable)) {
        return @()
    }

    try {
        # Use PowerShell directly to avoid encoding issues
        $output = & wsl --list --verbose 2>$null
        $distributions = @()

        foreach ($line in $output) {
            # Clean up the line
            $cleanLine = $line -replace '\0', '' # Remove null bytes
            $cleanLine = $cleanLine.Trim()

            # Skip header line and empty lines
            if ($cleanLine -match '^\s*NAME\s+STATE\s+VERSION' -or $cleanLine -eq '') {
                continue
            }

            # Match lines with optional asterisk, distribution name, state, and version
            if ($cleanLine -match '^\s*(\*)?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                $distributions += @{
                    Name = $matches[2].Trim()
                    State = $matches[3].Trim()
                    Version = $matches[4].Trim()
                    IsDefault = ($matches[1] -eq '*')
                }
            }
        }

        return $distributions
    }
    catch {
        Write-LogError "Failed to get WSL distributions: $($_.Exception.Message)"
        return @()
    }
}

# Test if a specific WSL distribution is available and running
function Test-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    $distributions = Get-WSLDistributions
    $distro = $distributions | Where-Object { $_.Name -eq $DistroName }
    
    return ($null -ne $distro -and $distro.State -eq 'Running')
}

# Find the best WSL distribution for a specific purpose
function Find-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Arch', 'Ubuntu', 'Debian', 'Any')]
        [string]$Purpose
    )

    $distributions = Get-WSLDistributions

    # Always prioritize Ubuntu as the default distribution
    $ubuntuCandidates = @('Ubuntu-24.04', 'Ubuntu-22.04', 'Ubuntu-20.04', 'Ubuntu', 'ubuntu')

    # First, check for Ubuntu regardless of purpose
    foreach ($candidate in $ubuntuCandidates) {
        $distro = $distributions | Where-Object { $_.Name -ilike "*$candidate*" -and $_.State -eq 'Running' }
        if ($distro) {
            Write-LogInfo "Using default Ubuntu WSL distribution: $($distro.Name)"
            return $distro.Name
        }
    }

    # Fallback to purpose-specific search only if Ubuntu is not available
    switch ($Purpose) {
        'Arch' {
            # Already checked above, return null if not found
            return $null
        }
        'Ubuntu' {
            $candidates = @('Ubuntu', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-24.04')
        }
        'Debian' {
            $candidates = @('Debian', 'Ubuntu', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-24.04')
        }
        'Any' {
            $candidates = $distributions | ForEach-Object { $_.Name }
        }
    }

    foreach ($candidate in $candidates) {
        # Use case-insensitive matching for distribution names
        $distro = $distributions | Where-Object { $_.Name -ilike "*$candidate*" -and $_.State -eq 'Running' }
        if ($distro) {
            return $distro.Name
        }
    }

    return $null
}

# Convert Windows path to WSL path format
function Convert-WindowsPathToWSL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )
    
    # Convert C:\Users\... to /mnt/c/Users/...
    $wslPath = $WindowsPath -replace '^([A-Za-z]):', '/mnt/$1'
    $wslPath = $wslPath -replace '\\', '/'
    $wslPath = $wslPath.ToLower()
    
    return $wslPath
}

# Convert WSL path to Windows path format
function Convert-WSLPathToWindows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WSLPath
    )
    
    # Convert /mnt/c/Users/... to C:\Users\...
    if ($WSLPath -match '^/mnt/([a-z])/(.*)') {
        $drive = $matches[1].ToUpper()
        $path = $matches[2] -replace '/', '\'
        return "${drive}:\$path"
    }
    
    return $WSLPath
}

# Execute a command in WSL with standardized format
function Invoke-WSLCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DistroName = 'Ubuntu-24.04',

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string]$WorkingDirectory = $null,

        [switch]$PassThru,

        [switch]$AsRoot
    )

    # Default to Ubuntu-24.04 if no distribution specified
    if (-not $DistroName -or [string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = 'Ubuntu-24.04'
    }

    # Validate distribution name
    if ($DistroName -isnot [string]) {
        throw "DistroName must be a string, got: $($DistroName.GetType().Name)"
    }

    # Build arguments array for proper command execution
    $wslArgs = @('-d', $DistroName)

    # Add root user flag if requested
    if ($AsRoot) {
        $wslArgs += @('-u', 'root')
    }

    if ($WorkingDirectory) {
        $wslPath = Convert-WindowsPathToWSL -WindowsPath $WorkingDirectory
        $wslArgs += @('--cd', $wslPath)
    }

    $wslArgs += @('--', 'bash', '-c', $Command)

    try {
        if ($PassThru) {
            $result = & wsl @wslArgs
            # Return result even if exit code is non-zero for PassThru mode
            return $result
        }
        else {
            # TRUE real-time output streaming - show output as it happens
            Write-Host "   WSL Output (streaming live):" -ForegroundColor Gray
            
            # Start the WSL process and capture streams
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl"
            $psi.Arguments = ($wslArgs -join " ")
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            
            # Event handlers for real-time output
            $outputAction = {
                if ($Event.SourceEventArgs.Data) {
                    Write-Host "   $(Get-Date -Format 'HH:mm:ss') | WSL: $($Event.SourceEventArgs.Data)" -ForegroundColor Yellow
                }
            }
            
            $errorAction = {
                if ($Event.SourceEventArgs.Data) {
                    Write-Host "   $(Get-Date -Format 'HH:mm:ss') | WSL ERROR: $($Event.SourceEventArgs.Data)" -ForegroundColor Red
                }
            }
            
            # Register event handlers
            Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputAction | Out-Null
            Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorAction | Out-Null
            
            # Start the process and begin reading
            $process.Start() | Out-Null
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            
            # Wait for completion
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            
            # Clean up event handlers
            Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event
            
            Write-Host "   $(Get-Date -Format 'HH:mm:ss') | WSL Command completed with exit code: $exitCode" -ForegroundColor $(if($exitCode -eq 0){'Green'}else{'Red'})
            
            if ($exitCode -ne 0) {
                throw "WSL command failed with exit code $exitCode"
            }
        }
    }
    catch {
        Write-LogError "WSL command execution failed: $($_.Exception.Message)"
        Write-LogError "Command: $Command"
        Write-LogError "Distribution: $DistroName"
        Write-LogError "WSL Args: $($wslArgs -join ' ')"
        throw
    }
}

# Test if a command is available in the current environment
function Test-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )
    
    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

# Test if a command is available in WSL
function Test-WSLCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DistroName = 'Ubuntu-24.04',

        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    try {
        # Use standardized WSL command format
        $result = & wsl -d $DistroName -- bash -c "command -v $CommandName >/dev/null 2>&1 && echo 'found' || echo 'missing'"
        return $result.Trim() -eq "found"
    }
    catch {
        return $false
    }
}

# Configure WSL distribution for automated builds
function Initialize-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName = 'Ubuntu-24.04'
    )

    # Additional validation
    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        Write-LogError "DistroName cannot be null or empty"
        return $false
    }

    Write-LogInfo "Configuring WSL distribution '$DistroName' for automated builds..."

    try {
        # Check if distribution exists and is running
        $distributions = Get-WSLDistributions
        $targetDistro = $distributions | Where-Object { $_.Name -eq $DistroName }

        if (-not $targetDistro) {
            Write-LogWarning "WSL distribution '$DistroName' not found"
            return $false
        }

        if ($targetDistro.State -ne 'Running') {
            Write-LogInfo "Starting WSL distribution '$DistroName'..."
            try {
                & wsl -d $DistroName -- echo "WSL distribution started"
                if ($LASTEXITCODE -ne 0) {
                    Write-LogError "Failed to start WSL distribution '$DistroName'"
                    return $false
                }
            }
            catch {
                Write-LogError "Failed to start WSL distribution '$DistroName': $($_.Exception.Message)"
                return $false
            }
        }

        # Get current user in WSL
        $currentUser = Invoke-WSLCommand -DistroName $DistroName -Command "whoami" -PassThru
        if ($currentUser) {
            $currentUser = $currentUser.Trim()
        } else {
            Write-LogError "Failed to get current user from WSL distribution '$DistroName'"
            return $false
        }

        Write-LogInfo "Current WSL user: $currentUser"

        # Configure passwordless sudo for the current user (if not already configured)
        $sudoersCheck = Invoke-WSLCommand -DistroName $DistroName -Command "sudo grep -q '$currentUser.*NOPASSWD' /etc/sudoers || echo 'NOT_CONFIGURED'" -PassThru -AsRoot

        if ($sudoersCheck -and $sudoersCheck.Trim() -eq 'NOT_CONFIGURED') {
            Write-LogInfo "Configuring passwordless sudo for user '$currentUser'..."
            $sudoersEntry = "$currentUser ALL=(ALL) NOPASSWD: ALL"
            Invoke-WSLCommand -DistroName $DistroName -Command "echo '$sudoersEntry' >> /etc/sudoers" -AsRoot
            Write-LogSuccess "Passwordless sudo configured for '$currentUser'"
        } else {
            Write-LogInfo "Passwordless sudo already configured for '$currentUser'"
        }

        # Verify sudo configuration
        $sudoTest = Invoke-WSLCommand -DistroName $DistroName -Command "sudo -n echo 'sudo_test_passed' 2>/dev/null || echo 'sudo_test_failed'" -PassThru
        if ($sudoTest -and $sudoTest.Trim() -eq 'sudo_test_passed') {
            Write-LogSuccess "WSL distribution '$DistroName' configured successfully for automated builds"
            return $true
        } else {
            Write-LogWarning "Sudo configuration verification failed for '$DistroName'"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to configure WSL distribution '$DistroName': $($_.Exception.Message)"
        return $false
    }
}

# Get the project root directory
function Get-ProjectRoot {
    [CmdletBinding()]
    param()

    $scriptDir = Split-Path -Parent $PSScriptRoot
    return Split-Path -Parent $scriptDir
}

# Ensure directory exists (using approved verb)
function New-DirectoryIfNotExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-LogInfo "Created directory: $Path"
    }
}

# Get file hash (SHA256)
function Get-SHA256Hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

# Install Chocolatey package manager
function Install-Chocolatey {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    # Check if Chocolatey is already installed
    if ((Test-Command "choco") -and -not $Force) {
        Write-LogInfo "Chocolatey is already installed"
        return $true
    }

    Write-LogInfo "Installing Chocolatey package manager..."

    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

        if (-not $isAdmin) {
            Write-LogWarning "Chocolatey installation requires administrator privileges"
            Write-LogInfo "Please run PowerShell as Administrator or install Chocolatey manually"
            return $false
        }

        # Set execution policy for this process
        Set-ExecutionPolicy Bypass -Scope Process -Force

        # Set security protocol
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        # Download and execute Chocolatey installation script
        $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $installScript

        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verify installation
        if (Test-Command "choco") {
            Write-LogSuccess "Chocolatey installed successfully"

            # Show version
            $chocoVersion = choco --version
            Write-LogInfo "Chocolatey version: $chocoVersion"

            return $true
        }
        else {
            throw "Chocolatey installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install Chocolatey: $($_.Exception.Message)"
        Write-LogInfo "Manual installation: https://chocolatey.org/install"
        return $false
    }
}

# Install package using Chocolatey with user consent
function Install-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [string]$VerifyCommand,

        [string]$EstimatedTime = "2-5 minutes",

        [string]$DiskSpace = "100-500 MB",

        [switch]$AutoInstall,

        [switch]$RequiresRestart
    )

    Write-LogInfo "Checking for $DisplayName..."

    # Check if package is already installed via Chocolatey
    try {
        $chocoList = choco list --local-only $PackageName --exact --limit-output
        if ($chocoList -and $chocoList -notlike "*0 packages installed*") {
            Write-LogSuccess "$DisplayName is already installed via Chocolatey"
            return $true
        }
    }
    catch {
        # Chocolatey might not be available, continue with verification command
    }

    # Check if software is available via verification command
    if ($VerifyCommand) {
        try {
            Invoke-Expression $VerifyCommand | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "$DisplayName is already available"
                return $true
            }
        }
        catch {
            # Software not available, proceed with installation
        }
    }

    # Prompt user for installation consent
    if (-not $AutoInstall) {
        Write-Host ""
        Write-Host "[PACKAGE] Package Installation Required" -ForegroundColor Yellow
        Write-Host "================================" -ForegroundColor Yellow
        Write-Host "Package: $DisplayName"
        Write-Host "Estimated Time: $EstimatedTime"
        Write-Host "Disk Space: $DiskSpace"
        if ($RequiresRestart) {
            Write-Host "[WARNING] May require system restart" -ForegroundColor Yellow
        }
        Write-Host ""

        Write-LogWarning "Automated mode: Use -AutoInstall parameter to install dependencies automatically"
        Write-LogWarning "Skipping installation of $DisplayName"
        Write-LogInfo "Manual installation required. Please install $DisplayName and run the script again."
        return $false
    }

    # Check for administrator privileges only if AutoInstall is requested
    if ($AutoInstall) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-LogWarning "Administrator privileges required for installing $DisplayName via Chocolatey"
            Write-LogInfo "Please run PowerShell as Administrator or install $DisplayName manually"
            Write-LogInfo "Skipping automatic installation of $DisplayName"
            return $false
        }
    }

    # Ensure Chocolatey is installed
    if (-not (Install-Chocolatey)) {
        Write-LogError "Cannot install $DisplayName without Chocolatey"
        return $false
    }

    Write-LogInfo "Installing $DisplayName via Chocolatey..."
    Write-LogInfo "This may take $EstimatedTime and use approximately $DiskSpace of disk space"

    # Install with retry logic
    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        try {
            $retryCount++
            Write-LogInfo "Installation attempt $retryCount of $maxRetries..."

            # Execute Chocolatey installation with timeout and non-interactive flags
            choco install $PackageName --yes --no-progress --timeout=300 --force --accept-license --confirm

            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "$DisplayName installed successfully"

                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

                # Verify installation
                if ($VerifyCommand) {
                    Start-Sleep -Seconds 2  # Allow time for installation to complete
                    try {
                        Invoke-Expression $VerifyCommand | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogSuccess "$DisplayName verification passed"
                            return $true
                        }
                        else {
                            throw "Verification command failed"
                        }
                    }
                    catch {
                        Write-LogWarning "$DisplayName installed but verification failed: $($_.Exception.Message)"
                        Write-LogInfo "The software may still be functional. Continuing..."
                        return $true
                    }
                }

                return $true
            }
            else {
                throw "Chocolatey installation failed with exit code $LASTEXITCODE"
            }
        }
        catch {
            Write-LogWarning "Installation attempt $retryCount failed: $($_.Exception.Message)"

            if ($retryCount -lt $maxRetries) {
                Write-LogInfo "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
            else {
                Write-LogError "Failed to install $DisplayName after $maxRetries attempts"
                Write-LogInfo "Please install $DisplayName manually and run the script again"
                return $false
            }
        }
    }

    return $false
}

# Install Windows built-in OpenSSH client
function Install-OpenSSHClient {
    [CmdletBinding()]
    param(
        [switch]$AutoInstall
    )

    Write-LogInfo "Checking for OpenSSH Client..."

    # Check if OpenSSH client is already available
    if (Test-Command "ssh") {
        Write-LogSuccess "OpenSSH Client is already available"
        return $true
    }

    # Check if running on Windows 10/11
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-LogError "OpenSSH Client requires Windows 10 or later"
        return $false
    }

    # Prompt user for installation consent
    if (-not $AutoInstall) {
        Write-Host ""
        Write-Host "[OPENSSH] OpenSSH Client Installation" -ForegroundColor Yellow
        Write-Host "==============================" -ForegroundColor Yellow
        Write-Host "OpenSSH Client is required for VPS deployment operations."
        Write-Host "This will install the Windows built-in OpenSSH client feature."
        Write-Host ""

        Write-LogWarning "Automated mode: Use -AutoInstall parameter to install OpenSSH Client automatically"
        Write-LogWarning "Skipping OpenSSH Client installation"
        return $false
    }

    Write-LogInfo "Installing OpenSSH Client..."

    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

        if (-not $isAdmin) {
            Write-LogWarning "OpenSSH Client installation requires administrator privileges"
            Write-LogInfo "Please run PowerShell as Administrator"
            return $false
        }

        # Install OpenSSH Client capability
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

        # Verify installation
        if (Test-Command "ssh") {
            Write-LogSuccess "OpenSSH Client installed successfully"
            return $true
        }
        else {
            throw "OpenSSH Client installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install OpenSSH Client: $($_.Exception.Message)"
        Write-LogInfo "Try installing via Settings > Apps > Optional Features > OpenSSH Client"
        return $false
    }
}

# Synchronize SSH keys from WSL to Windows
function Sync-SSHKeys {
    [CmdletBinding()]
    param(
        [string]$SourceDistro,
        [switch]$Force,
        [switch]$AutoSync
    )

    Write-LogInfo "Starting SSH key synchronization..."

    # Define key types to look for
    $keyTypes = @(
        @{ Name = "RSA"; PrivateKey = "id_rsa"; PublicKey = "id_rsa.pub" },
        @{ Name = "ED25519"; PrivateKey = "id_ed25519"; PublicKey = "id_ed25519.pub" },
        @{ Name = "ECDSA"; PrivateKey = "id_ecdsa"; PublicKey = "id_ecdsa.pub" }
    )

    # Windows SSH directory
    $windowsSSHDir = Join-Path $env:USERPROFILE ".ssh"
    $backupDir = Join-Path $windowsSSHDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    # Find WSL distribution with SSH keys
    $sourceDistribution = $SourceDistro
    if (-not $sourceDistribution) {
        Write-LogInfo "Scanning WSL distributions for SSH keys..."

        $distributions = Get-WSLDistributions
        $foundKeys = @()

        foreach ($distro in $distributions) {
            if ($distro.State -eq "Running") {
                try {
                    $hasKeys = Invoke-WSLCommand -DistroName $distro.Name -Command "test -d ~/.ssh && ls ~/.ssh/id_* 2>/dev/null | wc -l" -PassThru
                    if ([int]$hasKeys.Trim() -gt 0) {
                        $foundKeys += @{ Distro = $distro.Name; KeyCount = [int]$hasKeys.Trim() }
                    }
                }
                catch {
                    # Continue checking other distributions
                }
            }
        }

        if ($foundKeys.Count -eq 0) {
            Write-LogWarning "No SSH keys found in any WSL distribution"
            return $false
        }

        # Prioritize Ubuntu, then by key count
        $sourceDistribution = ($foundKeys | Sort-Object @{Expression={if($_.Distro -like "*Ubuntu*") {0} else {1}}}, @{Expression={$_.KeyCount}; Descending=$true} | Select-Object -First 1).Distro
        Write-LogInfo "Selected WSL distribution: $sourceDistribution"
    }

    # Verify source distribution has SSH keys
    try {
        $keyList = Invoke-WSLCommand -DistroName $sourceDistribution -Command "ls ~/.ssh/id_* 2>/dev/null || echo 'NO_KEYS'" -PassThru
        if ($keyList -eq "NO_KEYS" -or -not $keyList) {
            Write-LogError "No SSH keys found in WSL distribution: $sourceDistribution"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to access SSH keys in WSL distribution: $sourceDistribution"
        return $false
    }

    # Create Windows SSH directory
    New-DirectoryIfNotExists -Path $windowsSSHDir

    # Check for existing keys and create backup if needed
    $existingKeys = Get-ChildItem -Path $windowsSSHDir -Filter "id_*" -ErrorAction SilentlyContinue
    if ($existingKeys -and -not $Force) {
        if (-not $AutoSync) {
            Write-Host ""
            Write-Host "[SSH] SSH Key Synchronization" -ForegroundColor Yellow
            Write-Host "==========================" -ForegroundColor Yellow
            Write-Host "Existing SSH keys found in Windows SSH directory:"
            $existingKeys | ForEach-Object { Write-Host "  - $($_.Name)" }
            Write-Host ""
            Write-Host "A backup will be created before synchronization."
            Write-Host ""

            Write-LogWarning "Automated mode: Use -AutoSync parameter to synchronize SSH keys automatically"
            Write-LogWarning "Skipping SSH key synchronization"
            return $false
        }

        # Create backup
        Write-LogInfo "Creating backup of existing SSH keys..."
        New-DirectoryIfNotExists -Path $backupDir
        $existingKeys | ForEach-Object {
            Copy-Item $_.FullName $backupDir -Force
        }
        Write-LogSuccess "Backup created: $backupDir"
    }

    # Synchronize each key type
    $syncedKeys = @()
    foreach ($keyType in $keyTypes) {
        try {
            # Check if key exists in WSL
            $privateKeyExists = Invoke-WSLCommand -DistroName $sourceDistribution -Command "test -f ~/.ssh/$($keyType.PrivateKey) && echo 'EXISTS'" -PassThru
            $publicKeyExists = Invoke-WSLCommand -DistroName $sourceDistribution -Command "test -f ~/.ssh/$($keyType.PublicKey) && echo 'EXISTS'" -PassThru

            if ($privateKeyExists -eq "EXISTS" -and $publicKeyExists -eq "EXISTS") {
                Write-LogInfo "Synchronizing $($keyType.Name) key pair..."

                # Copy private key
                $privateKeyPath = Join-Path $windowsSSHDir $keyType.PrivateKey
                $wslPrivateKeyPath = "~/.ssh/$($keyType.PrivateKey)"
                Invoke-WSLCommand -DistroName $sourceDistribution -Command "cat $wslPrivateKeyPath" -PassThru | Set-Content -Path $privateKeyPath -Encoding UTF8

                # Copy public key
                $publicKeyPath = Join-Path $windowsSSHDir $keyType.PublicKey
                $wslPublicKeyPath = "~/.ssh/$($keyType.PublicKey)"
                Invoke-WSLCommand -DistroName $sourceDistribution -Command "cat $wslPublicKeyPath" -PassThru | Set-Content -Path $publicKeyPath -Encoding UTF8

                # Set Windows file permissions
                Set-SSHKeyPermissions -KeyPath $privateKeyPath

                $syncedKeys += $keyType.Name
                Write-LogSuccess "$($keyType.Name) key pair synchronized"
            }
        }
        catch {
            Write-LogWarning "Failed to synchronize $($keyType.Name) key: $($_.Exception.Message)"
        }
    }

    if ($syncedKeys.Count -gt 0) {
        Write-LogSuccess "SSH key synchronization completed"
        Write-LogInfo "Synchronized key types: $($syncedKeys -join ', ')"

        # Update SSH config if needed
        Update-SSHConfig

        return $true
    }
    else {
        Write-LogError "No SSH keys were synchronized"
        return $false
    }
}

# Set proper Windows file permissions for SSH private keys
function Set-SSHKeyPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyPath
    )

    if (-not (Test-Path $KeyPath)) {
        Write-LogError "SSH key not found: $KeyPath"
        return $false
    }

    try {
        Write-LogInfo "Setting secure permissions for SSH key: $(Split-Path -Leaf $KeyPath)"

        # Remove inheritance and explicit permissions
        icacls $KeyPath /inheritance:r /grant:r "$($env:USERNAME):F" /remove "Everyone" /remove "Users" /remove "Authenticated Users" 2>$null | Out-Null

        # Verify permissions were set correctly
        $acl = Get-Acl $KeyPath
        $accessRules = $acl.Access | Where-Object { $_.IdentityReference -like "*$env:USERNAME*" -and $_.FileSystemRights -like "*FullControl*" }

        if ($accessRules) {
            Write-LogSuccess "SSH key permissions set successfully"
            return $true
        }
        else {
            throw "Permission verification failed"
        }
    }
    catch {
        Write-LogError "Failed to set SSH key permissions: $($_.Exception.Message)"
        return $false
    }
}

# Update SSH config file with VPS host configurations
function Update-SSHConfig {
    [CmdletBinding()]
    param(
        [string]$VPSHost = "zoidbot.online",
        [string]$VPSUser = "cloudllm"
    )

    $sshConfigPath = Join-Path $env:USERPROFILE ".ssh\config"
    $configEntry = @"

# Zoidbot VPS Configuration (Auto-generated)
Host zoidbot
    HostName $VPSHost
    User $VPSUser
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa
    IdentityFile ~/.ssh/id_ecdsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host $VPSHost
    User $VPSUser
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa
    IdentityFile ~/.ssh/id_ecdsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

"@

    try {
        # Check if config already contains Zoidbot entries
        if (Test-Path $sshConfigPath) {
            $existingConfig = Get-Content $sshConfigPath -Raw
            if ($existingConfig -like "*Zoidbot VPS Configuration*") {
                Write-LogInfo "SSH config already contains Zoidbot VPS configuration"
                return $true
            }
        }

        # Append configuration
        Add-Content -Path $sshConfigPath -Value $configEntry -Encoding UTF8
        Write-LogSuccess "SSH config updated with VPS configuration"
        return $true
    }
    catch {
        Write-LogError "Failed to update SSH config: $($_.Exception.Message)"
        return $false
    }
}

# Test SSH connectivity to VPS
function Test-SSHConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VPSHost,

        [Parameter(Mandatory = $true)]
        [string]$VPSUser,

        [int]$TimeoutSeconds = 10
    )

    Write-LogInfo "Testing SSH connectivity to $VPSUser@$VPSHost..."

    try {
        # Test SSH connection with timeout
        $testCommand = "ssh -o ConnectTimeout=$TimeoutSeconds -o BatchMode=yes -o StrictHostKeyChecking=no $VPSUser@$VPSHost 'echo SSH_TEST_SUCCESS'"
        $result = Invoke-Expression $testCommand 2>$null

        if ($result -like "*SSH_TEST_SUCCESS*") {
            Write-LogSuccess "SSH connectivity test passed"
            return $true
        }
        else {
            throw "SSH test command did not return expected result"
        }
    }
    catch {
        Write-LogError "SSH connectivity test failed: $($_.Exception.Message)"
        Write-LogInfo "Ensure SSH keys are properly configured and the VPS is accessible"
        return $false
    }
}

# Comprehensive dependency installation function
function Install-BuildDependencies {
    [CmdletBinding()]
    param(
        [switch]$AutoInstall,
        [switch]$SkipDependencyCheck,
        [string[]]$RequiredPackages = @('flutter', 'git', 'openssh')
    )

    if ($SkipDependencyCheck) {
        Write-LogWarning "Skipping dependency check as requested"
        return $true
    }

    Write-LogInfo "Checking build dependencies..."

    $installationResults = @()
    $allSuccessful = $true

    # Install Chocolatey first if needed
    if ($RequiredPackages -contains 'flutter' -or $RequiredPackages -contains 'git' -or $RequiredPackages -contains 'docker' -or $RequiredPackages -contains '7zip' -or $RequiredPackages -contains 'visualstudio') {
        if (-not (Install-Chocolatey)) {
            Write-LogError "Cannot proceed with dependency installation without Chocolatey"
            return $false
        }
    }

    # Define package configurations
    $packageConfigs = @{
        'flutter' = @{
            PackageName = 'flutter'
            DisplayName = 'Flutter SDK'
            VerifyCommand = 'flutter --version'
            EstimatedTime = '5-10 minutes'
            DiskSpace = '1-2 GB'
        }
        'git' = @{
            PackageName = 'git'
            DisplayName = 'Git for Windows'
            VerifyCommand = 'git --version'
            EstimatedTime = '2-3 minutes'
            DiskSpace = '100-200 MB'
        }
        'docker' = @{
            PackageName = 'docker-desktop'
            DisplayName = 'Docker Desktop'
            VerifyCommand = 'docker --version'
            EstimatedTime = '10-15 minutes'
            DiskSpace = '2-3 GB'
            RequiresRestart = $true
        }
        '7zip' = @{
            PackageName = '7zip'
            DisplayName = '7-Zip'
            VerifyCommand = '7z'
            EstimatedTime = '1-2 minutes'
            DiskSpace = '50-100 MB'
        }
        'visualstudio' = @{
            PackageName = 'visualstudio2022buildtools'
            DisplayName = 'Visual Studio Build Tools'
            VerifyCommand = 'where cl'
            EstimatedTime = '15-30 minutes'
            DiskSpace = '3-5 GB'
        }
    }

    # Install each required package
    foreach ($package in $RequiredPackages) {
        if ($package -eq 'openssh') {
            # Handle OpenSSH separately as it's a Windows feature
            $result = Install-OpenSSHClient -AutoInstall:$AutoInstall
            $installationResults += @{ Package = 'OpenSSH Client'; Success = $result }
            if (-not $result) { $allSuccessful = $false }
        }
        elseif ($packageConfigs.ContainsKey($package)) {
            $config = $packageConfigs[$package]
            $installParams = @{
                PackageName = $config.PackageName
                DisplayName = $config.DisplayName
                VerifyCommand = $config.VerifyCommand
                AutoInstall = $AutoInstall
            }
            if ($config.EstimatedTime) { $installParams.EstimatedTime = $config.EstimatedTime }
            if ($config.DiskSpace) { $installParams.DiskSpace = $config.DiskSpace }
            if ($config.RequiresRestart) { $installParams.RequiresRestart = $config.RequiresRestart }

            $result = Install-ChocolateyPackage @installParams
            $installationResults += @{ Package = $config.DisplayName; Success = $result }
            if (-not $result) { $allSuccessful = $false }
        }
        else {
            Write-LogWarning "Unknown package: $package"
        }
    }

    # Show installation summary
    Write-Host ""
    Write-Host "[SUMMARY] Dependency Installation Summary" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    foreach ($result in $installationResults) {
        $status = if ($result.Success) { "[OK] Installed" } else { "[FAIL] Failed" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        Write-Host "$status $($result.Package)" -ForegroundColor $color
    }
    Write-Host ""

    if ($allSuccessful) {
        Write-LogSuccess "All dependencies installed successfully"

        # Check if restart is recommended
        $restartPackages = $installationResults | Where-Object { $_.Package -like "*Docker*" -and $_.Success }
        if ($restartPackages) {
            Write-LogWarning "System restart recommended for Docker Desktop to function properly"
        }
    }
    else {
        Write-LogError "Some dependencies failed to install"
        Write-LogInfo "Please install missing dependencies manually and run the script again"
    }

    return $allSuccessful
}

# Test if WSL Flutter is installed and working
function Test-WSLFlutterInstallation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DistroName = 'Ubuntu-24.04',

        [Parameter(Mandatory = $false)]
        [string]$FlutterPath = '/opt/flutter/bin/flutter'
    )

    try {
        # Check if Flutter binary exists
        $flutterExists = Invoke-WSLCommand -DistroName $DistroName -Command "test -f $FlutterPath && echo 'EXISTS'" -PassThru
        if ($flutterExists -ne "EXISTS") {
            Write-LogWarning "Flutter not found at $FlutterPath in WSL distribution: $DistroName"
            return $false
        }

        # Test Flutter command
        $flutterVersion = Invoke-WSLCommand -DistroName $DistroName -Command "$FlutterPath --version" -PassThru
        if ($LASTEXITCODE -ne 0) {
            Write-LogError "Flutter command failed in WSL distribution: $DistroName"
            return $false
        }

        Write-LogSuccess "WSL Flutter verified: $(($flutterVersion -split "`n")[0])"
        return $true
    }
    catch {
        Write-LogError "Failed to test WSL Flutter installation: $($_.Exception.Message)"
        return $false
    }
}

# Execute Flutter commands via WSL
function Invoke-WSLFlutterCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FlutterArgs,

        [Parameter(Mandatory = $false)]
        [string]$DistroName = 'Ubuntu-24.04',

        [Parameter(Mandatory = $false)]
        [string]$FlutterPath = '/opt/flutter/bin/flutter',

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = $null,

        [switch]$PassThru
    )

    # Verify Flutter is available
    if (-not (Test-WSLFlutterInstallation -DistroName $DistroName -FlutterPath $FlutterPath)) {
        throw "WSL Flutter is not properly installed or configured"
    }

    # Build the complete Flutter command
    $command = "$FlutterPath $FlutterArgs"

    try {
        if ($PassThru) {
            return Invoke-WSLCommand -DistroName $DistroName -Command $command -WorkingDirectory $WorkingDirectory -PassThru
        }
        else {
            Invoke-WSLCommand -DistroName $DistroName -Command $command -WorkingDirectory $WorkingDirectory
        }
    }
    catch {
        Write-LogError "WSL Flutter command failed: $command"
        Write-LogError "Error: $($_.Exception.Message)"
        throw
    }
}

# Test if Windows Flutter is installed and working
function Test-WindowsFlutterInstallation {
    [CmdletBinding()]
    param()

    try {
        # Check if Flutter is in PATH
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if (-not $flutterCommand) {
            Write-LogWarning "Flutter not found in PATH"
            return $false
        }

        # Test Flutter command
        $flutterVersion = flutter --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-LogError "Flutter command failed"
            return $false
        }

        Write-LogSuccess "Windows Flutter verified: $($flutterVersion -split "`n" | Select-Object -First 1)"
        return $true
    }
    catch {
        Write-LogError "Error testing Windows Flutter installation: $($_.Exception.Message)"
        return $false
    }
}

# Execute Flutter commands on Windows
function Invoke-WindowsFlutterCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FlutterArgs,

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = (Get-Location).Path
    )

    try {
        # Verify Flutter is available
        if (-not (Test-WindowsFlutterInstallation)) {
            throw "Windows Flutter is not properly installed or configured"
        }

        # Change to working directory if specified
        $originalLocation = Get-Location
        if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
            Set-Location $WorkingDirectory
        }

        # Execute Flutter command
        Write-LogInfo "Executing: flutter $FlutterArgs"

        # Split arguments properly for PowerShell execution
        $argArray = $FlutterArgs -split '\s+'
        $output = & flutter $argArray 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Flutter command failed with exit code $LASTEXITCODE. Output: $output"
        }

        Write-Output $output
    }
    catch {
        Write-LogError "Windows Flutter command failed: flutter $FlutterArgs"
        Write-LogError "Error: $($_.Exception.Message)"
        throw
    }
    finally {
        # Restore original location
        Set-Location $originalLocation
    }
}

# Install Flutter in WSL if not present
function Install-WSLFlutter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DistroName = 'Ubuntu-24.04',

        [Parameter(Mandatory = $false)]
        [string]$FlutterPath = '/opt/flutter',

        [Parameter(Mandatory = $false)]
        [string]$FlutterVersion = 'stable'
    )

    Write-LogInfo "Installing Flutter in WSL distribution: $DistroName"

    try {
        # Check if Flutter is already installed
        if (Test-WSLFlutterInstallation -DistroName $DistroName -FlutterPath "$FlutterPath/bin/flutter") {
            Write-LogInfo "Flutter is already installed in WSL"
            return $true
        }

        # Install dependencies
        Write-LogInfo "Installing Flutter dependencies..."
        Invoke-WSLCommand -DistroName $DistroName -Command "sudo apt update && sudo apt install -y curl git unzip xz-utils zip libglu1-mesa" -AsRoot

        # Download and install Flutter
        Write-LogInfo "Downloading Flutter SDK..."
        $downloadCommand = @"
cd /tmp && \
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz && \
sudo mkdir -p $FlutterPath && \
sudo tar xf flutter.tar.xz -C /opt/ && \
sudo chown -R `$USER:`$USER $FlutterPath && \
rm flutter.tar.xz
"@

        Invoke-WSLCommand -DistroName $DistroName -Command $downloadCommand

        # Add Flutter to PATH in .bashrc if not already present
        Write-LogInfo "Configuring Flutter PATH..."
        $pathCommand = @"
if ! grep -q '$FlutterPath/bin' ~/.bashrc; then
    echo 'export PATH=`$PATH:$FlutterPath/bin' >> ~/.bashrc
fi
"@
        Invoke-WSLCommand -DistroName $DistroName -Command $pathCommand

        # Verify installation
        if (Test-WSLFlutterInstallation -DistroName $DistroName -FlutterPath "$FlutterPath/bin/flutter") {
            Write-LogSuccess "Flutter successfully installed in WSL"
            return $true
        }
        else {
            Write-LogError "Flutter installation verification failed"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to install Flutter in WSL: $($_.Exception.Message)"
        return $false
    }
}

# Export all functions (only when loaded as a module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # Script is being dot-sourced, functions are automatically available
} else {
    Export-ModuleMember -Function *
}
