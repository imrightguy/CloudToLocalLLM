# Zoidbot PowerShell Build Scripts

This directory contains PowerShell scripts designed to work natively on Windows with limited WSL integration only for Linux application builds.

## Overview

The PowerShell scripts provide Windows-native functionality while leveraging WSL only for:

- **Linux application builds** (Debian packages, AppImage, etc.)

WSL is **NOT used** for:

- Windows development workflows
- Version management
- Local file operations
- Git operations
- **VPS deployment operations** (use PowerShell SSH instead)

## Scripts

### Core Scripts

- **`BuildEnvironmentUtilities.ps1`** - Common utilities for WSL detection, logging, dependency management, SSH key synchronization, and WSL Flutter integration
- **`version_manager.ps1`** - Version management across all project files
- **`build_unified_package.ps1`** - Build Flutter applications for Windows
- **`create_unified_aur_package.ps1`** - Create AUR packages (requires WSL with Ubuntu)
- **`Build-DebianPackage.ps1`** - Create Debian packages (requires WSL with Ubuntu/Debian or Docker)
- **`Test-Environment.ps1`** - Comprehensive environment validation and testing
- **`Test-WSLFlutter.ps1`** - Test WSL Flutter integration and installation
- **`Test-FlutterBuild.ps1`** - Test complete Flutter build workflow via WSL
- **`Check-Syntax.ps1`** - PowerShell syntax checking utility
- **`Fix-Whitespace.ps1`** - Fix whitespace and line ending issues
- **`Push-Dev.ps1`** - Development push utility
- **`launcher.ps1`** - Smart script launcher with auto-detection

**Note**: VPS deployment operations use SSH from Windows PowerShell to execute bash scripts on the remote Linux VPS. WSL is NOT required for deployment.

### Dependencies

#### Required for All Scripts

- **PowerShell 5.1+** (included with Windows 10/11)
- **Chocolatey Package Manager** (automatically installed if needed)

#### Automatically Managed Dependencies

- **Git for Windows** - Version control operations
- **Flutter SDK** - For building Flutter applications
- **OpenSSH Client** - For SSH operations and WSL integration
- **Visual Studio Build Tools** - For Flutter Windows builds
- **7-Zip** - For archive operations
- **Docker Desktop** - For containerized builds (optional)

#### Optional WSL Integration

- **WSL 2** - Windows Subsystem for Linux
- **Ubuntu WSL** - For AUR package creation (`create_unified_aur_package.ps1`)
- **Ubuntu/Debian WSL** - For Debian package creation (`build_deb.ps1`)

#### Alternative to WSL

- **Docker Desktop** - For containerized Debian package building

## Usage Examples

### Version Management

```powershell
# Show current version information
.\version_manager.ps1 info

# Increment patch version
.\version_manager.ps1 increment patch

# Set specific version
.\version_manager.ps1 set 3.1.0

# Get semantic version
.\version_manager.ps1 get-semantic
```

### Building Applications

```powershell
# Build unified Windows package
.\build_unified_package.ps1

# Build with automatic dependency installation
.\build_unified_package.ps1 -AutoInstall

# Build with clean and skip dependency checks
.\build_unified_package.ps1 -Clean -SkipDependencyCheck

# Build to custom output directory
.\build_unified_package.ps1 -OutputPath C:\MyBuilds
```

### Creating AUR Packages

```powershell
# Create AUR package (requires WSL Arch Linux)
.\create_unified_aur_package.ps1

# Use specific WSL distribution
.\create_unified_aur_package.ps1 -WSLDistro ArchLinux

# Skip Flutter build step
.\create_unified_aur_package.ps1 -SkipBuild
```

### Package Creation

```powershell
# Create comprehensive packages (AUR, AppImage, Flatpak, Windows, Portable ZIP)
.\Create-UnifiedPackages.ps1

# Create specific package types
.\Create-UnifiedPackages.ps1 -PackageTypes AUR,AppImage

# Note: Debian package support has been deprecated in favor of
# AUR, AppImage, Flatpak, and Snap packages
```

### VPS Deployment

**Note**: VPS deployment is handled by bash scripts via WSL, not PowerShell scripts.

```powershell
# From Windows PowerShell, deploy to VPS via SSH
ssh cloudllm@zoidbot.online "cd /opt/zoidbot && ./scripts/deploy/update_and_deploy.sh --force --verbose"
```

### Environment Testing

```powershell
# Test entire environment
.\Test-Environment.ps1

# Test with automatic dependency installation
.\Test-Environment.ps1 -AutoInstall

# Detailed testing with issue fixing
.\Test-Environment.ps1 -Detailed -FixIssues
```

### SSH Key Management

```powershell
# Synchronize SSH keys from WSL to Windows
Import-Module .\utils.ps1
Sync-SSHKeys

# Force synchronization from specific WSL distribution
Sync-SSHKeys -SourceDistro "Ubuntu-22.04" -Force

# Auto-sync without prompts
Sync-SSHKeys -AutoSync
```

### WSL Flutter Testing

```powershell
# Test WSL Flutter integration
.\Test-WSLFlutter.ps1

# Test complete Flutter build workflow
.\Test-FlutterBuild.ps1

# Test Flutter build with specific project root
.\Test-FlutterBuild.ps1 -ProjectRoot "C:\MyProject"
```

## WSL Setup

### Installing WSL

```powershell
# Enable WSL feature
wsl --install

# Install specific distributions
wsl --install -d Ubuntu-24.04
wsl --install -d Ubuntu-22.04
```

### Setting Up Ubuntu for Flutter and Package Building

```bash
# In WSL Ubuntu
sudo apt update
sudo apt install -y dpkg-dev fakeroot build-essential curl git unzip xz-utils zip libglu1-mesa

# Flutter will be automatically installed at /opt/flutter by the PowerShell scripts
# Or install manually:
# curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz
# sudo tar xf flutter.tar.xz -C /opt/
# echo 'export PATH=$PATH:/opt/flutter/bin' >> ~/.bashrc
```

## Features

### Automatic Dependency Management

- **Chocolatey Integration**: Automatic installation and management of packages
- **User Consent**: Clear prompts with installation details and requirements
- **Retry Logic**: Automatic retry for failed installations (up to 3 attempts)
- **Verification**: Post-installation verification of all dependencies
- **Progress Indicators**: Real-time installation progress and status updates

### SSH Key Synchronization

- **Multi-Source Detection**: Scans WSL distributions for SSH keys
- **Key Type Support**: RSA, ED25519, and ECDSA key pairs
- **Windows Integration**: Proper Windows file permissions using icacls
- **Backup Creation**: Timestamped backups before overwriting existing keys
- **SSH Config Management**: Automatic SSH config updates for VPS hosts

### Cross-Platform Compatibility

- **Native Windows**: Core functionality works without WSL
- **WSL Integration**: Seamless integration for Linux-specific tasks
- **Docker Support**: Alternative to WSL for containerized builds
- **Automatic Detection**: Scripts detect available tools and choose best method

### Enhanced Error Handling

- **Comprehensive Validation**: Prerequisites checked before execution
- **Clear Error Messages**: Detailed error reporting with suggestions
- **Graceful Fallbacks**: Alternative methods when preferred tools unavailable
- **Progress Indicators**: Colored output with status information
- **Environment Testing**: Comprehensive validation script for troubleshooting

### WSL Features

- **Automatic Distribution Detection**: Finds suitable WSL distributions
- **Path Conversion**: Seamless Windows ↔ WSL path conversion
- **Command Execution**: Execute Linux commands from PowerShell
- **Tool Availability Checking**: Verify required tools in WSL

## Troubleshooting

### Common Issues

#### WSL Not Available

```
Error: WSL is not available on this system
Solution: Install WSL using 'wsl --install'
```

#### No Suitable WSL Distribution

```
Error: No Arch Linux WSL distribution found
Solution: Install Arch Linux WSL or use alternative method
```

#### Docker Not Running

```
Error: Docker daemon is not running
Solution: Start Docker Desktop or check Docker service
```

#### SSH Connection Failed

```
Error: Failed to connect to VPS
Solution: Check SSH key authentication and VPS accessibility
```

### WSL Troubleshooting

#### Check WSL Status

```powershell
wsl --list --verbose
wsl --status
```

#### Start WSL Distribution

```powershell
wsl -d Ubuntu-22.04
```

#### Update WSL

```powershell
wsl --update
```

## Script Architecture

### Modular Design

- **`BuildEnvironmentUtilities.ps1`**: Shared utilities imported by all scripts
- **Consistent Interface**: Similar command-line options across scripts
- **Error Handling**: Standardized error reporting and logging
- **Configuration**: Centralized configuration management

### WSL Integration Pattern

1. **Detection**: Check if WSL is available
2. **Distribution Selection**: Find suitable Linux distribution
3. **Tool Verification**: Ensure required tools are installed
4. **Command Execution**: Execute Linux commands via WSL
5. **Path Conversion**: Handle Windows/Linux path differences

### Fallback Strategy

1. **Primary Method**: Use WSL for Linux-specific operations
2. **Secondary Method**: Use Docker for containerized operations
3. **Native Method**: Use Windows tools where possible
4. **Error Reporting**: Clear guidance when methods unavailable

## Development

### Adding New Scripts

1. Import `utils.ps1` for common functionality
2. Use standardized logging functions
3. Implement WSL detection and fallbacks
4. Add comprehensive error handling
5. Include help documentation

### Testing

- Test on Windows without WSL (basic functionality)
- Test with WSL Ubuntu (Debian packaging)
- Test with WSL Arch Linux (AUR packaging)
- Test with Docker Desktop (containerized builds)
- Verify cross-platform file operations

## Compatibility

### Windows Versions

- **Windows 10** (version 2004 and later for WSL 2)
- **Windows 11** (full WSL 2 support)
- **Windows Server 2019/2022** (with WSL feature enabled)

### PowerShell Versions

- **PowerShell 5.1** (Windows PowerShell)
- **PowerShell 7+** (PowerShell Core)

### WSL Distributions

- **Ubuntu 20.04/22.04/24.04**
- **Debian 11/12**
- **Arch Linux**
- **Other systemd-based distributions**

## Contributing

When contributing to the PowerShell scripts:

1. **Follow PowerShell Best Practices**: Use approved verbs, proper parameter validation
2. **Maintain WSL Compatibility**: Ensure scripts work with and without WSL
3. **Add Error Handling**: Comprehensive error checking and user-friendly messages
4. **Update Documentation**: Keep README and help text current
5. **Test Thoroughly**: Verify functionality across different environments
