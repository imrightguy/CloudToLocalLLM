# Linux Installation Guide

This guide covers all methods for installing CloudToLocalLLM on Linux systems.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [DEB Package (Recommended)](#deb-package-recommended)
- [AppImage (Universal)](#appimage-universal)
- [Source Build](#source-build)
- [Post-Installation Setup](#post-installation-setup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 🧠 **Ollama Installation**

CloudToLocalLLM requires Ollama to be installed and running:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Download a model (example)
ollama pull llama3.2

# Verify installation
ollama list
```

### 💻 **System Requirements**

- **OS**: Ubuntu 18.04+, Debian 10+, or equivalent
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 2GB for application + space for AI models
- **Network**: Internet connection for setup

### 📦 **System Dependencies**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl wget git

# For desktop integration
sudo apt-get install -y libgtk-3-0 libglib2.0-0 libnss3 libatk-bridge2.0-0
```

---

## Installation Methods

### 🎯 **Choose Your Method**

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **DEB Package** | Ubuntu/Debian users | Easy installation, automatic updates | Debian-based only |
| **AppImage** | Any Linux distribution | Universal compatibility, portable | Manual updates |
| **Source Build** | Developers, advanced users | Latest features, customizable | Requires development tools |

---

## DEB Package (Recommended)

### 📦 **For Ubuntu/Debian Systems**

#### **Download and Install**

```bash
# Download latest DEB package
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm_amd64.deb

# Install the package
sudo dpkg -i cloudtolocalllm_amd64.deb

# Fix any dependency issues
sudo apt-get install -f
```

#### **Alternative: Direct Installation**

```bash
# Add repository (if available)
curl -fsSL https://cloudtolocalllm.online/install.sh | sudo bash

# Install via apt
sudo apt-get update
sudo apt-get install cloudtolocalllm
```

### ✅ **DEB Package Benefits**

- **Native package management integration**
- **Automatic dependency handling**
- **System service integration**
- **Desktop environment integration**
- **Easy updates via package manager**

### 🔄 **Updates**

```bash
# Update via package manager
sudo apt-get update
sudo apt-get upgrade cloudtolocalllm
```

### 🗑️ **Uninstallation**

```bash
# Remove package
sudo apt-get remove cloudtolocalllm

# Remove package and configuration
sudo apt-get purge cloudtolocalllm
```

---

## AppImage (Universal)

### 🌐 **For Any Linux Distribution**

#### **Download and Setup**

```bash
# Download latest AppImage
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-x86_64.AppImage

# Make executable
chmod +x CloudToLocalLLM-x86_64.AppImage

# Run the application
./CloudToLocalLLM-x86_64.AppImage
```

#### **Optional: Desktop Integration**

```bash
# Move to applications directory
sudo mv CloudToLocalLLM-x86_64.AppImage /opt/cloudtolocalllm/

# Create desktop entry
cat > ~/.local/share/applications/cloudtolocalllm.desktop << EOF
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Access your local AI models from anywhere
Exec=/opt/cloudtolocalllm/CloudToLocalLLM-x86_64.AppImage
Icon=cloudtolocalllm
Terminal=false
Type=Application
Categories=Development;Network;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications/
```

### ✅ **AppImage Benefits**

- **Universal Linux compatibility**
- **Portable, no-installation-needed package**
- **Self-contained application bundle**
- **Runs on most Linux distributions**
- **No root privileges required**

### 🔄 **Updates**

```bash
# Download new version and replace old file
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-x86_64.AppImage
chmod +x CloudToLocalLLM-x86_64.AppImage
```

---

## Source Build

### 👨‍💻 **For Developers and Advanced Users**

#### **Prerequisites**

```bash
# Install Flutter SDK
sudo snap install flutter --classic

# Or download manually from https://flutter.dev/docs/get-started/install/linux

# Install build dependencies
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

#### **Build Process**

```bash
# Clone repository
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM

# Install dependencies
flutter pub get

# Enable Linux desktop support
flutter config --enable-linux-desktop

# Build release version
flutter build linux --release

# Or use build script
./scripts/build_unified_package.sh
```

#### **Installation**

```bash
# Copy built application
sudo cp -r build/linux/x64/release/bundle /opt/cloudtolocalllm

# Create symlink for command line access
sudo ln -s /opt/cloudtolocalllm/cloudtolocalllm /usr/local/bin/cloudtolocalllm

# Create desktop entry (optional)
./scripts/create_desktop_entry.sh
```

### ✅ **Source Build Benefits**

- **Latest features and bug fixes**
- **Customizable build options**
- **Development environment ready**
- **Full control over dependencies**

---

## Post-Installation Setup

### 🚀 **First Launch**

1. **Launch CloudToLocalLLM**:

   ```bash
   # If installed via package manager
   cloudtolocalllm
   
   # If using AppImage
   ./CloudToLocalLLM-x86_64.AppImage
   
   # If built from source
   /opt/cloudtolocalllm/cloudtolocalllm
   ```

2. **System Tray**: The application will appear in your system tray

3. **Setup Wizard**: Follow the first-time setup wizard

### 🔧 **Configuration**

#### **Ollama Connection**

- CloudToLocalLLM automatically detects Ollama on `localhost:11434`
- Configure custom Ollama settings in the application preferences

#### **System Integration**

```bash
# Enable autostart (optional)
mkdir -p ~/.config/autostart
cp /usr/share/applications/cloudtolocalllm.desktop ~/.config/autostart/

# Configure system tray (if needed)
# Ensure your desktop environment supports system tray
```

### 🌐 **Web Access**

1. Visit [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)
2. Sign in with your account
3. Configure tunnel connection to your local instance

---

## Troubleshooting

### 🐛 **Common Issues**

#### **Application Won't Start**

```bash
# Check dependencies
ldd /opt/cloudtolocalllm/cloudtolocalllm

# Install missing libraries
sudo apt-get install -y libgtk-3-0 libglib2.0-0

# Check permissions
chmod +x /opt/cloudtolocalllm/cloudtolocalllm
```

#### **System Tray Not Visible**

```bash
# Install system tray support
sudo apt-get install -y gnome-shell-extension-appindicator

# For KDE
sudo apt-get install -y plasma-workspace

# Restart desktop environment or log out/in
```

#### **Ollama Connection Issues**

```bash
# Check Ollama status
systemctl status ollama

# Start Ollama if not running
ollama serve

# Check port availability
netstat -tlnp | grep 11434
```

#### **Permission Issues**

```bash
# Fix file permissions
sudo chown -R $USER:$USER ~/.config/cloudtolocalllm
chmod -R 755 ~/.config/cloudtolocalllm

# Fix executable permissions
chmod +x /opt/cloudtolocalllm/cloudtolocalllm
```

### 📝 **Log Files**

```bash
# Application logs
tail -f ~/.config/cloudtolocalllm/logs/app.log

# System logs
journalctl -u cloudtolocalllm -f

# Ollama logs
journalctl -u ollama -f
```

### 🔧 **Advanced Troubleshooting**

#### **Debug Mode**

```bash
# Run in debug mode
cloudtolocalllm --debug

# Or with verbose output
cloudtolocalllm --verbose
```

#### **Reset Configuration**

```bash
# Backup current config
cp -r ~/.config/cloudtolocalllm ~/.config/cloudtolocalllm.backup

# Reset to defaults
rm -rf ~/.config/cloudtolocalllm
```

---

## Distribution-Specific Notes

### 🟠 **Ubuntu**

- Tested on Ubuntu 20.04, 22.04, and 24.04
- Use DEB package for best integration

### 🔵 **Debian**

- Tested on Debian 11 and 12
- May need to enable non-free repositories for some dependencies

### 🟣 **Arch Linux**

- AUR package temporarily unavailable (reintegration planned)
- Use AppImage or source build
- See [AUR Status](../DEPLOYMENT/AUR_STATUS.md) for updates

### 🟢 **Fedora/CentOS/RHEL**

- Use AppImage for best compatibility
- RPM package planned for future releases

### 🟡 **Other Distributions**

- AppImage should work on most modern Linux distributions
- Source build available for maximum compatibility

---

## Related Documentation

- [Installation Overview](README.md)
- [Windows Installation](WINDOWS.md)
-
-
-
- [User Guide](../USER_DOCUMENTATION/USER_GUIDE.md)

---

*For additional help, see our  or [open an issue](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues).*
