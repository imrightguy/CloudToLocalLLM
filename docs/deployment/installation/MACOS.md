# macOS Installation Guide

Zoidbot support for macOS is currently in development. This guide will be updated as macOS support becomes available.

## 📋 Current Status

### 🚧 **Development in Progress**

macOS support is planned for future releases. We're working on:

- **Native macOS app bundle** with proper code signing
- **Homebrew package** for easy installation
- **Mac App Store distribution** (under consideration)
- **System integration** with macOS menu bar and notifications

### 📅 **Timeline**

- **Development Preview**: Available for testing (see below)
- **Beta Release**: Planned for Q2 2025
- **Stable Release**: Planned for Q3 2025

---

## 🧪 Development Preview

### ⚠️ **For Developers and Early Adopters Only**

If you're a developer or want to help test macOS support, you can build from source:

#### **Prerequisites**

- **macOS**: 10.15 (Catalina) or later
- **Xcode**: Latest version from App Store
- **Xcode Command Line Tools**: `xcode-select --install`
- **Flutter SDK**: Download from [flutter.dev](https://flutter.dev/docs/get-started/install/macos)
- **CocoaPods**: `sudo gem install cocoapods`

#### **Build from Source**

```bash
# Install Flutter and enable macOS support
flutter config --enable-macos-desktop

# Clone repository
git clone https://github.com/Zoidbot-online/Zoidbot.git
cd Zoidbot

# Install dependencies
flutter pub get

# Build for macOS
flutter build macos --release

# Output will be in build/macos/Build/Products/Release/
```

#### **Known Limitations**

- ⚠️ **Experimental**: May be unstable or have missing features
- ⚠️ **No Installer**: Manual installation required
- ⚠️ **Limited Integration**: Basic macOS integration only
- ⚠️ **No Auto-Updates**: Manual updates required

---

## 📋 Prerequisites (When Available)

### 🧠 **Ollama Installation**

Zoidbot will require Ollama to be installed:

```bash
# Install Ollama for macOS
curl -fsSL https://ollama.ai/install.sh | sh

# Or use Homebrew (when available)
brew install ollama

# Download a model
ollama pull llama3.2

# Verify installation
ollama list
```

### 💻 **System Requirements**

- **macOS**: 10.15 (Catalina) or later
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 2GB for application + space for AI models
- **Network**: Internet connection for setup

---

## 🔮 Planned Features

### 🍎 **Native macOS Integration**

#### **Menu Bar Integration**

- Native macOS menu bar app
- Quick access to settings and status
- Connection indicators
- Context-aware menu options

#### **System Integration**

- **Dock integration** with badge notifications
- **macOS notification system** for status updates
- **Keychain integration** for secure credential storage
- **Spotlight search** integration
- **Quick Actions** in Finder

#### **App Bundle Features**

- **Code signing** for security and trust
- **Sandboxing** for enhanced security
- **Auto-updates** through built-in updater
- **Retina display** optimization

---

## 📦 Planned Installation Methods

### 🏠 **Homebrew (Planned)**

```bash
# Add Zoidbot tap
brew tap Zoidbot-online/Zoidbot

# Install Zoidbot
brew install zoidbot

# Start the service
brew services start zoidbot
```

### 📱 **App Bundle (Planned)**

1. Download `.dmg` file from releases
2. Open the disk image
3. Drag Zoidbot to Applications folder
4. Launch from Applications or Spotlight

### 🏪 **Mac App Store (Under Consideration)**

- Simplified installation and updates
- Automatic sandboxing and security
- Family sharing support
- In-app purchase options for premium features

---

## 🤝 Help Us Build macOS Support

### 👨‍💻 **For Developers**

We welcome contributions to macOS support:

- **Testing**: Try the development build and report issues
- **Development**: Help implement macOS-specific features
- **Documentation**: Improve macOS installation guides
- **Feedback**: Share your experience and suggestions

### 📝 **How to Contribute**

1. **Join the Discussion**: [GitHub Discussions](https://github.com/Zoidbot-online/Zoidbot/discussions)
2. **Report Issues**: [GitHub Issues](https://github.com/Zoidbot-online/Zoidbot/issues) with "macOS" label
3. **Submit PRs**: Follow our [Contributing Guide](../../CONTRIBUTING.md)
4. **Test Builds**: Help test development builds

### 🎯 **Priority Areas**

- **Menu bar integration** using native macOS APIs
- **Keychain integration** for secure storage
- **Notification system** integration
- **App bundle packaging** and code signing
- **Homebrew formula** creation

---

## 📢 Stay Updated

### 🔔 **Get Notified**

- **Watch** the [GitHub repository](https://github.com/Zoidbot-online/Zoidbot) for updates
- **Follow** releases for macOS availability announcements
- **Join** our [discussions](https://github.com/Zoidbot-online/Zoidbot/discussions) for development updates

### 📅 **Milestones**

Track macOS development progress:

- [macOS Support Milestone](https://github.com/Zoidbot-online/Zoidbot/milestone/1)
- [macOS Issues](https://github.com/Zoidbot-online/Zoidbot/labels/macOS)

---

## 🔄 Alternative Solutions

### 💻 **Current Options**

#### **Web Interface**

While waiting for native macOS support, you can:

1. Install Ollama on your Mac
2. Use Zoidbot on another device (Windows/Linux)
3. Access via [app.zoidbot.online](https://app.zoidbot.online)

#### **Virtual Machine**

- Run Linux in a VM (VirtualBox, Parallels, VMware)
- Install Zoidbot Linux version in the VM
- Access from macOS through the VM

#### **Docker (Advanced)**

```bash
# Run Zoidbot in Docker (when available)
docker run -d --name zoidbot \
  -p 8080:8080 \
  -v ~/.config/zoidbot:/config \
  zoidbot/app:latest
```

---

## 📚 Related Documentation

- [Installation Overview](README.md)
- [Linux Installation](LINUX.md)
- [Windows Installation](WINDOWS.md)
- [Development Guide](../DEVELOPMENT/BUILDING_GUIDE.md)
- [Contributing Guide](../../CONTRIBUTING.md)

---

## 📞 Contact

For questions about macOS support:

- **GitHub Issues**: [Report macOS-related issues](https://github.com/Zoidbot-online/Zoidbot/issues/new?labels=macOS)
- **Discussions**: [Join macOS development discussions](https://github.com/Zoidbot-online/Zoidbot/discussions)
- **Email**: Contact us through GitHub for specific macOS development questions

---

*We appreciate your patience as we work on bringing Zoidbot to macOS. Your feedback and contributions help us prioritize development efforts!*
