# Zoidbot Complete Release Assets Builder
# Creates all release assets: Windows portable ZIP, Windows installer, and checksums

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipBuild,
    [switch]$SkipInstaller,
    [switch]$InstallInnoSetup,
    [switch]$Force,
    [switch]$Help,
    [string]$Version
)

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    Write-Host "BuildEnvironmentUtilities module not found, using basic functions" -ForegroundColor Yellow
    
    # Basic logging functions if utilities not available
    function Write-LogInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
    function Write-LogSuccess { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogWarning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Get-ProjectRoot { return (Get-Location).Path }
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$OutputDir = Join-Path $ProjectRoot "dist"
$WindowsBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$WindowsOutputDir = Join-Path $OutputDir "windows"
$InstallerScriptPath = Join-Path $ProjectRoot "build-tools\installers\windows\Basic.iss"

# Get version - prioritize parameter, then environment variable, then version manager
if (-not $Version) {
    $Version = $env:BUILD_VERSION
}

if (-not $Version) {
    # Get version from version manager
    $versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionManagerPath) {
        $Version = & $versionManagerPath get-semantic
    } else {
        # Fallback to reading from pubspec.yaml
        $pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
        if (Test-Path $pubspecPath) {
            $pubspecContent = Get-Content $pubspecPath
            $versionLine = $pubspecContent | Where-Object { $_ -match "^version:" }
            if ($versionLine) {
                $Version = ($versionLine -split ":")[1].Trim() -replace "\+.*", ""
            } else {
                $Version = "0.0.0"
            }
        } else {
            $Version = "0.0.0"
        }
    }
}

function Show-Help {
    Write-Host "Zoidbot Complete Release Assets Builder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\Build-GitHubReleaseAssets.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Clean            Clean build directories first"
    Write-Host "  -SkipBuild        Skip Flutter build step"
    Write-Host "  -SkipInstaller    Skip Windows installer creation"
    Write-Host "  -InstallInnoSetup Install Inno Setup if not found"
    Write-Host "  -Force            Force reinstall dependencies"
    Write-Host "  -Version <string> Override version (defaults to version manager or pubspec.yaml)"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "This script creates all GitHub release assets:"
    Write-Host "  • Windows portable ZIP package"
    Write-Host "  • Windows installer (Setup.exe)"
    Write-Host "  • SHA256 checksums for all packages"
}

function New-DirectoryIfNotExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-LogInfo "Created directory: $Path"
    }
}

function Test-InnoSetup {
    $innoSetupPaths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    )
    
    foreach ($path in $innoSetupPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Install-InnoSetup {
    Write-LogInfo "Installing Inno Setup..."
    
    $downloadUrl = "https://jrsoftware.org/download.php/is.exe"
    $tempFile = Join-Path $env:TEMP "innosetup.exe"
    
    try {
        Write-LogInfo "Downloading Inno Setup installer..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        
        Write-LogInfo "Running Inno Setup installer..."
        Start-Process -FilePath $tempFile -ArgumentList "/SILENT" -Wait
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        # Verify installation
        $innoPath = Test-InnoSetup
        if ($innoPath) {
            Write-LogSuccess "Inno Setup installed successfully at: $innoPath"
            return $innoPath
        } else {
            throw "Inno Setup installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install Inno Setup: $($_.Exception.Message)"
        throw
    }
}

function Build-FlutterWindows {
    Write-LogInfo "Building Flutter application for Windows..."

    try {
        # Verify Windows Flutter is available
        if (-not (Test-WindowsFlutterInstallation)) {
            throw "Windows Flutter is not properly installed or configured"
        }

        if ($Clean) {
            Write-LogInfo "Cleaning Flutter build..."
            Invoke-WindowsFlutterCommand -FlutterArgs "clean" -WorkingDirectory $ProjectRoot
        }

        Write-LogInfo "Running flutter pub get..."
        Invoke-WindowsFlutterCommand -FlutterArgs "pub get" -WorkingDirectory $ProjectRoot

        Write-LogInfo "Running flutter build windows --release..."
        $buildArgs = "build windows --release"
        Invoke-WindowsFlutterCommand -FlutterArgs $buildArgs -WorkingDirectory $ProjectRoot

        $mainExecutable = Join-Path $WindowsBuildDir "zoidbot.exe"
        if (-not (Test-Path $mainExecutable)) {
            throw "Flutter Windows executable not found after build at: $mainExecutable"
        }

        Write-LogSuccess "Windows Flutter application built successfully"
    }
    catch {
        Write-LogError "Flutter build failed: $($_.Exception.Message)"
        throw
    }
}

function New-PortableZipPackage {
    Write-LogInfo "Creating portable ZIP package..."
    
    $packageName = "zoidbot-$Version-portable.zip"
    New-DirectoryIfNotExists -Path $WindowsOutputDir
    
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build directory not found. Run Flutter build first."
    }
    
    $zipPath = Join-Path $WindowsOutputDir $packageName
    
    Write-LogInfo "Creating ZIP archive: $packageName"
    Compress-Archive -Path "$WindowsBuildDir\*" -DestinationPath $zipPath -Force
    
    # Generate checksum
    $sha256 = New-Object -TypeName System.Security.Cryptography.SHA256Managed
    $fileStream = [System.IO.File]::OpenRead($zipPath)
    $hashBytes = $sha256.ComputeHash($fileStream)
    $fileStream.Close()
    $checksum = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
    "$checksum  $packageName" | Set-Content -Path "$zipPath.sha256" -Encoding UTF8
    
    Write-LogSuccess "Portable ZIP package created: $packageName"
    Write-LogInfo "Package location: $zipPath"
    Write-LogInfo "Checksum: $checksum"
    
    return $zipPath
}

function New-WindowsInstaller {
    Write-LogInfo "Creating Windows installer..."
    
    # Check for Inno Setup
    $innoPath = Test-InnoSetup
    if (-not $innoPath) {
        if ($InstallInnoSetup) {
            $innoPath = Install-InnoSetup
        } else {
            Write-LogWarning "Inno Setup not found. Use -InstallInnoSetup to install it automatically."
            Write-LogWarning "Skipping Windows installer creation."
            return $null
        }
    }
    
    # Verify installer script exists
    if (-not (Test-Path $InstallerScriptPath)) {
        Write-LogWarning "Installer script not found at: $InstallerScriptPath"
        Write-LogWarning "Skipping Windows installer creation."
        return $null
    }
    
    try {
        Write-LogInfo "Compiling installer with Inno Setup..."
        $installerArgs = @(
            "`"$InstallerScriptPath`"",
            "/DMyAppVersion=$Version",
            "/O`"$WindowsOutputDir`""
        )
        
        $process = Start-Process -FilePath $innoPath -ArgumentList $installerArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            throw "Inno Setup compilation failed with exit code: $($process.ExitCode)"
        }
        
        # Find the created installer
        $installerName = "Zoidbot-Windows-$Version-Setup.exe"
        $installerPath = Join-Path $WindowsOutputDir $installerName
        
        if (Test-Path $installerPath) {
            # Generate checksum
            $sha256 = New-Object -TypeName System.Security.Cryptography.SHA256Managed
            $fileStream = [System.IO.File]::OpenRead($installerPath)
            $hashBytes = $sha256.ComputeHash($fileStream)
            $fileStream.Close()
            $checksum = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
            "$checksum  $installerName" | Set-Content -Path "$installerPath.sha256" -Encoding UTF8
            
            Write-LogSuccess "Windows installer created: $installerName"
            Write-LogInfo "Installer location: $installerPath"
            Write-LogInfo "Checksum: $checksum"
            
            return $installerPath
        } else {
            throw "Installer file not found after compilation: $installerPath"
        }
    }
    catch {
        Write-LogError "Failed to create Windows installer: $($_.Exception.Message)"
        throw
    }
}

function Main {
    Write-LogInfo "Zoidbot Complete Release Assets Builder v$Version"
    Write-LogInfo "============================================================"
    
    if ($Help) {
        Show-Help
        return
    }
    
    try {
        # Create output directories
        New-DirectoryIfNotExists -Path $OutputDir
        New-DirectoryIfNotExists -Path $WindowsOutputDir
        
        # Build Flutter application if not skipped
        if (-not $SkipBuild) {
            Build-FlutterWindows
        }
        
        # Create portable ZIP package
        $zipPath = New-PortableZipPackage
        
        # Create Windows installer if not skipped
        $installerPath = $null
        if (-not $SkipInstaller) {
            $installerPath = New-WindowsInstaller
        }
        
        # Summary
        Write-LogSuccess "Release assets creation completed successfully!"
        Write-LogInfo ""
        Write-LogInfo "Created assets:"
        Write-LogInfo "  • Portable ZIP: $zipPath"
        if ($installerPath) {
            Write-LogInfo "  • Windows Installer: $installerPath"
        }
        Write-LogInfo ""
        Write-LogInfo "All assets are ready for GitHub release upload."
        
    } catch {
        Write-LogError "Script failed: $($_.Exception.Message)"
        exit 1
    }
}

# Execute main function
Main
