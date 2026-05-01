# CloudToLocalLLM Windows Development Environment Setup

## 🚀 Quick Start

For a fresh Windows installation, run this automated setup script:

```powershell
# Navigate to the CloudToLocalLLM project directory
cd C:\path\to\CloudToLocalLLM

# Run the automated setup script
.\scripts\powershell\Setup-WindowsDevelopmentEnvironment.ps1

# Or run with specific options
.\scripts\powershell\Setup-WindowsDevelopmentEnvironment.ps1 -AutoInstall
```

## 📋 Prerequisites

- **Windows 10/11** (64-bit)
- **Administrator privileges** (for some installations)
- **Internet connection** (for downloading tools and dependencies)
- **Visual Studio components** (currently installing - good!)
- **Chocolatey** (already installed - excellent!)

## 🛠️ Development Tools Overview

### Core Requirements

1. **PowerShell 5.1+** ✅ (Built into Windows 10/11)
2. **Chocolatey Package Manager** ✅ (Already installed)
3. **Git for Windows** - Version control
4. **Flutter SDK** - Cross-platform development framework
5. **Node.js & npm** - For e2e testing with Playwright
6. **Visual Studio Build Tools** - For Windows Flutter builds

### Optional but Recommended

1. **Docker Desktop** - For containerized development
2. **WSL2** - Windows Subsystem for Linux (for cross-platform builds)
3. **Ollama or LM Studio** - Optional support model provider for memory/background feature testing

## 🔧 Manual Installation Steps

If you prefer manual installation or the automated script fails:

### 1. PowerShell Configuration

```powershell
# Set execution policy to allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify current policy
Get-ExecutionPolicy -Scope CurrentUser
```

### 2. Install Development Tools via Chocolatey

```powershell
# Install Git for Windows
choco install git -y

# Install Flutter SDK
choco install flutter -y

# Install Node.js (LTS version)
choco install nodejs -y

# Install Docker Desktop (optional)
choco install docker-desktop -y

# Install Ollama for support model features (optional)
choco install ollama -y

# Refresh environment variables
refreshenv
```

### 3. Configure Flutter

```powershell
# Enable desktop development
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop

# Verify Flutter installation
flutter doctor

# Install project dependencies
flutter pub get
```

### 4. Setup Node.js Environment

```powershell
# Install project npm dependencies
npm install

# Install Playwright browsers for testing
npx playwright install

# Verify Node.js setup
node --version
npm --version
```

### 5. Configure Git (Replace with your information)

```powershell
# Set your Git user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify Git configuration
git config --list
```

## 🧪 Testing Your Setup

### Automated Environment Test

```powershell
# Test all development tools
.\scripts\powershell\Setup-WindowsDevelopmentEnvironment.ps1 -TestOnly
```

### Manual Verification

```powershell
# Test Flutter
flutter doctor
flutter --version

# Test Node.js and npm
node --version
npm --version

# Test Git
git --version

# Test PowerShell scripts
.\scripts\powershell\version_manager.ps1 info -SkipDependencyCheck

# Test Flutter project
flutter analyze
flutter test
```

### Test Flutter Build

```powershell
# Test Windows build
flutter build windows --debug

# Test web build
flutter build web
```

## 🔍 Troubleshooting

### Common Issues

#### PowerShell Execution Policy Restricted

```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Flutter Doctor Issues

```powershell
# Check Flutter doctor output
flutter doctor -v

# Common fixes:
# - Install Visual Studio Build Tools (already installing)
# - Enable Windows desktop development
flutter config --enable-windows-desktop
```

#### Chocolatey Installation Fails

```powershell
# Run PowerShell as Administrator and try:
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

#### npm/Node.js Issues

```powershell
# Clear npm cache
npm cache clean --force

# Reinstall Node.js
choco uninstall nodejs -y
choco install nodejs -y
refreshenv
```

#### Playwright Browser Installation Fails

```powershell
# Install browsers manually
npx playwright install chromium
npx playwright install firefox
npx playwright install webkit
```

### Environment Variables

After installation, ensure these are in your PATH:

- `C:\tools\flutter\bin`
- `C:\Program Files\nodejs`
- `C:\Program Files\Git\bin`
- `C:\ProgramData\chocolatey\bin`

## 📚 Development Workflow

### Daily Development Commands

```powershell
# Get latest changes
git pull origin master

# Update Flutter dependencies
flutter pub get

# Run code analysis
flutter analyze

# Run tests
flutter test

# Build for testing
flutter build windows --debug
```

### Version Management

```powershell
# Check current version
.\scripts\powershell\version_manager.ps1 info -SkipDependencyCheck

# Increment version (after deployment)
.\scripts\powershell\version_manager.ps1 increment patch -SkipDependencyCheck

# Set specific version
.\scripts\powershell\version_manager.ps1 set 4.1.0 -SkipDependencyCheck
```

### Testing Framework

```powershell
# Run e2e tests
npm test

# Run specific test suites
npm run test:auth
npm run test:tunnel

# Run tests in headed mode (visible browser)
npm run test:headed
```

## 🎯 Next Steps

After setup completion:

1. **Configure SSH Keys** for GitHub access
2. **Test the complete workflow** with a small change
3. **Familiarize yourself** with the project structure
4. **Review documentation** in `docs/DEVELOPMENT/`
5. **Join the development workflow** described in `docs/DEVELOPMENT_WORKFLOW.md`

## 📖 Additional Resources

- **[Developer Onboarding Guide](DEVELOPER_ONBOARDING.md)** - Comprehensive development guide
- **[Building Guide](BUILDING_GUIDE.md)** - Platform-specific build instructions
- **[PowerShell Scripts README](scripts/powershell/README.md)** - PowerShell utilities documentation
- **[Development Workflow](DEVELOPMENT_WORKFLOW.md)** - Daily development practices

---

**Need Help?** Check the troubleshooting section above or refer to the project documentation in the `docs/` directory.
