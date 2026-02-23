---
name: desktop-control
description: Desktop automation development with GUI automation templates, clipboard management, window control scripts, and screen capture patterns for CloudToLocalLLM (Pillar 4)
user-invocable: true
---

# Desktop Control Development

Desktop automation templates and scripts for CloudToLocalLLM's Desktop Control pillar (Pillar 4).

## Context

Desktop Control capabilities include:
- **GUI Automation** - `GuiAutomationService` for screenshot and vision-powered automation
- **System Control** - `SystemControlService` for command execution
- **Window Management** - Window manipulation (desktop only)
- **Clipboard Service** - Cross-platform clipboard operations
- **File Operations** - Safe file manipulation

## Quick Start

### Take Screenshot
```dart
final guiService = GuiAutomationService();
final screenshot = await guiService.takeScreenshot();
```

### Execute Command
```dart
final systemService = SystemControlService();
final result = await systemService.executeCommand('ls -la');
```

### Clipboard Operations
```dart
final clipboard = ClipboardService();
await clipboard.setText('Hello from automation!');
final text = await clipboard.getText();
```

## Templates

### Screenshot Capture Template
```dart
import 'package:cloudtolocalllm/services/gui_automation_service.dart';

/// Capture screenshot with optional region selection
Future<void> captureScreenshot() async {
  final guiService = GuiAutomationService();

  // Full screen capture
  final screenshot = await guiService.takeScreenshot();

  // Region capture (x, y, width, height)
  final region = Rect.fromLTWH(100, 100, 800, 600);
  final regionScreenshot = await guiService.takeRegionScreenshot(region);

  // Save to file
  await screenshot.saveTo('screenshot.png');

  print('✓ Screenshot saved');
}
```

### Window Control Template
```dart
import 'package:window_manager/window_manager.dart';

/// Window control operations (desktop only)
Future<void> controlWindows() async {
  // Get focused window
  final focused = await WindowManager.getActiveWindow();

  // Move window
  await focused.setBounds(Rect.fromLTWH(100, 100, 1200, 800));

  // Minimize/Maximize
  await focused.minimize();
  await focused.maximize();

  // List all windows
  final windows = await WindowManager.getAllWindows();
  for (final window in windows) {
    print('${window.title} - ${window.rect}');
  }
}
```

## Scripts

### Platform Detection Script
```bash
#!/bin/bash
# Detect current platform and available features

case "$(uname -s)" in
  Linux*)
    echo "Platform: Linux"
    echo "Window management: available (xdotool)"
    echo "Clipboard: available (xclip)"
    echo "Screenshot: available (import, grim)"
    ;;
  Darwin*)
    echo "Platform: macOS"
    echo "Window management: available (AppleScript)"
    echo "Clipboard: available (pbcopy/pbpaste)"
    echo "Screenshot: available (screencapture)"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Platform: Windows"
    echo "Window management: limited"
    echo "Clipboard: available (PowerShell)"
    echo "Screenshot: available (PowerShell)"
    ;;
  *)
    echo "Platform: Unknown"
    ;;
esac
```

## Related Files
- GUI automation: `lib/services/gui_automation_service.dart`
- System control: `lib/services/system_control_service.dart`
- Window manager: `lib/services/window_manager_service.dart`
- GUI screen: `lib/screens/gui_automation_screen.dart`
