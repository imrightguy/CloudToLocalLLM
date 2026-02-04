# Zoidbot Windows Self-Hosted GitHub Actions Runner Setup
# This script sets up a Windows machine as a self-hosted GitHub Actions runner
# with all prerequisites needed to build the Windows app

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "https://github.com/Zoidbot-online/Zoidbot",
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerLabels = "windows,self-hosted",
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$FlutterVersion = "3.24.0",
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerVersion = "2.317.0",
    
    [switch]$SkipBuildTools,
    [switch]$SkipFlutter,
    [switch]$SkipRunnerConfig,
    [switch]$TestOnly
)

# Error handling
$ErrorActionPreference = "Stop"

# Logging functions
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Install Chocolatey if not present
function Install-Chocolatey {
    Write-LogInfo "Checking Chocolatey installation..."
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-LogSuccess "Chocolatey is already installed"
        $chocoVersion = choco --version
        Write-LogInfo "Chocolatey version: $chocoVersion"
        return $true
    }
    
    Write-LogInfo "Installing Chocolatey package manager..."
    
    if (-not (Test-Administrator)) {
        Write-LogError "Administrator privileges required to install Chocolatey"
        Write-LogInfo "Please run PowerShell as Administrator"
        return $false
    }
    
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $installScript
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-LogSuccess "Chocolatey installed successfully"
        return $true
    }
    catch {
        Write-LogError "Failed to install Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

# Set PowerShell execution policy
function Set-PowerShellExecutionPolicy {
    Write-LogInfo "Checking PowerShell execution policy..."
    
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -eq 'Restricted') {
        Write-LogInfo "Setting PowerShell execution policy to RemoteSigned for current user..."
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-LogSuccess "PowerShell execution policy set to RemoteSigned"
        }
        catch {
            Write-LogWarning "Failed to set execution policy: $($_.Exception.Message)"
            Write-LogInfo "You may need to run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    } else {
        Write-LogSuccess "PowerShell execution policy is already set to: $currentPolicy"
    }
    return $true
}

# Install Git
function Install-Git {
    Write-LogInfo "Checking Git installation..."
    
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitVersion = git --version
        Write-LogSuccess "Git is already installed: $gitVersion"
        return $true
    }
    
    Write-LogInfo "Installing Git for Windows..."
    
    try {
        choco install git -y
        refreshenv
        
        # Verify installation
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $gitVersion = git --version
            Write-LogSuccess "Git installed successfully: $gitVersion"
            return $true
        } else {
            Write-LogError "Git installation completed but not found in PATH"
            Write-LogInfo "Please restart PowerShell or run: refreshenv"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to install Git: $($_.Exception.Message)"
        return $false
    }
}

# Install Visual Studio Build Tools 2022
function Install-VisualStudioBuildTools {
    if ($SkipBuildTools) {
        Write-LogInfo "Skipping Visual Studio Build Tools installation"
        return $true
    }
    
    Write-LogInfo "Checking Visual Studio Build Tools installation..."
    
    # Check if Visual Studio 2022 is already installed
    $vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools"
    $vsCommunityPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"
    $vsEnterprisePath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise"
    
    if ((Test-Path $vsPath) -or (Test-Path $vsCommunityPath) -or (Test-Path $vsEnterprisePath)) {
        Write-LogSuccess "Visual Studio 2022 is already installed"
        return $true
    }
    
    Write-LogInfo "Installing Visual Studio Build Tools 2022 with C++ workload..."
    Write-LogWarning "This may take 15-30 minutes depending on your internet connection"
    
    try {
        # Download Visual Studio Build Tools installer
        $vsInstallerUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
        $vsInstallerPath = "$env:TEMP\vs_buildtools.exe"
        
        Write-LogInfo "Downloading Visual Studio Build Tools installer..."
        Invoke-WebRequest -Uri $vsInstallerUrl -OutFile $vsInstallerPath -UseBasicParsing
        
        # Install with C++ desktop development workload
        Write-LogInfo "Installing Visual Studio Build Tools (this may take a while)..."
        $installArgs = @(
            "--quiet",
            "--wait",
            "--nocache",
            "--norestart",
            "--add", "Microsoft.VisualStudio.Workload.VCTools",
            "--includeRecommended"
        )
        
        Start-Process -FilePath $vsInstallerPath -ArgumentList $installArgs -Wait -NoNewWindow
        
        Write-LogSuccess "Visual Studio Build Tools installed successfully"
        
        # Clean up installer
        Remove-Item $vsInstallerPath -Force -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        Write-LogError "Failed to install Visual Studio Build Tools: $($_.Exception.Message)"
        Write-LogInfo "You may need to install manually from: https://visualstudio.microsoft.com/downloads/"
        return $false
    }
}

# Install Flutter SDK
function Install-Flutter {
    if ($SkipFlutter) {
        Write-LogInfo "Skipping Flutter SDK installation"
        return $true
    }
    
    Write-LogInfo "Checking Flutter SDK installation..."
    
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        $flutterVersion = flutter --version
        Write-LogSuccess "Flutter is already installed"
        Write-LogInfo $flutterVersion
        return $true
    }
    
    Write-LogInfo "Installing Flutter SDK version $FlutterVersion..."
    
    try {
        # Install Flutter via Chocolatey
        choco install flutter --version=$FlutterVersion -y
        refreshenv
        
        # Verify installation
        if (Get-Command flutter -ErrorAction SilentlyContinue) {
            Write-LogSuccess "Flutter SDK installed successfully"
            
            # Enable Windows desktop support
            Write-LogInfo "Enabling Windows desktop support..."
            flutter config --enable-windows-desktop
            
            # Run flutter doctor to verify setup
            Write-LogInfo "Running Flutter doctor to verify setup..."
            flutter doctor
            
            return $true
        } else {
            Write-LogError "Flutter installation completed but not found in PATH"
            Write-LogInfo "Please restart PowerShell or run: refreshenv"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to install Flutter: $($_.Exception.Message)"
        return $false
    }
}

# Setup GitHub Actions Runner
function Setup-GitHubActionsRunner {
    if ($SkipRunnerConfig) {
        Write-LogInfo "Skipping GitHub Actions Runner configuration"
        return $true
    }
    
    Write-LogInfo "Setting up GitHub Actions Runner..."
    
    $runnerDir = "C:\actions-runner"
    
    # Check if runner is already configured
    if (Test-Path "$runnerDir\.runner") {
        Write-LogWarning "GitHub Actions Runner appears to be already configured"
        Write-LogInfo "If you want to reconfigure, remove the $runnerDir directory first"
        return $true
    }
    
    # Create runner directory
    if (-not (Test-Path $runnerDir)) {
        New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
    }
    
    Set-Location $runnerDir
    
    # Get runner token from user
    Write-LogInfo "You need a GitHub runner registration token"
    Write-LogInfo "Get it from: $GitHubRepo/settings/actions/runners/new"
    Write-Host ""
    $runnerToken = Read-Host "Enter your GitHub runner registration token (or press Enter to skip)"
    
    if ([string]::IsNullOrWhiteSpace($runnerToken)) {
        Write-LogWarning "Runner token not provided. Skipping runner configuration."
        Write-LogInfo "You can configure the runner manually later by running:"
        Write-LogInfo "  cd $runnerDir"
        Write-LogInfo "  .\config.cmd --url $GitHubRepo --token YOUR_TOKEN --labels $RunnerLabels --name $RunnerName"
        return $false
    }
    
    # Download runner
    Write-LogInfo "Downloading GitHub Actions Runner v$RunnerVersion..."
    $runnerZipUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/actions-runner-win-x64-$RunnerVersion.zip"
    $runnerZipPath = "$runnerDir\actions-runner-win-x64-$RunnerVersion.zip"
    
    try {
        Invoke-WebRequest -Uri $runnerZipUrl -OutFile $runnerZipPath -UseBasicParsing
        Write-LogSuccess "Runner downloaded successfully"
    }
    catch {
        Write-LogError "Failed to download runner: $($_.Exception.Message)"
        return $false
    }
    
    # Extract runner
    Write-LogInfo "Extracting runner..."
    try {
        Expand-Archive -Path $runnerZipPath -DestinationPath $runnerDir -Force
        Remove-Item $runnerZipPath -Force
        Write-LogSuccess "Runner extracted successfully"
    }
    catch {
        Write-LogError "Failed to extract runner: $($_.Exception.Message)"
        return $false
    }
    
    # Configure runner
    Write-LogInfo "Configuring runner..."
    try {
        $configArgs = @(
            "--url", $GitHubRepo,
            "--token", $runnerToken,
            "--labels", $RunnerLabels,
            "--name", $RunnerName,
            "--unattended"
        )
        
        & .\config.cmd $configArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Runner configured successfully"
        } else {
            Write-LogError "Runner configuration failed"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to configure runner: $($_.Exception.Message)"
        return $false
    }
    
    # Install runner as a service
    Write-LogInfo "Installing runner as a Windows service..."
    try {
        & .\svc.exe install
        
        Write-LogInfo "Starting runner service..."
        & .\svc.exe start
        
        Write-LogSuccess "GitHub Actions Runner service installed and started"
        Write-LogInfo "Runner should now appear in: $GitHubRepo/settings/actions/runners"
        return $true
    }
    catch {
        Write-LogError "Failed to install runner service: $($_.Exception.Message)"
        Write-LogInfo "You can manually install the service by running:"
        Write-LogInfo "  cd $runnerDir"
        Write-LogInfo "  .\svc.exe install"
        Write-LogInfo "  .\svc.exe start"
        return $false
    }
}

# Verify setup
function Test-Setup {
    Write-LogInfo "Verifying setup..."
    
    $allGood = $true
    
    # Check Git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-LogSuccess "✓ Git is installed"
    } else {
        Write-LogError "✗ Git is not installed"
        $allGood = $false
    }
    
    # Check Flutter
    if (-not $SkipFlutter) {
        if (Get-Command flutter -ErrorAction SilentlyContinue) {
            Write-LogSuccess "✓ Flutter is installed"
            $flutterVersion = (flutter --version | Select-String -Pattern '\d+\.\d+\.\d+' | Select-Object -First 1).Matches.Value
            Write-LogInfo "  Flutter version: $flutterVersion"
        } else {
            Write-LogError "✗ Flutter is not installed"
            $allGood = $false
        }
    }
    
    # Check Visual Studio Build Tools
    if (-not $SkipBuildTools) {
        $vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools"
        $vsCommunityPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"
        if ((Test-Path $vsPath) -or (Test-Path $vsCommunityPath)) {
            Write-LogSuccess "✓ Visual Studio 2022 is installed"
        } else {
            Write-LogWarning " Visual Studio 2022 may not be installed"
        }
    }
    
    # Check Runner
    if (-not $SkipRunnerConfig) {
        $runnerDir = "C:\actions-runner"
        if (Test-Path "$runnerDir\.runner") {
            Write-LogSuccess "✓ GitHub Actions Runner is configured"
        } else {
            Write-LogWarning " GitHub Actions Runner is not configured"
        }
    }
    
    return $allGood
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Windows Self-Hosted Runner Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($TestOnly) {
        Write-LogInfo "Running in test mode - only verifying existing setup"
        Test-Setup
        return
    }
    
    # Check for administrator privileges
    $isAdmin = Test-Administrator
    if (-not $isAdmin) {
        Write-LogWarning "Not running as Administrator. Some installations may require elevation."
        Write-LogInfo "For best results, run PowerShell as Administrator"
    }
    
    # Set execution policy
    Set-PowerShellExecutionPolicy | Out-Null
    
    # Install Chocolatey
    if (-not (Install-Chocolatey)) {
        Write-LogError "Chocolatey installation failed. Cannot continue."
        exit 1
    }
    
    # Install Git
    if (-not (Install-Git)) {
        Write-LogError "Git installation failed."
        exit 1
    }
    
    # Install Visual Studio Build Tools
    if (-not (Install-VisualStudioBuildTools)) {
        Write-LogWarning "Visual Studio Build Tools installation had issues."
        Write-LogInfo "You may need to install it manually for Windows builds to work"
    }
    
    # Install Flutter
    if (-not (Install-Flutter)) {
        Write-LogError "Flutter installation failed."
        exit 1
    }
    
    # Setup GitHub Actions Runner
    if (-not (Setup-GitHubActionsRunner)) {
        Write-LogWarning "GitHub Actions Runner setup had issues."
        Write-LogInfo "You can configure it manually later"
    }
    
    # Verify setup
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Setup Verification" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if (Test-Setup) {
        Write-Host ""
        Write-LogSuccess "Setup completed successfully!"
        Write-Host ""
        Write-LogInfo "Next steps:"
        Write-LogInfo "1. Verify the runner appears in GitHub: $GitHubRepo/settings/actions/runners"
        Write-LogInfo "2. Test a build by pushing a tag that triggers the workflow"
        Write-LogInfo "3. Monitor runner logs at: C:\actions-runner\_diag"
        Write-Host ""
    } else {
        Write-Host ""
        Write-LogWarning "Setup completed with some warnings. Please review the output above."
        Write-Host ""
    }
}

# Run main function
Main

