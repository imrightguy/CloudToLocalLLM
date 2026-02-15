# Zoidbot Windows Development Environment Setup Script
# Comprehensive setup for Zoidbot development on Windows

[CmdletBinding()]
param(
    [switch]$SkipFlutter,
    [switch]$SkipNodeJS,
    [switch]$SkipGit,
    [switch]$SkipDocker,
    [switch]$SkipWSL,
    [switch]$SkipOllama,
    [switch]$AutoInstall,
    [switch]$TestOnly
)

# Import utilities if available
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    # Basic logging functions if utilities not available
    function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
    function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
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
        return $true
    }
    
    Write-LogInfo "Installing Chocolatey package manager..."
    
    if (-not (Test-Administrator)) {
        Write-LogError "Administrator privileges required to install Chocolatey"
        Write-LogInfo "Please run PowerShell as Administrator or install Chocolatey manually"
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
            Write-LogError "Failed to set execution policy: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-LogSuccess "PowerShell execution policy is already set to: $currentPolicy"
    }
    return $true
}

# Install package via Chocolatey
function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$DisplayName,
        [string]$VerifyCommand,
        [string[]]$AdditionalParams = @()
    )
    
    Write-LogInfo "Checking ${DisplayName} installation..."
    
    # Check if already installed
    if ($VerifyCommand -and (Get-Command $VerifyCommand.Split(' ')[0] -ErrorAction SilentlyContinue)) {
        Write-LogSuccess "${DisplayName} is already installed"
        return $true
    }
    
    Write-LogInfo "Installing ${DisplayName} via Chocolatey..."
    
    try {
        $params = @('install', $PackageName, '-y') + $AdditionalParams
        & choco @params
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "${DisplayName} installed successfully"
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        } else {
            Write-LogError "Failed to install ${DisplayName} (exit code: $LASTEXITCODE)"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to install ${DisplayName}: $($_.Exception.Message)"
        return $false
    }
}

# Install Flutter SDK
function Install-FlutterSDK {
    if ($SkipFlutter) {
        Write-LogInfo "Skipping Flutter installation as requested"
        return $true
    }
    
    Write-LogInfo "Setting up Flutter SDK..."
    
    # Install Flutter via Chocolatey
    if (-not (Install-ChocoPackage -PackageName "flutter" -DisplayName "Flutter SDK" -VerifyCommand "flutter")) {
        return $false
    }
    
    # Enable desktop development
    Write-LogInfo "Enabling Flutter desktop development..."
    try {
        & flutter config --enable-windows-desktop
        & flutter config --enable-linux-desktop
        & flutter config --enable-macos-desktop
        
        Write-LogInfo "Running flutter doctor to check setup..."
        & flutter doctor
        
        Write-LogSuccess "Flutter SDK setup completed"
        return $true
    }
    catch {
        Write-LogError "Failed to configure Flutter: $($_.Exception.Message)"
        return $false
    }
}

# Install Node.js and npm
function Install-NodeJS {
    if ($SkipNodeJS) {
        Write-LogInfo "Skipping Node.js installation as requested"
        return $true
    }
    
    Write-LogInfo "Setting up Node.js environment..."
    
    # Install Node.js via Chocolatey
    if (-not (Install-ChocoPackage -PackageName "nodejs" -DisplayName "Node.js" -VerifyCommand "node")) {
        return $false
    }
    
    # Verify npm is available
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-LogSuccess "npm is available"
        
        # Install project dependencies
        if (Test-Path "package.json") {
            Write-LogInfo "Installing npm dependencies..."
            try {
                & npm install
                if ($LASTEXITCODE -eq 0) {
                    Write-LogSuccess "npm dependencies installed"
                } else {
                    Write-LogWarning "npm install completed with warnings"
                }
            }
            catch {
                Write-LogError "Failed to install npm dependencies: $($_.Exception.Message)"
                return $false
            }
        }
        
        return $true
    } else {
        Write-LogError "npm not found after Node.js installation"
        return $false
    }
}

# Install Git for Windows
function Install-Git {
    if ($SkipGit) {
        Write-LogInfo "Skipping Git installation as requested"
        return $true
    }
    
    return (Install-ChocoPackage -PackageName "git" -DisplayName "Git for Windows" -VerifyCommand "git")
}

# Install Docker Desktop
function Install-DockerDesktop {
    if ($SkipDocker) {
        Write-LogInfo "Skipping Docker installation as requested"
        return $true
    }
    
    Write-LogInfo "Setting up Docker Desktop..."
    
    if (-not (Install-ChocoPackage -PackageName "docker-desktop" -DisplayName "Docker Desktop" -VerifyCommand "docker")) {
        Write-LogWarning "Docker Desktop installation failed or requires manual setup"
        Write-LogInfo "You may need to:"
        Write-LogInfo "1. Enable Hyper-V and Containers Windows features"
        Write-LogInfo "2. Restart your computer"
        Write-LogInfo "3. Start Docker Desktop manually"
        return $false
    }
    
    return $true
}

# Install WSL2
function Install-WSL2 {
    if ($SkipWSL) {
        Write-LogInfo "Skipping WSL2 installation as requested"
        return $true
    }
    
    Write-LogInfo "Checking WSL2 installation..."
    
    try {
        $wslVersion = & wsl --version 2>$null
        if ($wslVersion) {
            Write-LogSuccess "WSL2 is already installed"
            return $true
        }
    }
    catch {
        # WSL not installed
    }
    
    if (-not (Test-Administrator)) {
        Write-LogWarning "Administrator privileges required to install WSL2"
        Write-LogInfo "Please run as Administrator to install WSL2, or install manually"
        return $false
    }
    
    Write-LogInfo "Installing WSL2..."
    try {
        & wsl --install
        Write-LogSuccess "WSL2 installation initiated"
        Write-LogWarning "A restart may be required to complete WSL2 installation"
        return $true
    }
    catch {
        Write-LogError "Failed to install WSL2: $($_.Exception.Message)"
        return $false
    }
}

# Install Ollama
function Install-Ollama {
    if ($SkipOllama) {
        Write-LogInfo "Skipping Ollama installation as requested"
        return $true
    }
    
    Write-LogInfo "Setting up Ollama..."
    
    if (-not (Install-ChocoPackage -PackageName "ollama" -DisplayName "Ollama" -VerifyCommand "ollama")) {
        Write-LogWarning "Ollama installation via Chocolatey failed"
        Write-LogInfo "You can install Ollama manually from https://ollama.ai/"
        return $false
    }
    
    # Download a basic model
    Write-LogInfo "Downloading a basic Ollama model (llama3.2:1b)..."
    try {
        & ollama pull llama3.2:1b
        Write-LogSuccess "Basic Ollama model downloaded"
    }
    catch {
        Write-LogWarning "Failed to download Ollama model. You can download it later with: ollama pull llama3.2:1b"
    }
    
    return $true
}

# Install Playwright browsers
function Install-PlaywrightBrowsers {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-LogWarning "npm not available, skipping Playwright browser installation"
        return $false
    }
    
    Write-LogInfo "Installing Playwright browsers..."
    try {
        & npx playwright install
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Playwright browsers installed"
            return $true
        } else {
            Write-LogWarning "Playwright browser installation completed with warnings"
            return $true
        }
    }
    catch {
        Write-LogError "Failed to install Playwright browsers: $($_.Exception.Message)"
        return $false
    }
}

# Test development environment
function Test-DevelopmentEnvironment {
    Write-LogInfo "Testing development environment..."
    
    $tests = @(
        @{ Name = "PowerShell Execution Policy"; Command = { (Get-ExecutionPolicy -Scope CurrentUser) -ne 'Restricted' } },
        @{ Name = "Chocolatey"; Command = { Get-Command choco -ErrorAction SilentlyContinue } },
        @{ Name = "Git"; Command = { Get-Command git -ErrorAction SilentlyContinue } },
        @{ Name = "Flutter"; Command = { Get-Command flutter -ErrorAction SilentlyContinue } },
        @{ Name = "Node.js"; Command = { Get-Command node -ErrorAction SilentlyContinue } },
        @{ Name = "npm"; Command = { Get-Command npm -ErrorAction SilentlyContinue } },
        @{ Name = "Docker"; Command = { Get-Command docker -ErrorAction SilentlyContinue } },
        @{ Name = "Ollama"; Command = { Get-Command ollama -ErrorAction SilentlyContinue } }
    )
    
    $passed = 0
    $total = $tests.Count
    
    Write-Host "`n=== Development Environment Test Results ===" -ForegroundColor Cyan
    
    foreach ($test in $tests) {
        try {
            $result = & $test.Command
            if ($result) {
                Write-Host " $($test.Name)" -ForegroundColor Green
                $passed++
            } else {
                Write-Host " $($test.Name)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host " $($test.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nTest Results: $passed/$total passed" -ForegroundColor $(if ($passed -eq $total) { 'Green' } else { 'Yellow' })
    
    if ($passed -eq $total) {
        Write-LogSuccess "All development environment tests passed!"
        return $true
    } else {
        Write-LogWarning "Some development environment tests failed. Please review the results above."
        return $false
    }
}

# Test Flutter project setup
function Test-FlutterProject {
    Write-LogInfo "Testing Flutter project setup..."

    if (-not (Test-Path "pubspec.yaml")) {
        Write-LogError "pubspec.yaml not found. Are you in the Zoidbot project directory?"
        return $false
    }

    try {
        Write-LogInfo "Running flutter pub get..."
        & flutter pub get

        Write-LogInfo "Running flutter analyze..."
        & flutter analyze

        Write-LogInfo "Testing flutter doctor..."
        & flutter doctor

        Write-LogSuccess "Flutter project setup test completed"
        return $true
    }
    catch {
        Write-LogError "Flutter project test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test PowerShell scripts
function Test-PowerShellScripts {
    Write-LogInfo "Testing PowerShell version management scripts..."

    $versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionManagerPath) {
        try {
            Write-LogInfo "Testing version manager script..."
            & $versionManagerPath info -SkipDependencyCheck
            Write-LogSuccess "Version manager script test passed"
            return $true
        }
        catch {
            Write-LogError "Version manager script test failed: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-LogWarning "Version manager script not found at $versionManagerPath"
        return $false
    }
}

# Main execution
function Main {
    Write-Host " Zoidbot Windows Development Environment Setup" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host ""

    if ($TestOnly) {
        Write-LogInfo "Running tests only (no installation)..."
        $testResult = Test-DevelopmentEnvironment
        if (Test-Path "pubspec.yaml") {
            Test-FlutterProject
            Test-PowerShellScripts
        }
        return $testResult
    }

    $success = $true

    # Step 1: Set PowerShell execution policy
    Write-Host "Step 1: PowerShell Configuration" -ForegroundColor Yellow
    if (-not (Set-PowerShellExecutionPolicy)) {
        $success = $false
    }
    Write-Host ""

    # Step 2: Install Chocolatey
    Write-Host "Step 2: Package Manager Setup" -ForegroundColor Yellow
    if (-not (Install-Chocolatey)) {
        $success = $false
    }
    Write-Host ""

    # Step 3: Install Git
    Write-Host "Step 3: Version Control Setup" -ForegroundColor Yellow
    if (-not (Install-Git)) {
        $success = $false
    }
    Write-Host ""

    # Step 4: Install Flutter SDK
    Write-Host "Step 4: Flutter Development Environment" -ForegroundColor Yellow
    if (-not (Install-FlutterSDK)) {
        $success = $false
    }
    Write-Host ""

    # Step 5: Install Node.js
    Write-Host "Step 5: Node.js and npm Setup" -ForegroundColor Yellow
    if (-not (Install-NodeJS)) {
        $success = $false
    }
    Write-Host ""

    # Step 6: Install Playwright browsers
    Write-Host "Step 6: Testing Framework Setup" -ForegroundColor Yellow
    if (-not (Install-PlaywrightBrowsers)) {
        Write-LogWarning "Playwright browser installation failed, but continuing..."
    }
    Write-Host ""

    # Step 7: Install Docker Desktop
    Write-Host "Step 7: Container Development Setup" -ForegroundColor Yellow
    if (-not (Install-DockerDesktop)) {
        Write-LogWarning "Docker Desktop installation failed, but continuing..."
    }
    Write-Host ""

    # Step 8: Install WSL2
    Write-Host "Step 8: Windows Subsystem for Linux Setup" -ForegroundColor Yellow
    if (-not (Install-WSL2)) {
        Write-LogWarning "WSL2 installation failed, but continuing..."
    }
    Write-Host ""

    # Step 9: Install Ollama
    Write-Host "Step 9: Local AI Model Setup" -ForegroundColor Yellow
    if (-not (Install-Ollama)) {
        Write-LogWarning "Ollama installation failed, but continuing..."
    }
    Write-Host ""

    # Step 10: Test environment
    Write-Host "Step 10: Environment Validation" -ForegroundColor Yellow
    Test-DevelopmentEnvironment
    Write-Host ""

    # Step 11: Test Flutter project (if in project directory)
    if (Test-Path "pubspec.yaml") {
        Write-Host "Step 11: Flutter Project Validation" -ForegroundColor Yellow
        Test-FlutterProject
        Write-Host ""

        Write-Host "Step 12: PowerShell Scripts Validation" -ForegroundColor Yellow
        Test-PowerShellScripts
        Write-Host ""
    }

    # Final summary
    Write-Host "� Setup Complete!" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green

    if ($success) {
        Write-LogSuccess "Zoidbot development environment setup completed successfully!"
    } else {
        Write-LogWarning "Setup completed with some issues. Please review the output above."
    }

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Restart your PowerShell session to ensure all environment variables are loaded"
    Write-Host "2. If you installed WSL2, restart your computer to complete the installation"
    Write-Host "3. Configure Git with your user information:"
    Write-Host "   git config --global user.name 'Your Name'"
    Write-Host "   git config --global user.email 'your.email@example.com'"
    Write-Host "4. Set up SSH keys for GitHub access if needed"
    Write-Host "5. Run 'flutter doctor' to verify Flutter setup"
    Write-Host "6. Test the development workflow with:"
    Write-Host "   .\scripts\powershell\version_manager.ps1 info -SkipDependencyCheck"
    Write-Host ""

    return $success
}

# Execute main function
Main
