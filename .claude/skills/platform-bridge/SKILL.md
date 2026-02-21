---
name: platform-bridge
description: Create platform-specific implementations (web vs desktop) with conditional imports and stub files
disable-model-invocation: true
---

Create a platform-specific implementation for {{feature_name}} that works on both web and desktop.

Include:
- Main implementation file for desktop (native)
- Web-specific implementation file
- Stub implementation for unused platform
- Conditional import statement
- Test both platforms

Follow existing patterns in lib/services/ and lib/auth/

Platform detection in Dart:
```dart
import 'package:flutter/foundation.dart';

// Check platform
if (kIsWeb) {
  // Web-specific code
} else {
  // Desktop-specific code
}
```

Conditional import pattern:

1. **Main entry point** (lib/services/{{feature_name}}.dart):
```dart
// Conditional import: use web version on web, native version on desktop
import 'platform_implementation.dart'
    if (dart.library.html) 'platform_implementation_web.dart';

// The implementation will be available as PlatformImplementation
```

2. **Desktop implementation** (lib/services/platform_implementation.dart):
```dart
import 'dart:io';

class PlatformImplementation {
  Future<String> getPlatformInfo() async {
    return 'Desktop: ${Platform.operatingSystem}';
  }

  Future<void> performNativeAction() async {
    // Native desktop code
    // Access file system, native APIs, etc.
  }
}
```

3. **Web implementation** (lib/services/platform_implementation_web.dart):
```dart
import 'dart:js_interop';

@JS()
external void showAlert(String message);

class PlatformImplementation {
  Future<String> getPlatformInfo() async {
    return 'Web Browser';
  }

  Future<void> performNativeAction() async {
    // Web-specific code using JS interop
    showAlert('Action performed on web');
  }
}
```

4. **Stub implementation** (if needed for imports):
```dart
// lib/services/platform_implementation_stub.dart
// Used when platform is not supported

class PlatformImplementation {
  Future<String> getPlatformInfo() async {
    throw UnsupportedError('Platform not supported');
  }

  Future<void> performNativeAction() async {
    throw UnsupportedError('Platform not supported');
  }
}
```

Conditional import syntax examples:

**Web vs Desktop (most common):**
```dart
import 'service.dart'
    if (dart.library.html) 'service_web.dart';
```

**Native (Windows/Linux/macOS) vs Web:**
```dart
import 'service.dart'
    if (dart.library.html) 'service_web.dart'
    if (dart.library.io) 'service_native.dart';
```

**Multiple conditional imports:**
```dart
import 'service.dart'
    if (dart.library.html) 'service_web.dart'
    if (dart.library.js_interop) 'service_js_interop.dart'
    if (dart.library.io) 'service_io.dart';
```

Common use cases:

**1. File system operations:**
```dart
// Desktop: use dart:io
import 'file_service.dart'
    if (dart.library.html) 'file_service_web.dart';

// Desktop: file_service.dart
import 'dart:io';

class FileService {
  Future<String> readFile(String path) async {
    return await File(path).readAsString();
  }
}

// Web: file_service_web.dart
import 'dart:html' as html;

class FileService {
  Future<String> readFile(String path) async {
    // Use IndexedDB or download/upload APIs
    throw UnimplementedError('Web file reading not implemented');
  }
}
```

**2. Authentication (Auth0):**
```dart
import 'auth_provider.dart'
    if (dart.library.html) 'auth_provider_web.dart';

// Desktop: native Auth0 SDK
// Web: JS bridge to Auth0 SPA SDK
```

**3. Storage:**
```dart
// Desktop: flutter_secure_storage (encrypted SQLite)
// Web: sessionStorage / localStorage via JS interop
```

**4. System integration:**
```dart
// Desktop: window_manager, tray_manager
// Web: No system tray, limited window controls
```

**5. Native APIs:**
```dart
// Desktop: dart:io, platform-specific packages
// Web: dart:js_interop, browser APIs
```

Platform-specific packages:

**Desktop (Windows/Linux/macOS):**
- `window_manager` - Window management
- `tray_manager` - System tray
- `flutter_secure_storage` - Encrypted storage
- `dart:io` - File system, process, network
- `dartssh2` - SSH tunneling
- Platform-specific: `path_provider`, `url_launcher`

**Web:**
- `dart:js_interop` - JavaScript interop
- `dart:html` - HTML/DOM access (via conditional import)
- IndexedDB via `dart:js_interop` or `web` package
- SessionStorage/LocalStorage via JS interop

Testing platform-specific code:

```dart
// In test file
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('PlatformImplementation', () {
    test('works on desktop', () async {
      // Mock kIsWeb if needed, or run on desktop
      final impl = PlatformImplementation();
      final info = await impl.getPlatformInfo();
      expect(info, contains('Desktop'));
    });

    test('works on web', () async {
      // Run on web target
      final impl = PlatformImplementation();
      final info = await impl.getPlatformInfo();
      expect(info, contains('Web'));
    });
  });
}
```

Platform detection at runtime:

```dart
import 'package:flutter/foundation.dart';

// Check platform type
bool get isWeb => kIsWeb;
bool get isDesktop => !kIsWeb;
bool get isMobile => false;  // Not supported currently

// Check specific desktop platform (requires dart:io)
import 'dart:io' show Platform;

bool get isWindows => Platform.isWindows;
bool get isLinux => Platform.isLinux;
bool get isMacOS => Platform.isMacOS;

// Usage
if (kIsWeb) {
  // Web-specific UI or behavior
} else if (Platform.isWindows) {
  // Windows-specific
} else if (Platform.isLinux) {
  // Linux-specific
}
```

Common gotchas:
- Never use `dart:io` directly in web builds (will fail)
- Always use conditional imports for platform-specific code
- Test on all supported platforms (web, Linux, Windows)
- Use stub files to prevent import errors
- JS interop requires proper type definitions
- Web has limited file system access
