# Windows Installation Guide

This guide covers installing CloudToLocalLLM on Windows 10 and Windows 11 systems.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Windows Installer (Recommended)](#windows-installer-recommended)
- [Portable Version](#portable-version)
- [Development Build](#development-build)
- [Post-Installation Setup](#post-installation-setup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 🧠 **Ollama Installation**

CloudToLocalLLM requires Ollama to be installed and running:

1. **Download Ollama**: Visit [ollama.ai](https://ollama.ai/) and download the Windows installer
2. **Install Ollama**: Run the installer and follow the setup wizard
3. **Download a model**: Open Command Prompt or PowerShell and run:

   ```powershell
   ollama pull llama3.2
   ```

4. **Verify installation**:

   ```powershell
   ollama list
   ```

### 💻 **System Requirements**

- **OS**: Windows 10 (version 1903 or later) or Windows 11
- **RAM**: 4GB minimum, 8GB+ recommended (depends on AI model size)
- **Storage**: 2GB for application + space for AI models
- **Network**: Internet connection for initial setup and web access
- **.NET Framework**: 4.7.2 or later (usually pre-installed)

### 🔧 **Optional Dependencies**

- **Visual C++ Redistributable**: Usually included with installer
- **Windows Defender**: Ensure CloudToLocalLLM is allowed through firewall

---

## Installation Methods

### 🎯 **Choose Your Method**

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Windows Installer** | Most users | Easy setup, system integration | Requires admin rights |
| **Portable Version** | Testing, temporary use | No installation, easy to move | Manual updates |
| **Development Build** | Developers, early adopters | Latest features | May be unstable |

---

## Windows Installer (Recommended)

### 📦 **Easy Installation with System Integration**

#### **Download and Install**

1. **Download**: Visit [GitHub Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)
2. **Choose**: Download `CloudToLocalLLM-Windows-Setup.exe`
3. **Run**: Double-click the installer
4. **Follow**: Complete the installation wizard

#### **Installation Steps**

1. **Welcome Screen**: Click "Next" to begin
2. **License Agreement**: Accept the MIT license terms
3. **Installation Location**: Choose install directory (default: `C:\Program Files\CloudToLocalLLM`)
4. **Start Menu**: Choose Start Menu folder name
5. **Additional Tasks**:
   - ✅ Create desktop shortcut
   - ✅ Start with Windows (recommended)
   - ✅ Add to system PATH
6. **Install**: Click "Install" and wait for completion
7. **Finish**: Launch CloudToLocalLLM immediately

### ✅ **Installer Benefits**

- **System tray integration** with native Windows APIs
- **Windows service support** for background operation
- **Registry integration** for settings storage
- **Automatic updates** through built-in updater
- **Uninstaller** for clean removal
- **Start Menu integration** and desktop shortcuts

### 🔄 **Updates**

- **Automatic**: CloudToLocalLLM checks for updates automatically
- **Manual**: Help → Check for Updates in the application menu
- **Download**: Latest version from [releases page](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases)

### 🗑️ **Uninstallation**

```
Settings → Apps → CloudToLocalLLM → Uninstall
```

Or use "Add or Remove Programs" in Control Panel.

---

## Portable Version

### 🎒 **No Installation Required**

#### **Download and Setup**

1. **Download**: Get `CloudToLocalLLM-Windows-Portable.zip` from [releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)
2. **Extract**: Unzip to your preferred location (e.g., `C:\Tools\CloudToLocalLLM`)
3. **Run**: Double-click `CloudToLocalLLM.exe`

#### **Portable Setup**

```
CloudToLocalLLM-Portable/
├── CloudToLocalLLM.exe          # Main application
├── data/                        # Application data
├── lib/                         # Required libraries
├── README.txt                   # Quick start guide
└── LICENSE                      # License file
```

### ✅ **Portable Benefits**

- **No installation required** - runs from any location
- **Portable settings** - configuration stored in application folder
- **Easy to move** - copy folder to USB drive or another computer
- **No registry changes** - leaves system clean
- **Multiple versions** - run different versions side by side

### 🔄 **Updates**

- Download new portable version
- Copy your `data` folder to preserve settings
- Replace old version with new one

---

## Development Build

### 👨‍💻 **For Developers and Early Adopters**

#### **Prerequisites**

- **Flutter SDK**: Download from [flutter.dev](https://flutter.dev/docs/get-started/install/windows)
- **Visual Studio 2022**: With C++ development tools
- **Git**: For cloning the repository

#### **Build from Source**

```powershell
# Clone repository
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM

# Install dependencies
flutter pub get

# Enable Windows desktop support
flutter config --enable-windows-desktop

# Build release version
flutter build windows --release

# Output will be in build\windows\runner\Release\
```

#### **Using Build Scripts**

```powershell
# Use PowerShell build automation
.\scripts\powershell\Build-WindowsRelease.ps1

# Create portable package
.\scripts\packaging\build_windows_portable.ps1
```

### ✅ **Development Build Benefits**

- **Latest features** and bug fixes
- **Development environment** ready for contributions
- **Custom build options** and configurations
- **Direct access** to source code

---

## Post-Installation Setup

### 🚀 **First Launch**

1. **Launch CloudToLocalLLM**:
   - From Start Menu: Search "CloudToLocalLLM"
   - From Desktop: Double-click desktop shortcut
   - From System Tray: Look for CloudToLocalLLM icon

2. **System Tray**: The application appears in the Windows system tray (bottom-right corner)

3. **Setup Wizard**: Follow the first-time setup wizard

### 🔧 **Configuration**

#### **Ollama Connection**

- CloudToLocalLLM automatically detects Ollama on `localhost:11434`
- Right-click system tray icon → Settings to configure custom Ollama settings

#### **Windows Integration**

- **Auto-start**: Enabled by default, can be disabled in Settings
- **System Tray**: Always visible when running
- **Notifications**: Windows 10/11 native notifications
- **Firewall**: Allow CloudToLocalLLM through Windows Defender Firewall

#### **Windows Defender Configuration**

```powershell
# Allow CloudToLocalLLM through firewall (run as Administrator)
New-NetFirewallRule -DisplayName "CloudToLocalLLM" -Direction Inbound -Program "C:\Program Files\CloudToLocalLLM\CloudToLocalLLM.exe" -Action Allow
```

### 🌐 **Web Access**

1. Visit [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)
2. Sign in with your account
3. Configure tunnel connection to your local instance

---

## Troubleshooting

### 🐛 **Common Issues**

#### **Application Won't Start**

```powershell
# Check if Ollama is running
Get-Process ollama

# Start Ollama if not running
ollama serve

# Check Windows Event Viewer for errors
eventvwr.msc
```

#### **System Tray Icon Missing**

1. **Check Hidden Icons**: Click the up arrow (^) in system tray
2. **Customize Notifications**:
   - Settings → System → Notifications & actions
   - Select which icons appear on taskbar
3. **Restart Application**: Exit and restart CloudToLocalLLM

#### **Firewall/Antivirus Issues**

```powershell
# Add Windows Defender exclusion
Add-MpPreference -ExclusionPath "C:\Program Files\CloudToLocalLLM"

# Check if blocked by antivirus
Get-MpThreatDetection | Where-Object {$_.Resources -like "*CloudToLocalLLM*"}
```

#### **Ollama Connection Issues**

```powershell
# Check Ollama status
ollama list

# Test Ollama connection
curl http://localhost:11434/api/version

# Restart Ollama service
Stop-Service ollama
Start-Service ollama
```

#### **Permission Issues**

```powershell
# Run as Administrator (if needed)
# Right-click CloudToLocalLLM → "Run as administrator"

# Check file permissions
icacls "C:\Program Files\CloudToLocalLLM"
```

### 📝 **Log Files**

```powershell
# Application logs
Get-Content "$env:APPDATA\CloudToLocalLLM\logs\app.log" -Tail 50

# Windows Event Logs
Get-WinEvent -LogName Application | Where-Object {$_.ProviderName -eq "CloudToLocalLLM"}

# Ollama logs
Get-Content "$env:LOCALAPPDATA\Ollama\logs\server.log" -Tail 50
```

### 🔧 **Advanced Troubleshooting**

#### **Debug Mode**

```powershell
# Run in debug mode
& "C:\Program Files\CloudToLocalLLM\CloudToLocalLLM.exe" --debug

# Or with verbose output
& "C:\Program Files\CloudToLocalLLM\CloudToLocalLLM.exe" --verbose
```

#### **Reset Configuration**

```powershell
# Backup current config
Copy-Item "$env:APPDATA\CloudToLocalLLM" "$env:APPDATA\CloudToLocalLLM.backup" -Recurse

# Reset to defaults
Remove-Item "$env:APPDATA\CloudToLocalLLM" -Recurse -Force
```

#### **Clean Reinstall**

```powershell
# Uninstall via Control Panel
# Then remove remaining files
Remove-Item "$env:APPDATA\CloudToLocalLLM" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\CloudToLocalLLM" -Recurse -Force

# Reinstall from latest installer
```

---

## Windows-Specific Features

### 🪟 **Native Windows Integration**

#### **System Tray**

- **Right-click menu** with quick actions
- **Connection status** indicators
- **Quick settings** access
- **Exit option** for clean shutdown

#### **Windows Services**

- **Background operation** when main window is closed
- **Auto-start with Windows** (optional)
- **Service management** through Windows Services console

#### **Registry Integration**

- **Settings storage** in Windows Registry
- **File associations** for CloudToLocalLLM files
- **URL protocol handlers** for web integration

#### **Windows Notifications**

- **Native Windows 10/11 notifications**
- **Connection status updates**
- **Error notifications** with action buttons

---

## Related Documentation

- [Installation Overview](README.md)
- [Linux Installation](LINUX.md)
-
-
-
- [User Guide](../USER_DOCUMENTATION/USER_GUIDE.md)

---

*For additional help, see our  or [open an issue](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues).*
