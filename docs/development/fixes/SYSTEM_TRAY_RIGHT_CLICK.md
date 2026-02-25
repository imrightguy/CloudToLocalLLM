# System Tray Right-Click Context Menu Fix

## Issue Description

The system tray icon in CloudToLocalLLM was not responding to right-click events on Windows, preventing users from accessing the context menu with options like "Show", "Hide", "Settings", and "Quit".

## Root Cause

The issue was caused by a limitation in the `tray_manager` package version 0.5.0 on Windows:

1. **Automatic Context Menu Display**: The package does not automatically show the context menu on right-click as expected
2. **Event Handler Issue**: The `onTrayIconRightMouseDown()` method was only logging a message and expecting automatic behavior
3. **Windows-Specific Bug**: On Windows, both left and right clicks trigger `onTrayIconMouseDown()`, making right-click detection unreliable

## Solution Implemented

### 1. Explicit Context Menu Trigger

Modified `onTrayIconRightMouseDown()` to explicitly call `trayManager.popUpContextMenu()`:

```dart
@override
void onTrayIconRightMouseDown() {
  debugPrint('🖥️ [NativeTray] Tray icon right-clicked');
  _showContextMenu();
}
```

### 2. Fallback Mechanism

Added `onTrayIconRightMouseUp()` as a fallback for timing-sensitive scenarios:

```dart
@override
void onTrayIconRightMouseUp() {
  debugPrint('🖥️ [NativeTray] Tray icon right-click released');
  _showContextMenu();
}
```

### 3. Robust Context Menu Helper

Created a dedicated `_showContextMenu()` method with proper error handling:

```dart
Future<void> _showContextMenu() async {
  try {
    debugPrint('🖥️ [NativeTray] Manually triggering context menu');
    await trayManager.popUpContextMenu();
    debugPrint('🖥️ [NativeTray] Context menu displayed successfully');
  } catch (e) {
    debugPrint('🖥️ [NativeTray] Failed to show context menu: $e');
    // Context menu failure is not critical - user can still left-click
  }
}
```

## Files Modified

- `lib/services/native_tray_service.dart` - Added explicit context menu triggering
- `test/services/native_tray_service_test.dart` - Added tests for right-click behavior
- `test/test_config.dart` - Updated mock to include `popUpContextMenu` method
- `test/mocks/mock_tray_manager.dart` - Enhanced mock with additional methods

## Testing

### Automated Tests

```bash
flutter test test/services/native_tray_service_test.dart
```

### Manual Testing

1. **Build and run the application**:

   ```bash
   flutter build windows
   flutter run -d windows
   ```

2. **Test right-click functionality**:
   - Minimize the application to system tray
   - Right-click on the tray icon
   - Verify that the context menu appears with all expected options:
     - Show CloudToLocalLLM
     - Hide CloudToLocalLLM
     - Local Ollama: [status]
     - Cloud Proxy: [status]
     - Settings
     - Reconnect All
     - Quit

3. **Test menu item functionality**:
   - Click each menu item to ensure proper behavior
   - Verify that "Show" brings the window to foreground
   - Verify that "Quit" closes the application

## Expected Behavior After Fix

- **Right-click on tray icon**: Context menu appears immediately
- **Left-click on tray icon**: Application window is shown/brought to foreground
- **Menu items work correctly**: All context menu options function as expected
- **Error resilience**: If context menu fails to display, the application continues to work normally

## Platform Compatibility

This fix specifically addresses the Windows issue with `tray_manager` 0.5.0. The solution:

- ✅ **Windows**: Explicitly triggers context menu on right-click
- ✅ **Linux**: Should work with existing behavior (context menu may show automatically)
- ✅ **macOS**: Should work with existing behavior (context menu may show automatically)

## Related Issues

- [tray_manager Issue #57](https://github.com/leanflutter/tray_manager/issues/57): Windows right-click detection problem
- Known limitation: `onTrayIconMouseDown()` triggers for both left and right clicks on Windows

## Future Considerations

If the `tray_manager` package is updated to fix the underlying Windows issue, this explicit triggering approach will remain compatible and can be simplified in future versions.
