# Vision System Architecture

**Pillar 5: Vision** — Screen understanding and camera input for enhanced AI interaction.

---

## Overview

The Vision System enables the AI assistant to see and understand visual content through screen capture, region selection, camera input, and OCR text extraction. Powered by OpenClaw Gateway's vision models, the system can analyze screenshots, extract text from images, and provide continuous screen monitoring for automated tasks.

**Current Status**: Full-screen capture and vision analysis working (30% complete)

**Planned Features**: Region capture, camera input, OCR engine, continuous monitoring

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                       Vision System                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                       UI Layer                              │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         GuiAutomationScreen                          │ │ │
│  │  │  - Full screenshot button                             │ │ │
│  │  │  - Region selection tool                              │ │ │
│  │  │  - Camera preview widget                              │ │ │
│  │  │  - OCR results display                                │ │ │
│  │  │  - Monitoring toggle (with indicator)                 │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         RegionSelectorDialog                          │ │ │
│  │  │  - Drag-to-select region                             │ │ │
│  │  │  - Coordinate display                                 │ │ │
│  │  │  - Capture/Cancel buttons                             │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                     Service Layer                           │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         ScreenCaptureService                           │ │ │
│  │  │  - captureFullScreen()                                 │ │ │
│  │  │  - captureRegion(x, y, width, height)                 │ │ │
│  │  │  - saveToTemp(bytes)                                   │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         CameraCaptureService                          │ │ │
│  │  │  - initialize()                                       │ │ │
│  │  │  - captureFrame()                                     │ │ │
│  │  │  - buildPreview()                                     │ │ │
│  │  │  - switchCamera()                                     │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         OcrEngine                                     │ │ │
│  │  │  - extractText(imageData)                             │ │ │
│  │  │  - extractTextWithRegions(imageData)                 │ │ │
│  │  │  - extractTextFromFile(imagePath)                     │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         ScreenMonitorService                         │ │ │
│  │  │  - startMonitoring(region, interval)                 │ │ │
│  │  │  - stopMonitoring()                                  │ │ │
│  │  │  - getEvents()                                       │ │ │
│  │  │  - _analyzeFrame(imageData, text)                    │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Vision Processing                         │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         OpenClaw Gateway (localhost:18789)           │ │ │
│  │  │  ┌────────────────────────────────────────────────┐  │ │ │
│  │  │  │           Vision Model                          │  │ │ │
│  │  │  │  - Image understanding                          │  │ │ │
│  │  │  │  - UI element detection                          │  │ │ │
│  │  │  │  - Scene description                             │  │ │ │
│  │  │  └────────────────────────────────────────────────┘  │ │ │
│  │  │  ┌────────────────────────────────────────────────┐  │ │ │
│  │  │  │              OCR Engine                         │  │ │ │
│  │  │  │  - Text extraction (Tesseract)                 │  │ │ │
│  │  │  │  - Multi-language support                      │  │ │ │
│  │  │  │  - Bounding box detection                      │  │ │ │
│  │  │  └────────────────────────────────────────────────┘  │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                Native Platform Layer                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │ │
│  │  │Screenshot API│  │Camera API    │  │Image Processing│  │ │
│  │  │- X11/Linux   │  │- Webcam      │  │- Crop/Decode   │  │ │
│  │  │- Win32 GDI   │  │- Multiple    │  │- Encode/Decode │  │ │
│  │  │- Cocoa/macOS │  │ cameras      │  │- Compression   │  │ │
│  │  └──────────────┘  └──────────────┘  └────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Screen Capture Service

**File**: `lib/services/vision/screen_capture.dart` (🔲 To Create)

**Purpose**: Capture full screen or specific regions

**Key Features**:
```dart
class ScreenCaptureService {
  // Capture full screen
  Future<Uint8List> captureFullScreen();

  // Capture specific region
  Future<Uint8List> captureRegion(Region region);

  // Save to temporary file
  Future<File> saveToTemp(Uint8List bytes);

  // Get screen dimensions
  Future<Size> getScreenSize();

  // Convert screenshot to different formats
  Future<String> toBase64(Uint8List bytes);
  Future<File> toPng(Uint8List bytes);
  Future<File> toJpeg(Uint8List bytes, {int quality = 90});
}
```

**Region Definition**:
```dart
class Region {
  final int x;
  final int y;
  final int width;
  final int height;

  const Region({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  // Convert to Rect
  Rect toRect() => Rect.fromLTWH(x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble());
}
```

---

### 2. Camera Capture Service

**File**: `lib/services/vision/camera_capture.dart` (🔲 To Create)

**Purpose**: Capture input from webcam for real-time vision

**Key Features**:
```dart
class CameraCaptureService {
  // Initialize camera
  Future<void> initialize();

  // Get available cameras
  Future<List<CameraDescription>> getAvailableCameras();

  // Switch to specific camera
  Future<void> switchCamera(CameraDescription camera);

  // Capture single frame
  Future<Uint8List> captureFrame();

  // Start stream capture
  Stream<Uint8List> startStream({Duration interval = const Duration(seconds: 1)});

  // Stop capture
  void stop();

  // Get camera preview widget
  Widget buildPreview();

  // Dispose resources
  void dispose();
}
```

**Camera States**:
- `uninitialized`: Camera not set up
- `initializing`: Setting up camera hardware
- `ready`: Camera ready for capture
- `capturing`: Currently capturing frame
- `error`: Camera failed to initialize

---

### 3. OCR Engine

**File**: `lib/services/vision/ocr_engine.dart` (🔲 To Create)

**Purpose**: Extract text from images (screenshots, camera frames)

**Key Features**:
```dart
class OcrEngine {
  // Extract text from image bytes
  Future<String> extractText(Uint8List imageData);

  // Extract text from file
  Future<String> extractTextFromFile(String imagePath);

  // Extract text with bounding boxes
  Future<List<TextRegion>> extractTextWithRegions(Uint8List imageData);

  // Set OCR language
  void setLanguage(String language);  // 'eng', 'spa', 'fra', etc.

  // Set page segmentation mode
  void setPsm(int mode);  // 0-13 (see Tesseract docs)
}
```

**Text Region**:
```dart
class TextRegion {
  final String text;
  final Rect boundingBox;
  final double confidence;

  const TextRegion({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });
}
```

**Languages Supported**:
- English (eng)
- Spanish (spa)
- French (fra)
- German (deu)
- Chinese (chi_sim, chi_tra)
- And 100+ more via Tesseract

---

### 4. Screen Monitor Service

**File**: `lib/services/vision/screen_monitor.dart` (🔲 To Create)

**Purpose**: Background screen watching for event detection

**Key Features**:
```dart
class ScreenMonitorService with ChangeNotifier {
  // Start monitoring a region at interval
  Future<void> startMonitoring({
    required Region region,
    required Duration interval,
  });

  // Stop monitoring
  Future<void> stopMonitoring();

  // Get detected events
  List<ScreenEvent> get events;

  // Clear event history
  void clearEvents();

  // Monitoring status
  bool get isMonitoring;
}
```

**Screen Event**:
```dart
class ScreenEvent {
  final DateTime timestamp;
  final String text;          // OCR'd text
  final String detectedContent;  // AI-detected change
  final double confidence;    // Detection confidence

  const ScreenEvent({
    required this.timestamp,
    required this.text,
    required this.detectedContent,
    required this.confidence,
  });
}
```

**Use Cases**:
- Monitor for notification popups
- Watch for download completion
- Detect error dialogs
- Track progress bar changes

---

## Data Flow

### Full Screenshot Flow

```
User clicks "Capture Screenshot"
        ↓
ScreenCaptureService.captureFullScreen()
        ↓
Native platform API called
        ↓
Screenshot returned as Uint8List
        ↓
Saved to temp file
        ↓
GuiAutomationService.analyzeScreenshot(imagePath)
        ↓
Image encoded as base64
        ↓
Sent to OpenClaw Gateway
        ↓
Vision model analysis
        ↓
Results displayed to user
```

### Region Capture Flow

```
User clicks "Select Region"
        ↓
RegionSelectorDialog opens
        ↓
User drags to select area
        ↓
Region coordinates captured
        ↓
ScreenCaptureService.captureRegion(region)
        ↓
Only selected area captured
        ↓
Crop to region bounds
        ↓
Return region image bytes
```

### OCR Flow

```
Image captured (screen or camera)
        ↓
OcrEngine.extractText(imageData)
        ↓
Image pre-processing (grayscale, denoise)
        ↓
Tesseract OCR engine
        ↓
Text extraction with confidence scores
        ↓
Bounding box calculation
        ↓
Return List<TextRegion>
```

### Continuous Monitoring Flow

```
User starts monitoring
        ↓
ScreenMonitorService.startMonitoring(region, interval)
        ↓
Timer starts (e.g., every 5 seconds)
        ↓
For each tick:
  captureRegion(region)
  ↓
  OcrEngine.extractText(imageData)
  ↓
  Compare with previous frame
  ↓
  If changed: Create ScreenEvent
  ↓
  Add to events list (max 100)
```

---

## Privacy & Security

**Privacy Indicators**:
- Clear visual indicator when camera is active
- System notification when monitoring starts
- Screen border highlight during region monitoring
- Logging of all capture events

**User Consent**:
- Explicit opt-in for camera access
- Explicit opt-in for continuous monitoring
- Clear warning about privacy implications

**Local Processing**:
- All OCR happens locally via Tesseract
- No images sent to cloud for OCR
- Vision analysis via local OpenClaw Gateway only

**Data Retention**:
- Screenshots saved to temp directory only
- Auto-cleanup on app exit
- User can manually clear cache

**Sensitive Content Handling**:
- Detect and blur password fields
- Detect and exclude incognito/private windows
- Warn when monitoring browser with sensitive content

---

## Platform Support

| Feature | Linux | Windows | Web |
|---------|-------|---------|-----|
| Screenshot | ✅ X11/Wayland | ✅ Win32 GDI | ❌ None |
| Region capture | ✅ Full | ✅ Full | ❌ None |
| Camera input | ✅ V4L2 | ✅ DirectShow | ⚠️ WebRTC |
| OCR (Tesseract) | ✅ Native | ✅ Native | ❌ None |
| Continuous monitoring | ✅ Full | ✅ Full | ❌ None |

---

## Dependencies

```yaml
dependencies:
  # Camera access
  camera: ^0.10.5

  # OCR
  tesseract_ocr: ^0.4.0

  # Image processing
  image: ^4.0.0

  # Path provider for temp files
  path_provider: ^2.1.0

  # Permissions
  permission_handler: ^11.0.0
```

---

## Performance Considerations

**Screenshot Capture**:
- Full screen: ~50-200ms depending on resolution
- Region capture: ~10-50ms (faster due to smaller area)
- Compression adds ~20-50ms

**OCR Processing**:
- Small text regions: ~100-500ms
- Full screen text: ~2-5 seconds
- Depends on CPU, text density, language

**Monitoring Impact**:
- 5-second interval: ~2-5% CPU usage
- 1-second interval: ~10-15% CPU usage
- Recommend 5-10 second intervals for long-running monitoring

**Memory Usage**:
- Screenshot in memory: ~5-20 MB (depending on resolution)
- OCR engine: ~50-100 MB RAM
- Camera preview: ~30-50 MB RAM

---

## Implementation Status

| Component | Status | File |
|-----------|--------|------|
| Full-screen capture | ✅ Working | `lib/services/system_control_service.dart` |
| Vision analysis | ✅ Working | `lib/services/gui_automation_service.dart` |
| Region capture | 🔲 To Create | `lib/services/vision/region_capture.dart` |
| Camera input | 🔲 To Create | `lib/services/vision/camera_capture.dart` |
| OCR engine | 🔲 To Create | `lib/services/vision/ocr_engine.dart` |
| Continuous monitoring | 🔲 To Create | `lib/services/vision/screen_monitor.dart` |
| Privacy indicators | 🔲 To Create | UI widgets |
| Region selector UI | 🔲 To Create | `RegionSelectorDialog` |

---

## Related Documentation

- [Implementation Plan - Phase 3](../development/IMPLEMENTATION_PLAN.md#phase-3-advanced-vision--avatar)
- [SPEC.md - Vision Capabilities](../SPEC.md#5-vision-capabilities)
- [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
- [Desktop Control](DESKTOP_CONTROL.md)
