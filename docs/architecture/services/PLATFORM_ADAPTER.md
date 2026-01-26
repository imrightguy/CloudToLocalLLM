# Platform Adapter

The Platform Adapter provides automatic component selection based on the detected platform, ensuring that the application uses platform-appropriate UI components across Web, Windows, Linux, and potentially iOS and Android.

## Overview

The `PlatformAdapter` class works in conjunction with `PlatformDetectionService` to:

- Detect the current platform (Web, Windows, Linux, macOS, iOS, Android)
- Select appropriate UI components (Material Design, Cupertino, Desktop)
- Provide platform-specific styling and behavior
- Cache platform detection results for performance
- Support feature detection for platform-specific capabilities

## Architecture

```
PlatformDetectionService
    ↓
  Detects Platform
    ↓
PlatformAdapter
    ↓
Selects Components
    ↓
Platform-Appropriate UI
```

## Platform Detection

The `PlatformDetectionService` provides:

### Platform Information

- `isWeb` - Running on Flutter web
- `isWindows` - Running on Windows desktop
- `isLinux` - Running on Linux desktop
- `isMacOS` - Running on macOS desktop
- `isDesktop` - Running on any desktop platform
- `isMobile` - Running on iOS or Android

### Caching

- Platform detection results are cached for 5 minutes
- Cache can be manually cleared with `clearCache()`
- Improves performance by avoiding repeated detection

### Screen Size Detection

```dart
final screenInfo = platformService.getScreenInfo(width, height);
// Returns:
// {
//   'width': 1920,
//   'height': 1080,
//   'isMobileSize': false,    // < 600px
//   'isTabletSize': false,    // 600-1024px
//   'isDesktopSize': true     // > 1024px
// }
```

## Component Selection

The `PlatformAdapter` provides methods to build platform-appropriate components:

### Buttons

```dart
// Primary button
platformAdapter.buildButton(
  onPressed: () {},
  child: Text('Submit'),
  isPrimary: true,
);

// Secondary button
platformAdapter.buildButton(
  onPressed: () {},
  child: Text('Cancel'),
  isPrimary: false,
);
```

### Text Fields

```dart
platformAdapter.buildTextField(
  controller: controller,
  label: 'Username',
  placeholder: 'Enter username',
  onChanged: (value) {},
);
```

### Switches

```dart
platformAdapter.buildSwitch(
  value: isEnabled,
  onChanged: (value) {
    setState(() => isEnabled = value);
  },
);
```

### Sliders

```dart
platformAdapter.buildSlider(
  value: volume,
  onChanged: (value) {
    setState(() => volume = value);
  },
  min: 0.0,
  max: 1.0,
);
```

### Progress Indicators

```dart
// Indeterminate
platformAdapter.buildProgressIndicator();

// Determinate
platformAdapter.buildProgressIndicator(value: 0.5);
```

### Dialogs

```dart
await platformAdapter.showPlatformDialog(
  context: context,
  title: 'Confirm Action',
  content: 'Are you sure?',
  confirmText: 'Yes',
  cancelText: 'No',
  onConfirm: () {},
  onCancel: () {},
);
```

### App Bars

```dart
platformAdapter.buildAppBar(
  title: 'My App',
  actions: [
    IconButton(icon: Icon(Icons.settings), onPressed: () {}),
  ],
);
```

### List Tiles

```dart
platformAdapter.buildListTile(
  leading: Icon(Icons.person),
  title: Text('John Doe'),
  subtitle: Text('john@example.com'),
  trailing: Icon(Icons.chevron_right),
  onTap: () {},
);
```

### Cards

```dart
platformAdapter.buildCard(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Card Content'),
  ),
);
```

### Checkboxes

```dart
platformAdapter.buildCheckbox(
  value: isChecked,
  onChanged: (value) {
    setState(() => isChecked = value ?? false);
  },
);
```

### Radio Buttons

```dart
platformAdapter.buildRadio<String>(
  value: 'option1',
  groupValue: selectedOption,
  onChanged: (value) {
    setState(() => selectedOption = value);
  },
);
```

### Dropdowns

```dart
platformAdapter.buildDropdown<String>(
  value: selectedValue,
  items: [
    DropdownMenuItem(value: 'option1', child: Text('Option 1')),
    DropdownMenuItem(value: 'option2', child: Text('Option 2')),
  ],
  onChanged: (value) {
    setState(() => selectedValue = value);
  },
  hint: 'Select an option',
);
```

## Feature Detection

Check if platform supports specific features:

```dart
// System tray (desktop only, not web)
if (platformAdapter.supportsFeature('system_tray')) {
  // Show system tray icon
}

// Window management (desktop only, not web)
if (platformAdapter.supportsFeature('window_management')) {
  // Enable window controls
}

// File system (non-web)
if (platformAdapter.supportsFeature('file_system')) {
  // Enable file operations
}

// Notifications (all platforms)
if (platformAdapter.supportsFeature('notifications')) {
  // Show notifications
}

// Biometric authentication (mobile only)
if (platformAdapter.supportsFeature('biometric_auth')) {
  // Enable fingerprint/face ID
}
```

## Platform-Specific Styling

Get platform-appropriate styling values:

```dart
final styling = platformAdapter.getPlatformStyling();

// Returns:
// {
//   'buttonPadding': EdgeInsets(...),
//   'inputPadding': EdgeInsets(...),
//   'borderRadius': 4.0,
//   'elevation': 2.0,
// }
```

## Usage in Widgets

### Using PlatformAdapter Directly

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final platformAdapter = serviceLocator.get<PlatformAdapter>();
    
    return platformAdapter.buildButton(
      onPressed: () {},
      child: Text('Click Me'),
    );
  }
}
```

### Using PlatformAwareButton Widget

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformAwareButton(
      onPressed: () {},
      child: Text('Click Me'),
      isPrimary: true,
    );
  }
}
```

## Component Mapping

### Current Platform Support

| Platform | Component Style | Status |
|----------|----------------|--------|
| Web | Material Design | ✅ Implemented |
| Windows | Material Design (Desktop) | ✅ Implemented |
| Linux | Material Design (Desktop) | ✅ Implemented |
| macOS | Material Design (Desktop) | 🔄 Planned |
| iOS | Cupertino | 🔄 Planned |
| Android | Material Design | 🔄 Planned |

### Component Fallback

If a platform-specific component is not available, the adapter falls back to Material Design components, ensuring the application always renders correctly.

## Dependency Injection

The `PlatformAdapter` is registered in the service locator during app initialization:

```dart
// In lib/di/locator.dart
final platformDetectionService = PlatformDetectionService();
serviceLocator.registerSingleton<PlatformDetectionService>(
  platformDetectionService,
);

final platformAdapter = PlatformAdapter(platformDetectionService);
serviceLocator.registerSingleton<PlatformAdapter>(platformAdapter);
```

## Testing

Both `PlatformDetectionService` and `PlatformAdapter` have comprehensive test coverage:

- `test/services/platform_detection_service_test.dart` - 42 tests
- `test/services/platform_adapter_test.dart` - 26 tests

Run tests:

```bash
flutter test test/services/platform_detection_service_test.dart
flutter test test/services/platform_adapter_test.dart
```

## Performance Considerations

### Caching

- Platform detection is cached for 5 minutes
- Detection info is cached until platform changes
- Cache can be manually cleared if needed

### Optimization

- Platform detection completes within 100ms (Requirement 2.1)
- Component selection is instantaneous (no async operations)
- Minimal memory footprint

## Future Enhancements

### iOS Support

- Add Cupertino component mapping
- Implement iOS-specific styling
- Add iOS feature detection

### Android Support

- Optimize Material Design for Android
- Add Android-specific features
- Implement Android-specific styling

### macOS Support

- Add macOS-specific components
- Implement macOS styling
- Add macOS feature detection

## Requirements Validation

This implementation satisfies the following requirements:

- ✅ 2.1: Platform detection within 100ms
- ✅ 2.2: Platform information available to all screens
- ✅ 2.3: Platform-specific information (screen size, capabilities)
- ✅ 2.4: Material Design for Web
- ✅ 2.5: Desktop components for Windows/Linux
- ✅ 2.6: Cupertino for iOS (architecture ready)
- ✅ 2.7: Material Design for Android (architecture ready)
- ✅ 16.1-16.6: Platform-specific component selection with fallback
- ✅ 18.4: Platform detection caching

## Related Documentation

- [ThemeProvider](./theme_provider.dart) - Theme management
- [Platform Settings Screen](.kiro/specs/platform-settings-screen/) - Platform-specific settings
- [Unified App Theming](.kiro/specs/unified-app-theming/) - Unified theming system
