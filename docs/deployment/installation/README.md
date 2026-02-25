# CloudToLocalLLM Installation Guide

This directory contains platform-specific installation guides for CloudToLocalLLM.

## 📋 Quick Navigation

### 🖥️ **Platform-Specific Guides**

- **[Linux Installation](LINUX.md)** - Ubuntu, Debian, Arch, and other distributions
- **[Windows Installation](WINDOWS.md)** - Windows 10/11 desktop application
- **[macOS Installation](MACOS.md)** - Coming soon

### 🚀 **Quick Start**

- **** - What you need before installing
- **** - Getting started after installation
- **** - Common installation issues

---

## 🎯 Choose Your Platform

### 🐧 **Linux Users**

CloudToLocalLLM supports multiple Linux installation methods:

- **DEB Package** (Ubuntu/Debian) - Recommended for most users
- **AppImage** - Universal Linux package, works everywhere
- **Source Build** - For advanced users and developers

**[→ Linux Installation Guide](LINUX.md)**

### 🪟 **Windows Users**

Simple installer for Windows 10/11:

- **Windows Installer** - Easy setup with system tray integration
- **Portable Version** - No installation required
- **Development Build** - For testing latest features

**[→ Windows Installation Guide](WINDOWS.md)**

### 🍎 **macOS Users**

macOS support is coming soon!

- **Native App Bundle** - Planned
- **Homebrew Package** - Planned
- **Development Preview** - Available for testing

**[→ macOS Installation Guide](MACOS.md)**

---

## 📋 Prerequisites

Before installing CloudToLocalLLM, you'll need:

### 🧠 **Ollama (Required)**

CloudToLocalLLM requires Ollama to run local AI models:

1. **Install Ollama**: Visit [ollama.ai](https://ollama.ai/) and follow installation instructions
2. **Download a model**: `ollama pull llama3.2` (or your preferred model)
3. **Verify installation**: `ollama list` should show your downloaded models

### 💻 **System Requirements**

- **RAM**: Minimum 4GB, recommended 8GB+ (depends on AI model size)
- **Storage**: 2GB for application + space for AI models
- **Network**: Internet connection for initial setup and web access
- **OS**: See platform-specific requirements in individual guides

---

## 🚀 Installation Overview

### 1. **Install Prerequisites**

- Install Ollama and download AI models
- Ensure system meets requirements

### 2. **Install CloudToLocalLLM**

- Choose your platform-specific installation method
- Follow the detailed guide for your operating system

### 3. **First Time Setup**

- Launch CloudToLocalLLM (appears in system tray)
- Complete the setup wizard
- Connect to your local Ollama instance

### 4. **Access Web Interface**

- Visit [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)
- Sign in with your account
- Start chatting with your local AI models!

---

## 🔧 Installation Methods Comparison

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Package Manager** | Easy updates, system integration | Platform-specific | Regular users |
| **Installer** | Simple setup, guided process | Larger download | First-time users |
| **Portable** | No installation, easy to move | Manual updates | Testing, temporary use |
| **Source Build** | Latest features, customizable | Requires development tools | Developers, advanced users |

---

## 🆘 Need Help?

### 📚 **Documentation**

- **** - Common installation issues
- **[User Guide](../USER_DOCUMENTATION/USER_GUIDE.md)** - How to use CloudToLocalLLM
- **[FAQ](../USER_DOCUMENTATION/SETUP_TROUBLESHOOTING_FAQ.md)** - Frequently asked questions

### 💬 **Support**

- **[GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)** - Report bugs or ask questions
- **[Discussions](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/discussions)** - Community support
- **[User Troubleshooting](../USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)** - Self-help guide

---

## 🔄 Updating CloudToLocalLLM

### **Automatic Updates**

- Package manager installations receive automatic updates
- Check for updates in the application settings

### **Manual Updates**

- Download latest version from [releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases)
- Follow the same installation process
- Your settings and data will be preserved

---

## 🗑️ Uninstalling

### **Package Manager**

```bash
# Ubuntu/Debian
sudo apt remove CloudToLocalLLM

# Arch Linux (when available)
sudo pacman -R CloudToLocalLLM
```

### **Windows**

- Use "Add or Remove Programs" in Windows Settings
- Or run the uninstaller from the Start Menu

### **Portable Versions**

- Simply delete the application folder
- Optionally remove configuration files from user directory

---

*Choose your platform above to get started with CloudToLocalLLM!*
