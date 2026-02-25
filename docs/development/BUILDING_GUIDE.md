# CloudToLocalLLM Building Guide

This document provides comprehensive instructions for building CloudToLocalLLM client applications across different platforms.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Linux Building](#linux-building)
- [Windows Building](#windows-building)
- [macOS Building](#macos-building)
- [Web Building](#web-building)
- [Development Builds](#development-builds)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 🛠️ **Required Tools**

#### **Core Requirements**

- **Flutter SDK**: Version 3.8 or higher
- **Dart SDK**: Included with Flutter
- **Git**: For version control and dependency management
- **Platform-specific tools**: See platform sections below

#### **Development Tools**

- **VS Code** with Flutter extension (recommended)
- **Android Studio** with Flutter plugin (alternative)
- **IntelliJ IDEA** with Flutter plugin (alternative)

#### **System Requirements**

- **RAM**: Minimum 8GB, recommended 16GB
- **Storage**: At least 10GB free space for development
- **Network**: Stable internet connection for dependencies

### 🔧 **Flutter Setup Verification**

```bash
# Verify Flutter installation
flutter doctor

# Check for any missing dependencies
flutter doctor -v

# Ensure all platforms are properly configured
flutter config --list
```

---

## Linux Building

### 🐧 **Linux Prerequisites**

```bash
# Ubuntu/Debian dependencies
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# Additional dependencies for desktop apps
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

### 📦 **Building Methods**

#### **1. General Static Package (Recommended)**

```bash
# Use the unified build script
./scripts/build_unified_package.sh
```

**What it does**:

1. Builds the Flutter application in release mode
2. Copies necessary assets and libraries
3. Creates a distributable archive (`.tar.gz`)
4. Output placed in `dist/` directory

#### **2. AppImage (Universal Linux - Recommended)**

```bash
# Build AppImage
./scripts/packaging/build_appimage.sh
```

**Benefits**:

- Portable, no-installation-needed package
- Universal Linux compatibility
- Self-contained application bundle
- Runs on most Linux distributions

**Usage**:

```bash
# Make executable and run
chmod +x CloudToLocalLLM-*.AppImage
./CloudToLocalLLM-*.AppImage
```

**Note**: Debian (.deb) packages have been discontinued in favor of AppImage for better cross-distribution compatibility.

#### **3. Manual Flutter Build**

```bash
# Enable Linux desktop support
flutter config --enable-linux-desktop

# Build for Linux
flutter build linux --release

# Output will be in build/linux/x64/release/bundle/
```

### 🔧 **Linux Build Configuration**

#### **Desktop Integration**

The Linux builds include:

- Desktop entry files (`.desktop`)
- Application icons
- System tray integration
- File associations
- Automatic startup options

#### **Dependencies**

- GTK 3.0+
- System tray support
- Network access permissions
- File system access for configuration

---

## Windows Building

### 🪟 **Windows Prerequisites**

#### **Required Software**

- **Visual Studio 2022** with C++ development tools
- **Windows 10 SDK** (latest version)
- **Git for Windows**
- **Flutter SDK** properly configured

#### **Environment Setup**

```powershell
# Verify Windows development setup
flutter doctor

# Enable Windows desktop support
flutter config --enable-windows-desktop
```

### 🏗️ **Building Process**

#### **1. Release Build**

```powershell
# Build Windows release
flutter build windows --release

# Output will be in build\windows\runner\Release\
```

#### **2. Debug Build**

```powershell
# Build Windows debug version
flutter build windows --debug

# For development and testing
```

#### **3. Using Build Scripts**

```powershell
# Use PowerShell build automation
.\scripts\powershell\Build-WindowsRelease.ps1

# With custom configuration
.\scripts\powershell\Build-WindowsRelease.ps1 -Configuration Release -Platform x64
```

### 📦 **Windows Packaging**

#### **Installer Creation**

```powershell
# Create Windows installer (if script available)
.\scripts\packaging\build_windows_installer.ps1
```

#### **Portable Package**

```powershell
# Create portable ZIP package
.\scripts\packaging\build_windows_portable.ps1
```

### 🔧 **Windows Features**

#### **System Integration**

- System tray integration with native Windows APIs
- Windows service support
- Registry integration for settings
- Windows Defender compatibility
- Auto-start with Windows

#### **Dependencies**

- Visual C++ Redistributable (included in installer)
- Windows 10/11 compatibility
- .NET Framework (if required by dependencies)

---

## macOS Building

### 🍎 **macOS Prerequisites**

#### **Required Software**

- **Xcode** (latest version from App Store)
- **Xcode Command Line Tools**
- **CocoaPods** for dependency management

#### **Setup**

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods

# Enable macOS desktop support
flutter config --enable-macos-desktop
```

### 🏗️ **Building Process**

#### **1. Release Build**

```bash
# Build macOS release
flutter build macos --release

# Output will be in build/macos/Build/Products/Release/
```

#### **2. Development Build**

```bash
# Build for development
flutter build macos --debug
```

### 📦 **macOS Packaging**

#### **App Bundle**

```bash
# Create macOS app bundle
./scripts/packaging/build_macos_app.sh
```

#### **DMG Creation**

```bash
# Create DMG installer
./scripts/packaging/build_macos_dmg.sh
```

### 🔧 **macOS Features**

#### **System Integration**

- Native macOS menu bar integration
- Dock integration
- macOS notification system
- Keychain integration for secure storage
- Sandboxing compatibility

**Note**: macOS support is planned for future releases. Current scripts may be placeholders.

---

## Web Building

### 🌐 **Web Build Process**

#### **Development Build**

```bash
# Build for web development
flutter build web --debug

# Serve locally for testing
flutter run -d chrome
```

#### **Production Build**

```bash
# Build optimized web version
flutter build web --release

# Output will be in build/web/
```

#### **Custom Web Build**

```bash
# Build with custom base href
flutter build web --base-href /app/

# Build with specific renderer
flutter build web --web-renderer canvaskit
```

### 🚀 **Web Deployment**

#### **Static Hosting**

```bash
# Copy build output to web server
cp -r build/web/* /var/www/html/

# Or use deployment script
./scripts/deploy/deploy_web.sh
```

#### **Container Deployment**

```bash
# Build web container
docker build -f docker/Dockerfile.web -t CloudToLocalLLM-web .

# Run web container
docker run -p 80:80 CloudToLocalLLM-web
```

---

## Development Builds

### 🔧 **Development Configuration**

#### **Debug Builds**

```bash
# Build debug version for any platform
flutter build [platform] --debug

# Examples:
flutter build linux --debug
flutter build windows --debug
flutter build web --debug
```

#### **Profile Builds**

```bash
# Build profile version for performance testing
flutter build [platform] --profile
```

### 🧪 **Testing Builds**

#### **Integration Testing**

```bash
# Run integration tests
flutter test integration_test/

# Run specific test file
flutter test integration_test/app_test.dart
```

#### **Platform Testing**

```bash
# Test on specific platform
flutter test --platform [platform]

# Test with coverage
flutter test --coverage
```

---

## Troubleshooting

### 🐛 **Common Issues**

#### **Flutter Doctor Issues**

```bash
# Fix common Flutter issues
flutter doctor --android-licenses
flutter clean
flutter pub get
```

#### **Platform-Specific Issues**

**Linux**:

```bash
# Missing dependencies
sudo apt-get install -y libgtk-3-dev

# Permission issues
chmod +x scripts/build_unified_package.sh
```

**Windows**:

```powershell
# Visual Studio issues
# Ensure C++ development tools are installed
# Update Windows SDK to latest version
```

**Web**:

```bash
# CORS issues in development
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

### 📝 **Build Logs**

#### **Verbose Output**

```bash
# Get detailed build information
flutter build [platform] --verbose

# Debug build issues
flutter analyze
flutter doctor -v
```

#### **Log Files**

- Build logs: `build/logs/`
- Flutter logs: `~/.flutter/logs/`
- Platform-specific logs in respective build directories

---

## Related Documentation

- [Development Workflow](DEVELOPMENT_WORKFLOW.md)
- [Developer Onboarding](DEVELOPER_ONBOARDING.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Deployment Overview](../DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)
- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)

---

*For build issues or questions, please check our [troubleshooting guide](../USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md) or [open an issue](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues).*
