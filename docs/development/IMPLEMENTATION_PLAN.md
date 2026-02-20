# Implementation Plan - OpenClaw Agent Manager

**CloudToLocalLLM** is an OpenClaw Agent Manager — a privacy-first desktop AI companion organized around five core pillars.

> **Last Updated**: 2026-02-20 | **Overall Progress**: ~50% complete | **Estimated Timeline**: 8 weeks

---

## Quick Reference: Pillar Status

| Pillar | Status | Progress | Next Step |
|--------|--------|----------|-----------|
| **Setup Wizard** | ✅ Complete | 100% | None |
| **Chat** | ✅ Phase 1 Complete | 85% | Multi-model attachments |
| **OpenClaw Manager** | ✅ Phase 1 Complete | 85% | Advanced metrics |
| **Evolving Avatar** | 🔲 Basic | 20% | Personality engine |
| **Desktop Control** | 🟡 Partial | 40% | Window management |
| **Vision** | 🟡 Partial | 30% | Region capture + OCR |

---

## Implementation Phases Overview

| Phase | Focus | Duration | Status | Key Deliverables |
|-------|-------|----------|--------|------------------|
| **Phase 0** | Setup Wizard | Week 1 | ✅ Complete | Onboarding flow, provider detection |
| **Phase 1** | Foundation | Weeks 2-3 | ✅ Complete | Multi-model selector, gateway control, chat search |
| **Phase 2** | Core Features | Weeks 4-6 | 🔲 Pending | Avatar personality/evolution, clipboard, file ops |
| **Phase 3** | Advanced | Weeks 7-8 | 🔲 Pending | Camera/OCR, avatar memory, achievements, macros |

---

## Phase 0: Setup Wizard (CRITICAL PATH) ✅ COMPLETE

> **Must be completed before any other phase** - Users cannot use the app without completing setup

### Goal

Guide new users through OpenClaw Gateway configuration with support for:
- **Local**: OpenClaw running on localhost:18789
- **Remote/Tailscale**: OpenClaw on VPS via tailnet IP
- **Custom**: SSH tunnels, VPNs, or custom URLs

### Success Criteria ✅

- ✅ New users complete setup in <3 minutes
- ✅ OpenClaw Gateway required (no partial setups)
- ✅ Database-backed configuration persistence

### Implementation Tasks

| Task | File(s) | Status |
|------|---------|--------|
| Build wizard flow container | `lib/screens/onboarding/setup_wizard_screen.dart` | ✅ Complete |
| Connection method selector | `lib/screens/onboarding/steps/connection_method_step.dart` | ✅ Complete |
| Local provider detection | `lib/services/provider_discovery_service.dart` | ✅ Complete |
| Tailscale device discovery | `provider_discovery_service.dart` (integrated) | ✅ Complete |
| Remote URL configuration | `lib/screens/onboarding/steps/remote_connection_step.dart` | ✅ Complete |
| Connection testing | `lib/screens/onboarding/steps/connection_test_step.dart` | ✅ Complete |
| Config persistence | `lib/services/provider_configuration_manager.dart` | ✅ Complete |
| First-run completion tracking | `lib/config/router.dart` (_HomeWithSetupCheck) | ✅ Complete |
| ProviderInfo/ProviderConfigurationManager fix | Database schema v5, raw SQL DAO | ✅ Complete |

**Total Time**: ~19 hours | **Completed**: 2026-02-20

### Files to Create

```
lib/screens/onboarding/
├── setup_wizard_screen.dart
├── steps/
│   ├── welcome_step.dart
│   ├── connection_method_step.dart
│   ├── local_detection_step.dart
│   ├── tailscale_discovery_step.dart
│   ├── remote_connection_step.dart
│   ├── connection_test_step.dart
│   ├── provider_download_step.dart
│   └── completion_step.dart
└── widgets/
    ├── connection_method_card.dart
    ├── tailscale_device_list.dart
    └── connection_status_indicator.dart

lib/services/onboarding/
├── tailscale_detection_service.dart
├── setup_wizard_service.dart
└── connection_test_service.dart
```

---

## Phase 1: Foundation (Chat + OpenClaw Manager) ✅ COMPLETE

### Prerequisites ✅

1. ✅ Complete Phase 0 (Setup Wizard)
2. ✅ Services reviewed and verified
3. ✅ Dev environment ready: Flutter SDK >= 3.5.0, Node.js >= 22.0.0

### Implementation Tasks

| Task | File(s) | Status |
|------|---------|--------|
| Extract multi-model selector widget | `lib/widgets/chat/model_selector.dart` | ✅ Complete |
| Add gateway auto-restart on crash | `lib/services/openclaw_manager/gateway_control_service.dart` | ✅ Complete |
| Add chat message search UI | `lib/components/conversation_list.dart` | ✅ Complete |
| Enhance rich message rendering | `lib/components/message_content.dart` | ✅ Complete |

**Total Time**: ~15 hours | **Completed**: 2026-02-20

### Phase 1 Summary

All Phase 1 tasks were already implemented in the codebase:

1. **Multi-Model Selector Widget** (`lib/widgets/chat/model_selector.dart`)
   - Reusable dropdown widget for model selection
   - Icon integration with refresh button
   - Handles empty model list state

2. **Gateway Auto-Restart** (`gateway_control_service.dart`)
   - Health check loop every 30 seconds
   - Auto-restart on crash with exponential backoff
   - Max 5 retry attempts before disabling
   - Toggle for auto-restart feature

3. **Chat Message Search** (`conversation_list.dart`)
   - Search in conversation titles
   - Search within message content
   - Real-time filtering as user types
   - Collapsible search UI

4. **Rich Message Rendering** (`message_content.dart`)
   - Markdown support with `flutter_markdown`
   - Code block detection with ```
   - Syntax highlighting for code blocks
   - Reasoning/thinking display
   - Proper styling and theming

### Step 1.1: Extract Multi-Model Selector Widget

**Current State**: Multi-model selector exists inline in `_ChatHeader` widget

**Goal**: Extract to reusable widget

```dart
// lib/widgets/chat/model_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ModelSelector extends StatelessWidget {
  final String selectedModel;
  final Function(String) onModelChanged;

  const ModelSelector({
    Key? key,
    required this.selectedModel,
    required this.onModelChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedModel,
      items: [
        DropdownMenuItem(value: 'glm-4', child: Text('GLM-4')),
        DropdownMenuItem(value: 'qwen', child: Text('Qwen')),
        DropdownMenuItem(value: 'custom', child: Text('Custom')),
      ],
      onChanged: (value) => onModelChanged(value!),
    );
  }
}
```

### Step 1.2: Add Gateway Auto-Restart on Crash

**Goal**: Automatically restart gateway on crash detection

```dart
// Add to gateway_control_service.dart
Future<void> _healthCheckLoop() async {
  while (!_disposed) {
    await Future.delayed(Duration(seconds: 30));
    final isRunning = await isGatewayRunning();
    if (!isRunning && _autoRestartEnabled) {
      await startGateway();
    }
  }
}
```

### Step 1.3: Add Chat Message Search UI

**Goal**: Add search UI to conversation list

```dart
class ConversationSearch extends StatefulWidget {
  @override
  _ConversationSearchState createState() => _ConversationSearchState();
}

class _ConversationSearchState extends State<ConversationSearch> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final service = GetIt.I<ConversationStorageService>();
    final results = await service.searchMessages(query);
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: 'Search conversations...'),
          onChanged: _performSearch,
        ),
        Expanded(child: ListView.builder(
          itemCount: _results.length,
          itemBuilder: (context, index) => SearchResultTile(result: _results[index]),
        )),
      ],
    );
  }
}
```

### Step 1.4: Enhance Rich Message Rendering

**Goal**: Add support for code blocks, images, and formatting

```dart
// lib/widgets/message_bubble.dart
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    final hasCodeBlock = content.contains('```');

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser ? Colors.blue[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: hasCodeBlock
          ? MarkdownBody(data: content)
          : Text(content),
    );
  }
}
```

---

## Phase 2: Core Features (Avatar + Desktop)

### Prerequisites

1. Complete Phase 1
2. Add dependencies to `pubspec.yaml`:
   - `rive: ^0.13.0`
   - `lottie: ^3.1.0`
   - `flutter_clipboard_listener: ^0.1.0`
   - `file_selector: ^1.0.0`

### Database Schema Migration (v3 → v4)

**Priority**: P0 | **Time**: 4 hours

```dart
// Avatar tables
@DataClassName('AvatarProfile')
class AvatarProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get xpToNextLevel => integer().withDefault(const Constant(100))();
  JsonColumn get traits => json()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastInteraction => dateTime()();
}

@DataClassName('Achievement')
class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get achievementId => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get icon => text()();
  IntColumn get xpReward => integer()();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
}

@DataClassName('AvatarMemory')
class AvatarMemoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  RealColumn get embedding => real()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get tags => text()();
}

// Desktop control tables
@DataClassName('ClipboardEntry')
class ClipboardHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get type => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get source => text()();
}

@DataClassName('ActionHistory')
class ActionHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();
  TextColumn get parameters => text()();
  TextColumn get result => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text()();
}

@DataClassName('Macro')
class Macros extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get steps => text()();
  IntColumn get repeatCount => integer().withDefault(const Constant(1))();
  IntColumn get delayBetweenSteps => integer().withDefault(const Constant(1000))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastRun => dateTime().nullable()();
}
```

### Implementation Tasks

| Task | File(s) | Time | Priority |
|------|---------|------|----------|
| Database schema migration | `lib/database/drift_local_brain.dart` | 4h | P0 |
| Implement personality engine | `lib/services/avatar/personality_engine.dart` | 6h | P1 |
| Implement evolution tracker | `lib/services/avatar/evolution_tracker.dart` | 5h | P1 |
| Implement clipboard service | `lib/services/desktop_control/clipboard_service.dart` | 4h | P1 |
| Implement file operations UI | `lib/screens/desktop/file_operations_screen.dart` | 5h | P1 |
| Implement action history service | `lib/services/desktop_control/action_history_service.dart` | 3h | P2 |

**Total Time**: ~27 hours

### Step 2.1: Implement Personality Engine

**Goal**: Create personality trait management system

```dart
class PersonalityTraits {
  final double friendliness;    // 0-1: cold to warm
  final double curiosity;       // 0-1: conservative to curious
  final double humor;           // 0-1: serious to playful
  final double formality;       // 0-1: casual to formal
  final double empathy;         // 0-1: detached to caring

  const PersonalityTraits({
    this.friendliness = 0.7,
    this.curiosity = 0.6,
    this.humor = 0.5,
    this.formality = 0.4,
    this.empathy = 0.8,
  });

  String adjustResponseTone(String response) {
    if (formality > 0.7) return _formalizeResponse(response);
    if (humor > 0.7) return _addHumor(response);
    return response;
  }
}

class PersonalityEngine with ChangeNotifier {
  final LocalBrain _db;
  PersonalityTraits _traits = PersonalityTraits();
  AvatarProfile? _profile;

  Future<void> initialize() async {
    final profiles = await _db.getAllAvatarProfiles();
    if (profiles.isEmpty) {
      await _createDefaultProfile();
    } else {
      _profile = profiles.first;
      _traits = PersonalityTraits.fromJson(_profile!.traits);
    }
    notifyListeners();
  }

  AvatarState getStateForContext(String context) {
    if (context.contains('error')) return AvatarState.error;
    if (context.contains('working')) return AvatarState.working;
    if (context.contains('thinking')) return AvatarState.thinking;
    if (_traits.humor > 0.8) return AvatarState.happy;
    return AvatarState.idle;
  }
}
```

### Step 2.2: Implement Evolution Tracker

**Goal**: Create XP, level, and achievement tracking

```dart
class EvolutionTracker with ChangeNotifier {
  final LocalBrain _db;
  final PersonalityEngine _personality;
  AvatarProfile? _profile;
  List<Achievement> _unlockedAchievements = [];

  static final List<Achievement> _allAchievements = [
    Achievement(achievementId: 'first_conversation', name: 'First Words', icon: '💬', xpReward: 50),
    Achievement(achievementId: 'social_butterfly', name: 'Social Butterfly', icon: '🦋', xpReward: 200),
    Achievement(achievementId: 'night_owl', name: 'Night Owl', icon: '🦉', xpReward: 100),
  ];

  Future<void> awardXP(int amount, String reason) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(xp: _profile!.xp + amount);

    while (_profile!.xp >= _profile!.xpToNextLevel) {
      _profile = _profile!.copyWith(
        level: _profile!.level + 1,
        xp: _profile!.xp - _profile!.xpToNextLevel,
        xpToNextLevel: (_profile!.xpToNextLevel * 1.5).toInt(),
      );
    }
    await _db.updateAvatarProfile(_profile!);
    notifyListeners();
  }

  Future<void> unlockAchievement(String achievementId) async {
    final achievement = _allAchievements.firstWhere((a) => a.achievementId == achievementId);
    await _db.insertAchievement(AchievementsCompanion.insert(
      achievementId: achievementId,
      name: achievement.name,
      icon: achievement.icon,
      xpReward: achievement.xpReward,
      unlockedAt: DateTime.now(),
    ));
    await awardXP(achievement.xpReward, 'Achievement: ${achievement.name}');
  }
}
```

---

## Phase 3: Advanced (Vision + Avatar)

### Prerequisites

1. Complete Phase 2
2. Add dependencies:
   - `camera: ^0.10.5`
   - `tesseract_ocr: ^0.4.0`
   - `vector_math: ^2.1.4`

### Implementation Tasks

| Task | File(s) | Time | Priority |
|------|---------|------|----------|
| Implement avatar memory system | `lib/services/avatar/memory_service.dart` | 8h | P1 |
| Avatar customization UI | `lib/screens/avatar/avatar_customization_screen.dart` | 5h | P2 |
| Achievement system UI | `lib/screens/avatar/achievements_screen.dart` | 4h | P2 |
| Region capture service | `lib/services/vision/region_capture.dart` | 5h | P1 |
| Camera input service | `lib/services/vision/camera_capture.dart` | 4h | P1 |
| OCR engine | `lib/services/vision/ocr_engine.dart` | 6h | P1 |
| Continuous screen monitor | `lib/services/vision/screen_monitor.dart` | 5h | P2 |
| Macro service | `lib/services/desktop_control/macro_service.dart` | 6h | P2 |

**Total Time**: ~43 hours

### Step 3.1: Implement Avatar Memory System

**Goal**: Create conversation embedding system for personalized responses

```dart
class MemoryService {
  final LocalBrain _db;

  Future<void> storeMemory({
    required String content,
    required List<String> tags,
  }) async {
    final embedding = await _generateEmbedding(content);
    await _db.insertAvatarMemoryEntry(AvatarMemoryEntriesCompanion.insert(
      content: content,
      embedding: embedding,
      tags: tags.join(','),
    ));
  }

  Future<List<AvatarMemoryEntry>> retrieveMemories(String query, {int limit = 5}) async {
    final queryEmbedding = await _generateEmbedding(query);
    final queryVector = jsonDecode(queryEmbedding) as List<double>;
    final allMemories = await _db.getAllAvatarMemoryEntries();

    final scored = allMemories.map((memory) {
      final memoryVector = jsonDecode(memory.embedding) as List<double>;
      final score = _cosineSimilarity(queryVector, memoryVector);
      return MapEntry(memory, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
```

### Step 3.2: Implement OCR Engine

**Goal**: Extract text from images

```dart
import 'package:tesseract_ocr/tesseract_ocr.dart';

class OcrEngine {
  Future<String> extractText(Uint8List imageData) async {
    try {
      final text = await TesseractOcr.extractText(
        imageData,
        language: 'eng',
        args: ['--psm', '6'],
      );
      return text;
    } catch (e) {
      return '';
    }
  }
}
```

---

## Final Steps

### Update DI Locator

**File**: `lib/di/locator.dart`

```dart
// Setup wizard services
locator.registerLazySingleton<TailscaleDetectionService>(() => TailscaleDetectionService());
locator.registerLazySingleton<SetupWizardService>(() => SetupWizardService(locator<ProviderConfigurationManager>()));

// Avatar services
locator.registerLazySingleton<MemoryService>(() => MemoryService(locator<LocalBrain>()));
locator.registerLazySingleton<PersonalityEngine>(() => PersonalityEngine(locator<LocalBrain>()));
locator.registerLazySingleton<EvolutionTracker>(() => EvolutionTracker(locator<LocalBrain>(), locator<PersonalityEngine>()));

// Desktop control services
locator.registerLazySingleton<ClipboardService>(() => ClipboardService(locator<LocalBrain>()));
locator.registerLazySingleton<ActionHistoryService>(() => ActionHistoryService(locator<LocalBrain>()));
locator.registerLazySingleton<MacroService>(() => MacroService(locator<LocalBrain>(), locator<GuiAutomationService>()));

// Vision services
locator.registerLazySingleton<RegionCaptureService>(() => RegionCaptureService(locator<SystemControlService>()));
locator.registerLazySingleton<CameraCaptureService>(() => CameraCaptureService());
locator.registerLazySingleton<OcrEngine>(() => OcrEngine());
locator.registerLazySingleton<ScreenMonitorService>(() => ScreenMonitorService(locator<RegionCaptureService>(), locator<OcrEngine>()));
```

### Testing

```bash
# Flutter tests
flutter test
flutter analyze
flutter format .

# Backend tests
cd services/api-backend
npm run test

# E2E tests
flutter test integration_test/
```

---

## Risk Mitigation

| Risk | Priority | Mitigation |
|------|----------|------------|
| Setup wizard failure | P0 | Extensive testing, clear error messages |
| OpenClaw API changes | P0 | Version pinning, API abstraction |
| Database migration | P1 | Backup before migration, rollback path |
| Platform-specific features | P1 | Feature detection, graceful degradation |
| Performance (monitoring + OCR) | P2 | Rate limiting, user controls |
| Privacy (screen/camera) | P2 | Explicit opt-in, clear indicators |

---

## Key Files to Modify

| Phase | Modify | Create |
|-------|--------|--------|
| Setup | `lib/di/locator.dart`, `lib/main_privacy_enhanced.dart`, `lib/config/router.dart` | Wizard screens + services |
| Chat | `streaming_chat_service.dart`, `home_layout.dart` | `model_selector.dart` |
| OpenClaw | `connection_manager_service.dart`, `dashboard_screen.dart` | `gateway_control_service.dart` |
| Avatar | `avatar_widget.dart` | Personality, evolution, memory services |
| Desktop | `gui_automation_service.dart`, `system_control_service.dart` | `clipboard_service.dart` |
| Vision | `gui_automation_service.dart` | `camera_capture.dart`, `ocr_engine.dart` |

---

## Success Criteria

### Phase 0 (Setup Wizard)
- ✅ New users complete setup in <3 minutes
- ✅ OpenClaw Gateway required and verified
- ✅ Local, Tailscale, and custom options work

### Phase 1 (Foundation)
- ✅ Multi-model selector widget extracted
- ✅ Gateway auto-restart working
- ✅ Chat search UI functional
- ✅ Rich message rendering with markdown

### Phase 2 (Core Features)
- ✅ Database migrated to v4
- ✅ Avatar personality engine with trait adjustments
- ✅ Evolution tracker with XP, levels, achievements
- ✅ Clipboard service with history
- ✅ File operations UI

### Phase 3 (Advanced)
- ✅ Avatar memory system with embeddings
- ✅ Avatar customization UI
- ✅ Achievement display
- ✅ Region capture, camera input, OCR
- ✅ Macro creation and execution

---

## Dependencies

### New Dependencies Required

```yaml
dependencies:
  # Avatar animations
  rive: ^0.13.0
  lottie: ^3.1.0

  # Desktop control
  flutter_clipboard_listener: ^0.1.0
  file_selector: ^1.0.0

  # Vision
  camera: ^0.10.5
  tesseract_ocr: ^0.4.0

  # Rich messages
  flutter_markdown: ^0.6.0
  flutter_highlight: ^0.7.0
  cached_network_image: ^3.3.0

  # Embeddings
  vector_math: ^2.1.4
```

---

## Reference

- **SPEC.md**: Master specification
- **README.md**: User-facing overview
- **SYSTEM_ARCHITECTURE.md**: Technical deep dive
- **CLAUDE.md**: Development guidelines
