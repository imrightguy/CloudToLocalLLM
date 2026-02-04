# Zoidbot Developer Onboarding Guide

## 🚀 Welcome to Zoidbot Development

This guide will help you get started contributing to Zoidbot v3.4.0+. The project uses a unified Flutter-native architecture with integrated system tray functionality.

**What You'll Learn:**

- 🏗️ Project architecture and structure
- 🛠️ Development environment setup
- 🔧 Build and testing procedures
- 📝 Contribution workflow
- 🐛 Debugging and troubleshooting

---

## 📋 **Prerequisites**

### **Required Tools**

- **Flutter SDK**: 3.8.0 or later
- **Dart SDK**: Included with Flutter
- **Git**: Version control
- **IDE**: VS Code (recommended) or Android Studio
- **Node.js**: 24 LTS recommended (>=18 supported) (for API backend development)
- **Docker**: For container development and testing

### **Platform-Specific Requirements**

#### **Linux Development**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install flutter git build-essential curl

# Arch Linux
sudo pacman -S flutter git base-devel curl

# Enable Linux desktop development
flutter config --enable-linux-desktop
```

#### **Windows Development**

```powershell
# Install Flutter via chocolatey
choco install flutter

# Or download from flutter.dev
# Enable Windows desktop development
flutter config --enable-windows-desktop
```

#### **macOS Development**

```bash
# Install Flutter via homebrew
brew install flutter

# Enable macOS desktop development
flutter config --enable-macos-desktop
```

---

## 🏗️ **Project Architecture Overview**

### **Unified Flutter-Native Architecture**

Zoidbot v3.4.0+ uses a single Flutter application with:

- **Integrated System Tray**: Native tray functionality using `tray_manager`
- **Cross-Platform Support**: Linux, Windows, macOS, and Web
- **Service-Based Architecture**: Modular services for different functionality
- **Zero External Dependencies**: No separate daemon processes

### **Key Directories**

```
Zoidbot/
├── lib/                    # Main Flutter application
│   ├── components/         # Reusable UI components
│   ├── config/            # App configuration and routing
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # Core services
│   ├── shared/            # Shared utilities
│   └── widgets/           # Custom widgets
├── services/              # Backend services
│   ├── api-backend/       # Node.js API backend
│   └── streaming-proxy/   # Ephemeral proxy containers
├── config/                # Unified configuration
│   ├── augment/           # AI assistant rules
│   ├── docker/            # Docker configurations
│   └── nginx/             # Web server configurations
├── build-tools/           # Build infrastructure
│   ├── installers/        # Platform installers
│   └── packaging/         # Package configurations
├── web/                   # Flutter web configuration
├── assets/                # Static assets
├── docs/                  # Documentation
├── scripts/               # Build and deployment scripts
└── archive/               # Archived files and logs
```

### **Core Services**

- **NativeTrayService**: System tray integration
- **TunnelManagerService**: Connection management
- **UnifiedConnectionService**: Platform-specific connections
- **AuthService**: Authentication handling (with Auth0 web bridge for Flutter web)
- **StreamingChatService**: Chat functionality with real-time streaming

### **Web Platform Integration**

- **Auth0 Bridge** (`web/auth0-bridge.js`): JavaScript bridge for seamless Auth0 authentication in Flutter web
- **Unified Web Architecture**: Single Flutter codebase handles both marketing and application routes
- **Platform Detection**: Automatic routing based on web vs desktop platform

---

## 🛠️ **Development Environment Setup**

### **1. Clone the Repository**

```bash
git clone https://github.com/Zoidbot-online/Zoidbot.git
cd Zoidbot
```

### **2. Flutter Setup**

```bash
# Verify Flutter installation
flutter doctor

# Get dependencies
flutter pub get

# Enable desktop development (if not already done)
flutter config --enable-linux-desktop
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
```

### **3. IDE Configuration**

#### **VS Code (Recommended)**

Install these extensions:

- **Flutter**: Official Flutter extension
- **Dart**: Dart language support
- **Flutter Widget Snippets**: Helpful code snippets
- **Bracket Pair Colorizer**: Better bracket visualization

#### **Kiro IDE (Enhanced Development)**

Zoidbot includes specialized Kiro IDE configuration with:

- **Custom AI Assistant Modes**: Task-specific AI assistance for documentation, code review, testing, and refactoring
- **MCP Tool Integration**: Browser automation, documentation lookup, and workflow automation
- **Development Hooks**: Automated linting, commit management, and documentation sync

See the [Kiro IDE Configuration Guide](KIRO_IDE_CONFIGURATION.md) for setup instructions.

#### **Launch Configuration**

The project includes `.vscode/launch.json` with pre-configured debug settings:

- **Debug (Desktop)**: Run on desktop platform
- **Debug (Web)**: Run in web browser
- **Debug (Verbose)**: Run with detailed logging

### **4. API Backend Setup** (Optional)

```bash
cd api-backend
npm install
npm run dev
```

**Testing the API Backend:**

```bash
# Run backend tests with ES module support
npm test

# Run tests with coverage
npm test -- --coverage

# Run specific test files
npm test -- tests/tunnel-message-protocol.test.js
```

**Note**: The API backend uses ES modules (`"type": "module"`) and Jest is configured with ESM support for proper testing of modern JavaScript modules.

---

## 🔧 **Building and Testing**

### **Development Builds**

```bash
# Run in debug mode (hot reload enabled)
flutter run -d linux

# Run with verbose logging
flutter run -d linux --verbose

# Run web version
flutter run -d chrome

# Run with specific device
flutter devices
flutter run -d <device-id>
```

### **Release Builds**

```bash
# Build for Linux
flutter build linux --release

# Build for Windows
flutter build windows --release

# Build for Web
flutter build web --release

# Build with specific target
flutter build linux --target-platform linux-x64
```

### **Testing**

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/native_tray_service_test.dart

# Run tests with coverage
flutter test --coverage

# Integration tests
flutter test integration_test/
```

### **Code Quality**

```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Check for unused dependencies
flutter pub deps
```

---

## 📝 **Development Workflow**

### **1. Feature Development**

1. **Create Feature Branch**: `git checkout -b feature/your-feature-name`
2. **Implement Changes**: Follow coding standards and architecture patterns
3. **Write Tests**: Add unit and integration tests
4. **Test Thoroughly**: Test on target platforms
5. **Update Documentation**: Update relevant docs

### **2. Code Standards**

#### **Flutter/Dart Standards**

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter_lints` package rules (already configured)
- Prefer composition over inheritance
- Use meaningful variable and function names
- Add documentation comments for public APIs

#### **File Organization**

```dart
// File header with description
/// Service for managing native system tray functionality
/// 
/// Provides cross-platform system tray integration using the tray_manager
/// package with real-time connection status updates.

// Imports (grouped and sorted)
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../models/connection_status.dart';
import '../services/tunnel_manager_service.dart';

// Class definition with documentation
/// Native Flutter system tray service for Zoidbot v3.4.0+
class NativeTrayService with TrayListener {
  // Implementation
}
```

### **3. Testing Guidelines**

#### **Unit Tests**

```dart
// test/services/native_tray_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zoidbot/services/native_tray_service.dart';

void main() {
  group('NativeTrayService', () {
    test('should initialize successfully', () async {
      final service = NativeTrayService();
      expect(service.isInitialized, false);
      
      // Test initialization logic
    });
  });
}
```

#### **Widget Tests**

```dart
// test/widgets/chat_message_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoidbot/widgets/chat_message.dart';

void main() {
  testWidgets('ChatMessage displays content correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatMessage(
          content: 'Test message',
          isUser: true,
        ),
      ),
    );
    
    expect(find.text('Test message'), findsOneWidget);
  });
}
```

---

## 🐛 **Debugging and Troubleshooting**

### **Common Development Issues**

#### **System Tray Not Working**

```bash
# Check platform support
flutter run -d linux --verbose

# Verify tray_manager dependency
flutter pub deps | grep tray_manager

# Test with debug output
# Add debug prints in NativeTrayService
```

#### **Build Failures**

```bash
# Clean build cache
flutter clean
flutter pub get

# Check for dependency conflicts
flutter pub deps

# Verify platform configuration
flutter config
```

#### **Hot Reload Issues**

```bash
# Restart with clean state
flutter run --hot

# Force full restart
# Press 'R' in terminal or use IDE restart
```

### **Debugging Tools**

#### **Flutter Inspector**

- **VS Code**: View → Command Palette → "Flutter: Open Widget Inspector"
- **Chrome DevTools**: Available when running web version
- **Widget Tree**: Inspect widget hierarchy and properties

#### **Logging**

```dart
// Use debugPrint for development logging
debugPrint('🖥️ [NativeTray] Initializing native tray service...');

// Use conditional logging
if (kDebugMode) {
  print('Debug information: $data');
}
```

#### **Performance Profiling**

```bash
# Profile app performance
flutter run --profile

# Analyze performance in DevTools
flutter run --profile --trace-startup
```

---

## 🔄 **Contribution Process**

### **1. Before Starting**

- Check existing issues and PRs
- Discuss major changes in GitHub Discussions
- Follow the project roadmap and priorities

### **2. Development Process**

1. **Fork Repository**: Create your own fork
2. **Create Branch**: Use descriptive branch names
3. **Implement Changes**: Follow coding standards
4. **Test Thoroughly**: Ensure all tests pass
5. **Update Documentation**: Keep docs current

### **3. Pull Request Process**

1. **Create PR**: Use the provided PR template
2. **Describe Changes**: Explain what and why
3. **Link Issues**: Reference related issues
4. **Request Review**: Tag relevant maintainers
5. **Address Feedback**: Respond to review comments

### **4. Review Criteria**

- ✅ Code follows project standards
- ✅ Tests pass and coverage is maintained
- ✅ Documentation is updated
- ✅ No breaking changes (unless discussed)
- ✅ Performance impact is acceptable

---

## 📚 **Additional Resources**

### **Documentation**

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [tray_manager Package](https://pub.dev/packages/tray_manager)
- [Project Architecture Docs](../ARCHITECTURE/)

### **Community**

- **GitHub Discussions**: Ask questions and share ideas
- **GitHub Issues**: Report bugs and request features
- **Code Reviews**: Learn from existing PRs

### **Development Tools**

- **Flutter DevTools**: Performance and debugging
- **Dart Analyzer**: Code quality analysis
- **Flutter Inspector**: Widget debugging
- **Hot Reload**: Fast development iteration

---

**Welcome to the Zoidbot development team! We're excited to see your contributions to the unified Flutter-native architecture.**
