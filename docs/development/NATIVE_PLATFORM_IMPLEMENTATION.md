# Native Platform Implementation Status

> **Last Updated**: 2026-03-04
> **Status**: ✅ Linux Implementation Verified - Build + Channels Working

---

## Overview

Native platform implementations enable Vision and Desktop Control features to work on Linux and Windows. The Flutter services (created in previous tasks) use `MethodChannel` to communicate with native code for:

- **Screenshot capture** (region, full screen)
- **Camera access** (for OCR and real-time vision)
- **Window management** (list, focus, move, resize, minimize, maximize, close)
- **Input simulation** (keyboard, mouse)

---

## Linux Implementation (🟡 Partial)

### Files Created

| File | Purpose | Status |
|------|---------|--------|
| `linux/runner/platform_channels.cc` | Method channel handlers | ✅ API Fixed |
| `linux/runner/platform_channels.h` | Header file | ✅ Complete |
| `linux/runner/my_application.cc` | Channel registration | ✅ Updated |
| `linux/runner/CMakeLists.txt` | Build configuration | ✅ Updated |

### Implemented Features

#### Screenshot Capture
```cpp
static FlValue* capture_screenshot(FlValue* args)
```
- Uses X11 `XGetImage` for screen capture
- Saves as PPM format (no external dependencies)
- Returns `true` on success, `false` on failure

#### Window Management
```cpp
static FlValue* get_windows()           // List all windows
static FlValue* focus_window(FlValue*)   // Focus window by ID
static FlValue* move_window(FlValue*)    // Move window (x, y)
static FlValue* resize_window(FlValue*)  // Resize (width, height)
static FlValue* minimize_window(FlValue*)
static FlValue* maximize_window(FlValue*)
static FlValue* toggle_maximize(FlValue*)
static FlValue* close_window(FlValue*)   // Close gracefully
```

- Uses EWMH (`_NET_CLIENT_LIST`) for window enumeration
- Supports window title, geometry, app name
- State flags (minimized, maximized, active) - placeholder for now

#### Input Simulation
```cpp
static FlValue* execute_action(FlValue* args)
```
- **Click**: `click(x,y)` - XTest fake motion + button event
- **Key press**: `keypress(keyname)` - Supports Enter, Tab, Escape, Backspace, Delete, space, and single characters
- **Scroll**: `scroll(up|down|left|right)` - Mouse button 4-7

### Build Dependencies Added
```cmake
target_link_libraries(${BINARY_NAME} PRIVATE X11)
target_link_libraries(${BINARY_NAME} PRIVATE Xext)
target_link_libraries(${BINARY_NAME} PRIVATE X11-xcb)
target_link_libraries(${BINARY_NAME} PRIVATE Xcb)
target_link_libraries(${BINARY_NAME} PRIVATE Imlib2)
```

### Known Issues

**None** - Flutter Linux API compatibility has been verified and fixed (commit 2941bceb6).

### Missing Features (Not Yet Implemented):
   - Region capture (only full screen implemented)
   - Camera capture via V4L2
   - Window state detection (currently returns false placeholders)
   - Drag and drop

---

## Windows Implementation (🔲 Not Started)

### Required Files (Not Created)
- `windows/runner/platform_channels.cpp`
- `windows/runner/platform_channels.h`
- `windows/runner/main.cpp` (update)
- `windows/CMakeLists.txt` (update)

### Planned Implementation

#### Screenshot Capture
- Use `GetDC` + `CreateCompatibleDC` + `BitBlt`
- Save as BMP or PNG

#### Window Management
- Use `EnumWindows` for enumeration
- `SetForegroundWindow` for focus
- `SetWindowPos` for move/resize
- `ShowWindow(SW_MINIMIZE)` for minimize
- `ShowWindow(SW_MAXIMIZE)` for maximize
- `PostMessage(WM_CLOSE)` for close

#### Input Simulation
- `SendInput` for keyboard/mouse events
- `INPUT` structure with `KEYBDINPUT` and `MOUSEINPUT`

---

## Testing Checklist

### Linux
- [x] Build compiles without errors (debug + release)
- [x] Channel registration verified (names match Flutter services)
- [x] X11 libraries linked correctly (X11, Xtst, xcb)
- [ ] Screenshot captures to file correctly
- [ ] Window list returns all visible windows
- [ ] Focus window brings target to front
- [ ] Move/resize window works
- [ ] Minimize/maximize/close works
- [ ] Click at coordinates works
- [ ] Keypress sends correct key
- [ ] Scroll works

### Windows
- [ ] Files created and build compiles
- [ ] All features work as expected

---

## Next Steps

### Immediate (Required for Basic Functionality)

1. **Implement Region Capture**
   - Add `captureRegion(x, y, width, height)` method
   - Use XGetImage with crop rectangle

2. **Add to CI/CD**
   - Build Linux executable on each commit
   - Run integration tests

### Future Enhancements

1. **Camera Capture** (Phase 3)
   - Use V4L2 (Video4Linux2) for camera access
   - Integrate with Flutter camera plugin

2. **Advanced Window State Detection**
   - Check `_NET_WM_STATE` for actual window state
   - Detect fullscreen, hidden, skip taskbar

3. **Hotkeys Support**
   - Register global hotkeys for quick actions
   - Use X11 `XGrabKey` for hotkey binding

4. **Multi-Monitor Support**
   - Detect all connected displays
   - Handle screen coordinates correctly across monitors

---

## Development Resources

### X11 Documentation
- [Xlib Programming Manual](https://www.x.org/releases/X11R7.7/doc/libX11/libX11/libX11.html)
- [EWMH Specification](https://specifications.freedesktop.org/wm-spec/wm-spec-latest.html)
- [XTest Extension](https://www.x.org/releases/X11R7.7/doc/xextlib/XTest.pdf)

### Windows API
- [Win32 API Reference](https://docs.microsoft.com/en-us/windows/win32/api/)
- [SendInput Function](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)

### Flutter Desktop
- [Flutter Linux Wiki](https://github.com/flutter/flutter/wiki/Linux)
- [Flutter Windows Wiki](https://github.com/flutter/flutter/wiki/Windows-Desktop)

---

## Troubleshooting

### Build Errors

**Error**: `error: undefined reference to 'XTestFakeMotionEvent'`

**Solution**: Link against XTest extension library:
```cmake
target_link_libraries(${BINARY_NAME} PRIVATE Xtst)
```

**Error**: `error: cannot find -lXcb`

**Solution**: Use lowercase library name:
```cmake
target_link_libraries(${BINARY_NAME} PRIVATE xcb)  # Not Xcb
```

### Runtime Errors

**Error**: "Failed to open X display"

**Solution**: Make sure X11 is running and `DISPLAY` environment variable is set:
```bash
echo $DISPLAY  # Should be :0 or :1
```

**Error**: Screenshot is all black or corrupted

**Solution**: Check if X11 composite manager is interfering. Try using `XShmGetImage` instead of `XGetImage` for better performance.

**Error**: Cannot focus certain windows

**Solution**: Some windows prevent focus (e.g., sudo applications). Check window manager protocols and permissions.

---

## License Notes

This implementation uses:
- **X11** - MIT/X11 license
- **Imlib2** (optional, for advanced image handling) - BSD license

All code is part of the CloudToLocalLLM project and follows the same license.

---

## Related Files

- `lib/services/vision/region_capture_service.dart` - Flutter-side service
- `lib/services/vision/camera_capture_service.dart` - Flutter-side service
- `lib/services/gui_automation_service.dart` - Flutter-side service
- `lib/services/desktop_control/window_manager_service.dart` - Flutter-side service
- `lib/screens/settings/vision_settings_screen.dart` - UI for testing
