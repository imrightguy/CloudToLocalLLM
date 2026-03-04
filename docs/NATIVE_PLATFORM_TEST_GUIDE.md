# Native Platform Manual Testing Guide

## App Status: Running ✓

The CloudToLocalLLM app is currently running with native platform channels registered.

## What to Test

### 1. Screenshot Capture

**How to test:**
- Navigate to Vision Settings in the app
- Click "Take Test Screenshot" button
- Check if screenshot file is created at `/tmp/cloudtolocallm_screenshot.ppm`

**Expected result:** `true` (success)

**To verify:**
```bash
ls -lh /tmp/*.ppm
# Should show a screenshot file
```

### 2. Window List

**How to test:**
- Navigate to Desktop Control → Window Manager
- Click "Refresh Window List"
- Should see a list of open windows

**Expected result:** List of windows with id, title, x, y, width, height, appName

### 3. Window Focus

**How to test:**
- In Window Manager, select a window from the list
- Click "Focus Window"
- Selected window should come to foreground

**Expected result:** Window gains focus

### 4. Window Move/Resize

**How to test:**
- Select a window
- Enter new X/Y coordinates and click "Move Window"
- Enter new width/height and click "Resize Window"
- Window should move/resize

**Expected result:** Window geometry changes

### 5. Input Simulation

**How to test:**
- Open a text editor (e.g., gedit)
- In Desktop Control → Input Simulation, click "Test Space Key"
- The text editor should receive a space character

**Expected result:** Key press is simulated

### 6. Mouse Click

**How to test:**
- Click "Test Click at (100, 100)"
- Should see a mouse click at those coordinates

**Expected result:** Mouse click occurs

## Quick Verification Commands

```bash
# Check if app is running
ps aux | grep cloudtolocalllm | grep -v grep

# Check for screenshot files
ls -lh /tmp/*.ppm

# Check for X11 display
echo $DISPLAY
```

## Known Limitations

- Window state detection (isMinimized, isMaximized, isActive) returns `false` placeholder
- Region capture not yet implemented (only full screen)
- Camera capture not yet implemented
- Drag and drop not yet implemented

## If Something Doesn't Work

1. Check app console output for errors
2. Verify X11 is running: `echo $DISPLAY`
3. Check if native channels are registered (no errors on startup)
4. Verify CMakeLists.txt has X11 libraries linked

## Current Build Status

✅ Debug build compiles
✅ Release build compiles
✅ Channel registration successful
✅ No X11 linker errors
✅ App launches without native channel errors
