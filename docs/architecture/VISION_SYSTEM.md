# Vision System Architecture

Pillar 5, Vision, gives the assistant controlled access to visual context through screenshots, region capture, camera input, and OCR.

## Current Status

The service layer exists for region capture, camera capture, OCR, and vision orchestration. Runtime capability still depends on platform support, user permissions, and native dependencies such as camera devices and OCR libraries.

## Current Components

| Component | Status | File |
| --- | --- | --- |
| Vision orchestration | Implemented | `lib/services/vision/vision_service.dart` |
| Region capture | Implemented | `lib/services/vision/region_capture_service.dart` |
| Camera capture | Implemented | `lib/services/vision/camera_capture_service.dart` |
| OCR engine | Implemented | `lib/services/vision/ocr_engine_service.dart` |
| Screenshot support | Implemented through desktop control | `lib/services/system_control_service.dart` |
| Screenshot analysis | Implemented through GUI automation | `lib/services/gui_automation_service.dart` |
| Continuous screen monitor | Planned | Not present |
| Dedicated privacy indicator widgets | Planned | Not present |

## Service Responsibilities

### `VisionService`

Coordinates higher-level vision workflows and composes capture/OCR services.

### `RegionCaptureService`

Captures selected screen regions where native platform support is available.

### `CameraCaptureService`

Initializes camera access, manages capture state, and supports frame/image capture where camera permissions and platform APIs allow it.

### `OcrEngineService`

Extracts text from image data through the configured OCR path. OCR behavior depends on platform and installed native support.

## Data Flow

Typical screenshot analysis flow:

1. User requests a capture or automation action.
2. Desktop control captures a full screenshot or selected region.
3. Vision/OCR services process image data locally where possible.
4. Optional LLM vision analysis is routed through the configured local provider path.
5. Results are shown to the user before any follow-up desktop action.

Typical camera flow:

1. User grants camera access.
2. `CameraCaptureService` initializes the selected camera.
3. A frame is captured for analysis.
4. OCR or image analysis runs on the captured frame.
5. Camera resources are disposed when no longer needed.

## Platform Support

| Feature | Linux | Windows | Web |
| --- | --- | --- | --- |
| Full screenshot | Desktop-supported | Desktop-supported | Not supported |
| Region capture | Desktop-supported | Desktop-supported | Not supported |
| Camera input | Supported with camera permissions | Supported with camera permissions | Browser-mediated |
| OCR | Depends on native OCR availability | Depends on native OCR availability | Limited |
| Continuous monitoring | Planned | Planned | Not supported |

## Privacy And Safety

- Camera access must be explicit and visible to the user.
- Continuous monitoring must remain opt-in when implemented.
- Screenshots and camera frames should stay local unless the user routes them to a configured provider.
- Temporary image artifacts should be cleaned up when workflows finish.
- Sensitive-content handling should be implemented before adding background monitoring.

## Planned Work

- Continuous screen monitoring service with explicit user consent.
- Dedicated privacy indicators for capture, camera, and monitoring state.
- Consistent retention controls for temporary captures.
- Richer OCR confidence and bounding-box UI.

## Related Documentation

- [System Architecture](SYSTEM_ARCHITECTURE.md)
- [Desktop Control](DESKTOP_CONTROL.md)
- [Implementation Plan](../development/IMPLEMENTATION_PLAN.md)
- [Product Specification](../../SPEC.md)
