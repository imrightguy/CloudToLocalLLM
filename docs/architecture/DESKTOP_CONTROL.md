# Desktop Control Architecture

Pillar 4, Desktop Control, lets CloudToLocalLLM inspect and operate the local desktop through explicit services and user-controlled actions.

## Current Status

Core desktop control services are implemented. The system includes GUI automation, shell/system control, clipboard history, window management, and a file operations screen. Macro recording and a standalone action-history service are not currently present.

## Current Components

| Component | Status | File |
| --- | --- | --- |
| GUI automation | Implemented | `lib/services/gui_automation_service.dart` |
| System control | Implemented | `lib/services/system_control_service.dart` |
| Clipboard service | Implemented | `lib/services/desktop_control/clipboard_service.dart` |
| Desktop window manager | Implemented | `lib/services/desktop_control/window_manager_service.dart` |
| App window manager wrapper | Implemented | `lib/services/window_manager_service.dart` |
| File operations UI | Implemented | `lib/screens/desktop/file_operations_screen.dart` |
| GUI automation UI | Implemented | `lib/screens/gui_automation_screen.dart` |
| Macro service | Planned | Not present |
| Standalone action-history service | Planned | Not present |

## Service Responsibilities

### `GuiAutomationService`

Handles screenshot-based GUI automation workflows. It coordinates capture, analysis, and user-approved actions such as clicking, typing, and key presses.

### `SystemControlService`

Handles local command execution, system stats, notifications, process/file operations, and native screenshot calls where supported.

### `ClipboardService`

Handles clipboard copy/read operations and optional polling-based history on desktop platforms. Web monitoring is intentionally limited by browser security rules.

### `WindowManagerService`

There are two window-manager-related services:

- `lib/services/window_manager_service.dart` handles app-window behavior.
- `lib/services/desktop_control/window_manager_service.dart` handles desktop-control window operations.

Check imports before editing to avoid mixing these responsibilities.

## Data Flow

Typical GUI automation flow:

1. User requests a desktop action.
2. The app captures a screenshot or region.
3. The image is analyzed locally or through the configured local provider path.
4. The UI presents the proposed action.
5. User approval gates risky operations.
6. The relevant service performs the action and updates state.

## Platform Support

| Feature | Linux | Windows | Web |
| --- | --- | --- | --- |
| Shell commands | Full | Full | Not supported |
| Screenshot | Supported where native APIs are available | Supported where native APIs are available | Not supported |
| Window management | Desktop-only | Desktop-only | Not supported |
| File operations | Full | Full | Browser-limited |
| Clipboard | Full with optional monitoring | Full with optional monitoring | Limited |
| Notifications | Desktop notifications | Desktop notifications | Browser-limited |

## Privacy And Safety

- Desktop actions are local-first and should stay user-visible.
- Clipboard monitoring is optional and should not be enabled silently.
- Destructive file or shell actions should require clear user intent.
- Shared Flutter code must not import `dart:io` directly; use platform helpers or conditional imports.

## Planned Work

- Central action audit/history service if product requirements need persistent action review.
- Macro recording and replay.
- Stronger permission prompts for destructive desktop actions.
- Clearer visual indicators while automation is active.

## Related Documentation

- [System Architecture](SYSTEM_ARCHITECTURE.md)
- [Vision System](VISION_SYSTEM.md)
- [Implementation Plan](../development/IMPLEMENTATION_PLAN.md)
- [Product Specification](../../SPEC.md)
