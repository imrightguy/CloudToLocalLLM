# Desktop Control Architecture

**Pillar 4: Desktop Control** — GUI automation and system integration for hands-free computer control.

---

## Overview

The Desktop Control system enables the AI assistant to interact with your computer through GUI automation, file operations, command execution, and clipboard management. Powered by vision-language models, the system can see your screen, understand UI elements, and execute actions.

**Current Status**: Screenshot capture, vision analysis, command execution working (40% complete)

**Planned Features**: Window management, clipboard service, file operations UI, action history, macro system

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Desktop Control System                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      UI Layer                               │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         GuiAutomationScreen                          │ │ │
│  │  │  - Screenshot capture button                          │ │ │
│  │  │  - Vision analysis display                            │ │ │
│  │  │  - Action controls (click, type, execute)            │ │ │
│  │  │  - Region selector                                   │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         FileOperationsScreen                         │ │ │
│  │  │  - Directory browser                                 │ │ │
│  │  │  - File open/save dialogs                            │ │ │
│  │  │  - Path navigation                                   │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         ClipboardHistoryWidget                       │ │ │
│  │  │  - Recent clipboard entries                          │ │ │
│  │  │  - Search functionality                              │ │ │
│  │  │  - Copy/paste actions                                │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                     Service Layer                           │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │           GuiAutomationService                        │ │ │
│  │  │  - takeScreenshot()                                   │ │ │
│  │  │  - analyzeScreenshot(imagePath)                       │ │ │
│  │  │  - clickAt(x, y)                                      │ │
│  │  │  - typeText(text)                                    │ │ │
│  │  │  - pressKey(key)                                     │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │           SystemControlService                        │ │ │
│  │  │  - executeCommand(command)                           │ │ │
│  │  │  - getSystemStats()                                  │ │ │
│  │  │  - captureScreenshot()                               │ │ │
│  │  │  - showNotification(title, body)                     │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │           ClipboardService                            │ │ │
│  │  │  - copy(content)                                     │ │ │
│  │  │  - getClipboardContent()                             │ │ │
│  │  │  - startMonitoring() / stopMonitoring()              │ │ │
│  │  │  - searchHistory(query)                              │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │           ActionHistoryService                       │ │ │
│  │  │  - logAction(action, parameters, result, status)      │ │ │
│  │  │  - getRecentActions(limit)                           │ │ │
│  │  │  - getStatistics()                                   │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │           MacroService                                │ │ │
│  │  │  - createMacro(name, steps, repeat, delay)           │ │ │
│  │  │  - executeMacro(macroId)                             │ │ │
│  │  │  - recordMacro() / stopRecording()                   │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Vision Integration                       │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         OpenClaw Gateway (localhost:18789)           │ │ │
│  │  │  - Vision model for screenshot analysis              │ │ │
│  │  │  - UI element detection                              │ │ │
│  │  │  - OCR for text extraction                           │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                 Native Platform Layer                     │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │ │
│  │  │ Linux/Win API│  │Shell Commands│  │File System API │  │ │
│  │  │- Window mgmt │  │- Process exec │  │- Read/Write    │  │ │
│  │  │- Input sim   │  │- Stats query  │  │- Permissions   │  │ │
│  │  └──────────────┘  └──────────────┘  └────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  Data Layer (Drift)                         │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐ │ │
│  │  │ ClipboardHistory│  │ActionHistoryEntry│  │   Macros   │ │ │
│  │  └─────────────────┘  └─────────────────┘  └────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. GUI Automation Service

**File**: `lib/services/gui_automation_service.dart`

**Current Implementation**: Screenshot capture and vision analysis via OpenClaw Gateway

**Key Features**:
```dart
class GuiAutomationService extends ChangeNotifier {
  // Take screenshot of current screen
  Future<String?> takeScreenshot();

  // Analyze screenshot with vision model
  Future<String> analyzeScreenshot(String imagePath);

  // Perform click action at coordinates
  Future<ActionResult> clickAt(int x, int y);

  // Type text at current cursor location
  Future<ActionResult> typeText(String text);

  // Press keyboard key
  Future<ActionResult> pressKey(String key);

  // Execute a sequence of actions
  Future<List<ActionResult>> executeActions(List<Action> actions);
}
```

**Vision Integration**:
1. Screenshot captured via native platform API
2. Image encoded as base64
3. Sent to OpenClaw Gateway with analysis prompt
4. Response includes:
   - Detected applications and UI elements
   - Suggested actions
   - Coordinates for click targets

---

### 2. System Control Service

**File**: `lib/services/system_control_service.dart`

**Current Implementation**: Shell command execution, system stats, notifications

**Key Features**:
```dart
class SystemControlService {
  // Execute shell command
  Future<String?> executeCommand(String command);

  // Get system resource usage
  Future<Map<String, String>> getSystemStats();

  // Show system notification
  Future<void> showNotification(String title, String body);

  // Capture screenshot (native method)
  Future<String?> captureScreenshot();

  // Get running processes
  Future<List<ProcessInfo>> getRunningProcesses();

  // Open application/file
  Future<void> open(String path);

  // List files in directory
  Future<List<File>> listDirectory(String path);
}
```

**Platform Support**:
- **Linux**: Full shell command support
- **Windows**: CMD/PowerShell commands (via Windows-specific implementations)
- **Web**: Limited to browser-based operations only

---

### 3. Clipboard Service

**File**: `lib/services/desktop_control/clipboard_service.dart` (🔲 To Create)

**Purpose**: Monitor clipboard changes and maintain searchable history

**Key Features**:
```dart
class ClipboardService with ChangeNotifier {
  // Copy text to clipboard
  Future<void> copy(String content);

  // Get current clipboard content
  Future<String?> getClipboardContent();

  // Start monitoring clipboard changes
  Future<void> startMonitoring();

  // Stop monitoring
  Future<void> stopMonitoring();

  // Search clipboard history
  Future<List<ClipboardEntry>> searchHistory(String query);

  // Clear history
  Future<void> clearHistory();
}
```

**Storage**: Last 100 clipboard entries in local database

**Privacy**: Monitoring disabled by default, requires user opt-in

---

### 4. Action History Service

**File**: `lib/services/desktop_control/action_history_service.dart` (🔲 To Create)

**Purpose**: Audit trail of all desktop automation actions

**Key Features**:
```dart
class ActionHistoryService {
  // Log action execution
  Future<void> logAction({
    required String action,
    required Map<String, dynamic> parameters,
    required String result,
    required ActionStatus status,
  });

  // Get recent actions
  Future<List<ActionHistoryEntry>> getRecentActions({int limit = 50});

  // Search actions
  Future<List<ActionHistoryEntry>> searchActions(String query);

  // Get statistics
  Future<Map<String, int>> getStatistics();

  // Clear history
  Future<void> clearHistory();
}
```

**Status Types**: `success`, `error`, `pending`

**Statistics**:
- Total actions executed
- Success/failure rate
- Most used actions
- Actions by type (click, type, command)

---

### 5. Macro Service

**File**: `lib/services/desktop_control/macro_service.dart` (🔲 To Create)

**Purpose**: Record and execute complex automation sequences

**Key Features**:
```dart
class MacroService with ChangeNotifier {
  // Create macro
  Future<void> createMacro({
    required String name,
    required String description,
    required List<MacroStep> steps,
    int repeatCount = 1,
    int delayBetweenSteps = 1000,
  });

  // Execute macro
  Future<MacroExecutionResult> executeMacro(int macroId);

  // Record macro (capture user actions)
  Future<void> startRecording();
  Future<void> stopRecording();

  // Get all macros
  Future<List<Macro>> getAllMacros();

  // Delete macro
  Future<void> deleteMacro(int macroId);
}
```

**Macro Step Types**:
```dart
enum MacroStepType {
  click,      // Click at (x, y)
  type,       // Type text
  wait,       // Wait N milliseconds
  screenshot, // Take screenshot
  keyPress,   // Press key
  command,    // Execute shell command
}
```

**Example Macro**:
```json
{
  "name": "Open Browser and Navigate",
  "description": "Opens Firefox and navigates to GitHub",
  "steps": [
    {"type": "command", "command": "firefox"},
    {"type": "wait", "delay": 2000},
    {"type": "type", "text": "github.com"},
    {"type": "keyPress", "key": "Enter"}
  ]
}
```

---

## Data Flow

### GUI Automation Flow

```
User requests action
        ↓
GuiAutomationService.takeScreenshot()
        ↓
Image saved to temp file
        ↓
analyzeScreenshot(imagePath)
        ↓
Send to OpenClaw Gateway (base64)
        ↓
Vision model analysis
        ↓
Response: UI elements, coordinates, suggestions
        ↓
User confirms action
        ↓
Execute action (click/type/press)
        ↓
ActionHistoryService.logAction()
```

### Macro Execution Flow

```
User selects macro
        ↓
MacroService.executeMacro(macroId)
        ↓
Load macro steps from database
        ↓
For each repeat:
  For each step:
    Execute step (click/type/wait/command)
    Log result
    If error: break
    Delay between steps
        ↓
Update macro lastRun timestamp
        ↓
Return execution result
```

---

## Database Schema

```dart
// Clipboard history (last 100 entries)
@DataClassName('ClipboardEntry')
class ClipboardHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get type => text();  // text, image, url
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get source => text()();  // app/source identifier
}

// Action audit trail
@DataClassName('ActionHistory')
class ActionHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();  // click, type, command, etc.
  TextColumn get parameters => text()();  // JSON
  TextColumn get result => text()();  // JSON
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text()();  // success, error, pending
}

// Recorded macros
@DataClassName('Macro')
class Macros extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get steps => text()();  // JSON array of MacroStep
  IntColumn get repeatCount => integer().withDefault(const Constant(1))();
  IntColumn get delayBetweenSteps => integer().withDefault(const Constant(1000))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastRun => dateTime().nullable()();
}
```

---

## Privacy & Security

**Local Execution**:
- All automation runs locally via native platform APIs
- No cloud services involved in action execution

**User Consent**:
- Explicit opt-in for clipboard monitoring
- Visual indicator when automation is active
- Clear confirmation before destructive actions

**Audit Trail**:
- All actions logged locally
- User can review full history
- Statistics available for transparency

**Sandboxing** (Planned):
- Restrict macros to safe directories
- Warn before system-wide actions
- Password confirmation for sensitive operations

---

## Platform Considerations

| Feature | Linux | Windows | Web |
|---------|-------|---------|-----|
| Shell commands | ✅ Full | ✅ Full (CMD/PS) | ❌ None |
| Screenshot | ✅ Full | ✅ Full | ❌ None |
| Window management | ✅ Via WM | ✅ Via Win32 API | ❌ None |
| File operations | ✅ Full | ✅ Full | ⚠️ Browser FS only |
| Clipboard | ✅ Full | ✅ Full | ⚠️ Limited |
| Notifications | ✅ Full | ✅ Full | ⚠️ Browser only |

---

## Dependencies

```yaml
dependencies:
  # Shell command execution
  process_run: ^0.12.0

  # Device info
  device_info_plus: ^9.0.0

  # Local notifications
  local_notifier: ^0.1.0

  # File operations (planned)
  file_selector: ^1.0.0

  # Clipboard monitoring (planned)
  flutter_clipboard_listener: ^0.1.0

  # Window management (planned)
  window_manager: ^0.3.0
```

---

## Implementation Status

| Component | Status | File |
|-----------|--------|------|
| Screenshot capture | ✅ Working | `lib/services/system_control_service.dart` |
| Vision analysis | ✅ Working | `lib/services/gui_automation_service.dart` |
| Command execution | ✅ Working | `lib/services/system_control_service.dart` |
| System stats | ✅ Working | `lib/services/system_control_service.dart` |
| Notifications | ✅ Working | `lib/services/system_control_service.dart` |
| GUI automation UI | ✅ Working | `lib/screens/gui_automation_screen.dart` |
| Clipboard service | 🔲 To Create | `lib/services/desktop_control/clipboard_service.dart` |
| Action history | 🔲 To Create | `lib/services/desktop_control/action_history_service.dart` |
| Macro service | 🔲 To Create | `lib/services/desktop_control/macro_service.dart` |
| File operations UI | 🔲 To Create | `lib/screens/desktop/file_operations_screen.dart` |
| Window management | 🔲 To Create | Platform-specific implementations |

---

## Related Documentation

- [Implementation Plan - Phase 2](../development/IMPLEMENTATION_PLAN.md#phase-2-core-features-avatar--desktop)
- [SPEC.md - Desktop Control](../SPEC.md#4-desktop-control)
- [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
- [Vision System](VISION_SYSTEM.md)
