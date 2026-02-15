# Zoidbot Update Checker
# This script checks for updates to Zoidbot on GitHub and downloads/installs them if available

# Parse command line arguments
param (
    [switch]$Silent,
    [switch]$AutoInstall
)

# GitHub repository information
$repoOwner = "imrightguy"
$repoName = "Zoidbot"
$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"

# Registry settings
$registryPath = "HKCU:\Software\Zoidbot\Updates"

# Function to get registry settings
function Get-UpdateSettings {
    try {
        if (Test-Path $registryPath) {
            $checkAtStartup = (Get-ItemProperty -Path $registryPath -Name "CheckForUpdatesAtStartup" -ErrorAction SilentlyContinue).CheckForUpdatesAtStartup
            $autoInstall = (Get-ItemProperty -Path $registryPath -Name "AutoInstallUpdates" -ErrorAction SilentlyContinue).AutoInstallUpdates

            return @{
                CheckAtStartup = if ($null -eq $checkAtStartup) { $true } else { $checkAtStartup -eq 1 }
                AutoInstall = if ($null -eq $autoInstall) { $false } else { $autoInstall -eq 1 }
            }
        }

        # Default settings if registry entries don't exist
        return @{
            CheckAtStartup = $true
            AutoInstall = $false
        }
    }
    catch {
        Write-Host "Error reading registry settings: $_"
        # Default settings if there's an error
        return @{
            CheckAtStartup = $true
            AutoInstall = $false
        }
    }
}

# Get the current version from the installed app
function Get-CurrentVersion {
    try {
        # Read version from the app's directory
        $versionFile = Join-Path $PSScriptRoot "version.txt"
        if (Test-Path $versionFile) {
            $version = Get-Content $versionFile -Raw
            return $version.Trim()
        }

        # Fallback: Try to extract version from the executable name
        $exePath = Join-Path $PSScriptRoot "Zoidbot-*.exe"
        $exeFile = Get-ChildItem -Path $exePath | Select-Object -First 1
        if ($exeFile) {
            $match = [regex]::Match($exeFile.Name, "Zoidbot-(\d+\.\d+\.\d+)\.exe")
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }

        # If we can't determine the version, return a default
        return "0.0.0"
    }
    catch {
        Write-Host "Error getting current version: $_"
        return "0.0.0"
    }
}

# Check for updates
function Check-ForUpdates {
    try {
        Write-Host "Checking for updates..."

        # Get current version
        $currentVersion = Get-CurrentVersion
        Write-Host "Current version: $currentVersion"

        # Get latest release from GitHub
        $headers = @{
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "PowerShell-UpdateScript"
        }

        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
        $latestVersion = $response.tag_name -replace 'v', ''

        Write-Host "Latest version: $latestVersion"

        # Compare versions
        if ([version]$latestVersion -gt [version]$currentVersion) {
            Write-Host "New version available: $latestVersion"
            return @{
                NewVersionAvailable = $true
                LatestVersion = $latestVersion
                DownloadUrl = ($response.assets | Where-Object { $_.name -like "*Windows*Setup.exe" }).browser_download_url
                ReleaseNotes = $response.body
            }
        }
        else {
            Write-Host "You have the latest version."
            return @{
                NewVersionAvailable = $false
                LatestVersion = $latestVersion
            }
        }
    }
    catch {
        Write-Host "Error checking for updates: $_"
        return @{
            NewVersionAvailable = $false
            Error = $_.Exception.Message
        }
    }
}

# Download and install update
function Install-Update {
    param (
        [string]$downloadUrl
    )

    try {
        Write-Host "Downloading update..."
        $tempFile = Join-Path $env:TEMP "Zoidbot-Update.exe"

        # Download the installer
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile

        # Run the installer
        Write-Host "Installing update..."
        Start-Process -FilePath $tempFile -ArgumentList "/SILENT" -Wait

        # Clean up
        Remove-Item -Path $tempFile -Force

        Write-Host "Update completed successfully!"
        return $true
    }
    catch {
        Write-Host "Error installing update: $_"
        return $false
    }
}

# Main function
function Main {
    param (
        [switch]$Silent,
        [switch]$AutoInstall
    )

    # If no command line parameters are provided, check registry settings
    if (-not $PSBoundParameters.ContainsKey('Silent') -and -not $PSBoundParameters.ContainsKey('AutoInstall')) {
        $settings = Get-UpdateSettings
        $Silent = $settings.CheckAtStartup
        $AutoInstall = $settings.AutoInstall
    }

    # Check if running with admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin -and -not $Silent) {
        Write-Host "This script requires administrator privileges to install updates."

        # Try to restart with admin privileges
        $scriptPath = $MyInvocation.MyCommand.Path
        $arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
        if ($Silent) { $arguments += " -Silent" }
        if ($AutoInstall) { $arguments += " -AutoInstall" }

        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    }

    # Check for updates
    $updateInfo = Check-ForUpdates

    if ($updateInfo.NewVersionAvailable) {
        if ($Silent) {
            # In silent mode, just return the result or notify the application
            if ($AutoInstall) {
                $result = Install-Update -downloadUrl $updateInfo.DownloadUrl
                if ($result) {
                    Write-Host "UPDATE_INSTALLED"
                    return @{ Status = "UPDATE_INSTALLED"; Version = $updateInfo.LatestVersion }
                } else {
                    Write-Host "UPDATE_FAILED"
                    return @{ Status = "UPDATE_FAILED"; Error = "Failed to install update" }
                }
            } else {
                Write-Host "UPDATE_AVAILABLE"
                return @{ Status = "UPDATE_AVAILABLE"; Version = $updateInfo.LatestVersion }
            }
        } else {
            # Automated mode (no interactive prompts)
            Write-Host "`nRelease Notes:`n$($updateInfo.ReleaseNotes)`n"

            # Automatically install the update in automated mode
            Write-Host "Automated mode: Installing update automatically..."
            $result = Install-Update -downloadUrl $updateInfo.DownloadUrl
            if ($result) {
                Write-Host "Update installed successfully. Please restart the application."
            }
            else {
                Write-Host "Failed to install update."
            }
        }
    } else {
        if ($Silent) {
            Write-Host "NO_UPDATE"
            return @{ Status = "NO_UPDATE" }
        } else {
            # Pause to show results
            Write-Host "`nPress any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# Run the main function with parameters
Main -Silent:$Silent -AutoInstall:$AutoInstall
