# Avatar Personality Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a personality and evolution system for OpenClaw agents that grows organically through meaningful conversations, with shared state between OpenClaw Gateway and CloudToLocalLLM.

**Architecture:** Hybrid shared state where OpenClaw owns personality/evolution, CloudToLocalLLM provides expanded awareness. Drift database (VPS via Tailscale) as primary storage, markdown files in OpenClaw skills directory as backup/portable storage. Collaborative evolution: OpenClaw self-reflects and requests evolution, CloudToLocalLLM validates before approving.

**Tech Stack:** Flutter 3.5+, Drift (SQLite), TypeScript (OpenClaw skills), Rive animations, markdown backup sync.

**Design Document:** `docs/plans/2026-02-22-avatar-personality-engine-design.md`

**Implementation Time:** ~42 hours

---

## Prerequisites

1. Read the design document: `docs/plans/2026-02-22-avatar-personality-engine-design.md`
2. Read existing architecture: `docs/architecture/SYSTEM_ARCHITECTURE.md`
3. Review existing avatar widget: `lib/features/avatar/avatar_widget.dart`
4. Review database schema: `lib/database/drift_local_brain.dart`
5. Review service locator: `lib/di/locator.dart`

---

## Phase 1: Database Schema & Core Services

### Task 1.1: Add Avatar Tables to Drift Schema

**Files:**
- Modify: `lib/database/drift_local_brain.dart`

**Step 1: Add avatar tables to Drift schema**

Add these table definitions after the existing tables:

```dart
// Avatar personality state (OpenClaw-owned)
@DataClassName('AvatarProfile')
class AvatarProfiles extends Table {
  TextColumn get id => text().withDefault(Constant('default'))();
  TextColumn get agentName => text().withDefaultValue(Constant('Agent'))();
  TextColumn get personalityTraits => text()();  // JSON: {formality, humor, enthusiasm, empathy}
  TextColumn get evolutionStage => text().withDefaultValue(Constant('base'))();
  IntColumn get conversationCount => integer().withDefault(Constant(0))();
  RealColumn get depthScore => real().withDefault(Constant(0.0))();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Evolution history
@DataClassName('EvolutionHistory')
class EvolutionHistoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get avatarId => text().references(AvatarProfiles, #id)();
  TextColumn get fromStage => text()();
  TextColumn get toStage => text()();
  TextColumn get triggerReason => text()();  // 'conversation_depth', 'pattern_recognition', 'self_reflection'
  TextColumn get context => text().nullable()();  // What triggered it
  TextColumn get confirmedBy => text()();  // 'agent', 'app', 'collaborative'
  IntColumn get triggeredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// Conversation depth metrics (for evolution tracking)
@DataClassName('ConversationDepthMetric')
class ConversationDepthMetrics extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  RealColumn get complexityScore => real()();  // 0-1: topic diversity, length, reasoning
  RealColumn get emotionalDepth => real()();  // 0-1: empathy, personal sharing
  RealColumn get noveltyScore => real()();  // 0-1: new topics vs repeated
  IntColumn get timestamp => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 2: Add DAO methods for avatar tables**

Add these methods to the DriftLocalBrain class:

```dart
// Avatar profile operations
Future<AvatarProfile> getAvatarProfile() async {
  final profiles = await select(avatarProfiles).get();
  if (profiles.isEmpty) {
    // Create default profile
    final defaultProfile = AvatarProfile(
      id: 'default',
      agentName: 'Agent',
      personalityTraits: '{"formality":0.5,"humor":0.5,"enthusiasm":0.5,"empathy":0.5}',
      evolutionStage: 'base',
      conversationCount: 0,
      depthScore: 0.0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await into(avatarProfiles).insert(defaultProfile);
    return defaultProfile;
  }
  return profiles.first;
}

Future<void> updateAvatarTraits(Map<String, double> traits) async {
  final json = jsonEncode(traits);
  final now = DateTime.now().millisecondsSinceEpoch;
  await (update(avatarProfiles)..where((tbl) => tbl.id.equals('default')))
      .write(AvatarProfilesCompanion(
    personalityTraits: Value(json),
    updatedAt: Value(now),
  ));
}

Future<void> updateAgentName(String name) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await (update(avatarProfiles)..where((tbl) => tbl.id.equals('default')))
      .write(AvatarProfilesCompanion(
    agentName: Value(name),
    updatedAt: Value(now),
  ));
}

Future<void> updateEvolutionStage(String stage) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await (update(avatarProfiles)..where((tbl) => tbl.id.equals('default')))
      .write(AvatarProfilesCompanion(
    evolutionStage: Value(stage),
    updatedAt: Value(now),
  ));
}

// Evolution history operations
Future<void> recordEvolution({
  required String fromStage,
  required String toStage,
  required String triggerReason,
  required String context,
  required String confirmedBy,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await into(evolutionHistory).insert(EvolutionHistoryCompanion(
    id: Value(const Uuid().v4()),
    avatarId: const Value('default'),
    fromStage: Value(fromStage),
    toStage: Value(toStage),
    triggerReason: Value(triggerReason),
    context: Value(context),
    confirmedBy: Value(confirmedBy),
    triggeredAt: Value(now),
  ));
}

Future<List<EvolutionHistory>> getEvolutionHistory() async {
  return await (select(evolutionHistory)
        ..orderBy([(t) => OrderingTerm.desc(t.triggeredAt)]))
      .get();
}

// Depth metrics operations
Future<void> addConversationDepthMetrics(ConversationDepthMetricsCompanion metric) async {
  await into(conversationDepthMetrics).insert(metric);
}

Future<List<ConversationDepthMetric>> getDepthMetrics() async {
  return await (select(conversationDepthMetrics)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .limit(20)
      .get();
}

Future<List<ConversationDepthMetric>> getDepthMetricsForConversation(String conversationId) async {
  return await (select(conversationDepthMetrics)
        ..where((tbl) => tbl.conversationId.equals(conversationId)))
      .get();
}
```

**Step 3: Add missing imports**

Add these imports at the top of the file:

```dart
import 'dart:convert';
import 'package:uuid/uuid.dart';
```

**Step 4: Run flutter analyze to verify**

Run: `flutter analyze`
Expected: No errors, possibly warnings about unused imports (we'll use them in next tasks)

**Step 5: Commit**

```bash
git add lib/database/drift_local_brain.dart
git commit -m "feat: add avatar personality tables to Drift schema

- Add avatar_profiles table for personality traits and evolution stage
- Add evolution_history table for tracking stage transitions
- Add conversation_depth_metrics table for evolution triggers
- Add DAO methods for avatar operations
"
```

---

### Task 1.2: Create PersonalityEngine Service

**Files:**
- Create: `lib/services/avatar/personality_engine.dart`
- Test: `test/services/avatar/personality_engine_test.dart`

**Step 1: Create personality models**

Create `lib/models/avatar/personality_models.dart`:

```dart
import 'package:cloudtolocallm/database/database.dart';

class PersonalityTraits {
  final double formality;
  final double humor;
  final double enthusiasm;
  final double empathy;

  PersonalityTraits({
    required this.formality,
    required this.humor,
    required this.enthusiasm,
    required this.empathy,
  });

  Map<String, double> toMap() => {
    'formality': formality,
    'humor': humor,
    'enthusiasm': enthusiasm,
    'empathy': empathy,
  };

  factory PersonalityTraits.fromMap(Map<String, double> map) => PersonalityTraits(
    formality: map['formality'] ?? 0.5,
    humor: map['humor'] ?? 0.5,
    enthusiasm: map['enthusiasm'] ?? 0.5,
    empathy: map['empathy'] ?? 0.5,
  );

  String toJson() => toMap().toString();

  static PersonalityTraits get defaultTraits => PersonalityTraits(
    formality: 0.5,
    humor: 0.5,
    enthusiasm: 0.5,
    empathy: 0.5,
  );
}

class EvolutionDecision {
  final bool approved;
  final String? reason;
  final String? newStage;

  EvolutionDecision({
    required this.approved,
    this.reason,
    this.newStage,
  });
}

class ExtendedAvatarProfile {
  final String agentName;
  final PersonalityTraits traits;
  final String evolutionStage;
  final int conversationCount;
  final double depthScore;

  ExtendedAvatarProfile({
    required this.agentName,
    required this.traits,
    required this.evolutionStage,
    required this.conversationCount,
    required this.depthScore,
  });
}
```

**Step 2: Write the failing test**

Create `test/services/avatar/personality_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocallm/database/database.dart';
import 'package:cloudtolocallm/models/avatar/personality_models.dart';
import 'package:cloudtolocallm/services/avatar/personality_engine.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([DriftLocalBrain])
import 'personality_engine_test.mocks.dart';

void main() {
  late PersonalityEngine engine;
  late MockDriftLocalBrain mockDb;

  setUp(() {
    mockDb = MockDriftLocalBrain();
    engine = PersonalityEngine(database: mockDb, markdownPath: '/tmp/test');
  });

  group('PersonalityEngine', () {
    test('getPersonality returns current profile', () async {
      final mockProfile = AvatarProfile(
        id: 'default',
        agentName: 'TestBot',
        personalityTraits: '{"formality":0.7,"humor":0.4,"enthusiasm":0.8,"empathy":0.9}',
        evolutionStage: 'base',
        conversationCount: 10,
        depthScore: 0.5,
        createdAt: 1000,
        updatedAt: 2000,
      );

      when(mockDb.getAvatarProfile()).thenAnswer((_) async => mockProfile);

      final result = await engine.getPersonality();

      expect(result.agentName, equals('TestBot'));
      expect(result.traits.formality, equals(0.7));
      expect(result.traits.humor, equals(0.4));
      expect(result.traits.enthusiasm, equals(0.8));
      expect(result.traits.empathy, equals(0.9));
    });

    test('updatePersonality writes to database', () async {
      final traits = PersonalityTraits(
        formality: 0.8,
        humor: 0.3,
        enthusiasm: 0.7,
        empathy: 0.9,
      );

      when(mockDb.updateAvatarTraits(any)).thenAnswer((_) async {});

      await engine.updatePersonality(traits);

      verify(mockDb.updateAvatarTraits({
        'formality': 0.8,
        'humor': 0.3,
        'enthusiasm': 0.7,
        'empathy': 0.9,
      })).called(1);
    });

    test('validateEvolutionRequest approves with sufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
        ConversationDepthMetric(
          id: '1',
          conversationId: 'conv1',
          complexityScore: 0.8,
          emotionalDepth: 0.7,
          noveltyScore: 0.6,
          timestamp: 1000,
        ),
        ConversationDepthMetric(
          id: '2',
          conversationId: 'conv2',
          complexityScore: 0.75,
          emotionalDepth: 0.8,
          noveltyScore: 0.7,
          timestamp: 2000,
        ),
      ]);

      final result = await engine.validateEvolutionRequest(
        'stage1',
        'self_reflection',
      );

      expect(result.approved, isTrue);
      expect(result.newStage, equals('stage1'));
    });

    test('validateEvolutionRequest denies with insufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
        ConversationDepthMetric(
          id: '1',
          conversationId: 'conv1',
          complexityScore: 0.3,
          emotionalDepth: 0.2,
          noveltyScore: 0.3,
          timestamp: 1000,
        ),
      ]);

      final result = await engine.validateEvolutionRequest(
        'stage1',
        'self_reflection',
      );

      expect(result.approved, isFalse);
      expect(result.reason, contains('Insufficient conversation depth'));
    });
  });
}
```

**Step 3: Run test to verify it fails**

Run: `flutter test test/services/avatar/personality_engine_test.dart`
Expected: FAIL with "PersonalityEngine not implemented"

**Step 4: Write minimal implementation**

Create `lib/services/avatar/personality_engine.dart`:

```dart
import 'dart:io';
import 'dart:convert';
import 'package:cloudtolocallm/database/database.dart';
import 'package:cloudtolocallm/models/avatar/personality_models.dart';

class PersonalityEngine {
  final DriftLocalBrain _database;
  final String _markdownPath;

  PersonalityEngine({
    required DriftLocalBrain database,
    required String markdownPath,
  })  : _database = database,
        _markdownPath = markdownPath;

  Future<ExtendedAvatarProfile> getPersonality() async {
    final profile = await _database.getAvatarProfile();
    final traitsMap = jsonDecode(profile.personalityTraits) as Map<String, dynamic>;
    final traits = PersonalityTraits.fromMap(
      traitsMap.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );

    return ExtendedAvatarProfile(
      agentName: profile.agentName,
      traits: traits,
      evolutionStage: profile.evolutionStage,
      conversationCount: profile.conversationCount,
      depthScore: profile.depthScore,
    );
  }

  Future<void> updatePersonality(PersonalityTraits traits) async {
    await _database.updateAvatarTraits(traits.toMap());
    final profile = await getPersonality();
    await _syncToMarkdown(profile);
  }

  Future<void> updateAgentName(String name) async {
    await _database.updateAgentName(name);
    final profile = await getPersonality();
    await _syncToMarkdown(profile);
  }

  Future<EvolutionDecision> validateEvolutionRequest(
    String requestedStage,
    String reason,
  ) async {
    // Get depth metrics
    final metrics = await _database.getDepthMetrics();

    // Assess readiness
    final deepConversations = metrics.where((m) => m.complexityScore > 0.7).length;
    final avgNovelty = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) / metrics.length;

    // Evolution criteria:
    // - At least 5 deep conversations (complexity > 0.7)
    // - Average novelty > 0.5
    if (deepConversations >= 5 && avgNovelty > 0.5) {
      // Record evolution
      final profile = await _database.getAvatarProfile();
      await _database.recordEvolution(
        fromStage: profile.evolutionStage,
        toStage: requestedStage,
        triggerReason: reason,
        context: '$deepConversations deep conversations, ${avgNovelty.toStringAsFixed(2)} avg novelty',
        confirmedBy: 'collaborative',
      );

      // Update stage
      await _database.updateEvolutionStage(requestedStage);

      // Sync to markdown
      await _syncToMarkdown(await getPersonality());

      return EvolutionDecision(
        approved: true,
        newStage: requestedStage,
      );
    }

    return EvolutionDecision(
      approved: false,
      reason: 'Insufficient conversation depth: need 5+ deep conversations (current: $deepConversations) and avg novelty > 0.5 (current: ${avgNovelty.toStringAsFixed(2)})',
    );
  }

  Future<void> _syncToMarkdown(ExtendedAvatarProfile profile) async {
    final timestamp = DateTime.now().toIso8601String();
    final md = '''---
agent_name: ${profile.agentName}
formality: ${profile.traits.formality}
humor: ${profile.traits.humor}
enthusiasm: ${profile.traits.enthusiasm}
empathy: ${profile.traits.empathy}
evolution_stage: ${profile.evolutionStage}
conversation_count: ${profile.conversationCount}
depth_score: ${profile.depthScore}
last_updated: $timestamp
---

# ${profile.agentName} Personality

## Traits
- Formality: ${(profile.traits.formality * 100).toInt()}%
- Humor: ${(profile.traits.humor * 100).toInt()}%
- Enthusiasm: ${(profile.traits.enthusiasm * 100).toInt()}%
- Empathy: ${(profile.traits.empathy * 100).toInt()}%

## Evolution Stage: ${profile.evolutionStage}
Conversations: ${profile.conversationCount}
Depth Score: ${profile.depthScore.toStringAsFixed(2)}
''';

    final file = File('$_markdownPath/personality.md');
    await file.writeAsString(md);
  }
}
```

**Step 5: Run test to verify it passes**

Run: `flutter test test/services/avatar/personality_engine_test.dart`
Expected: PASS

**Step 6: Generate mocks and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/services/avatar/personality_engine_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/models/avatar/personality_models.dart lib/services/avatar/personality_engine.dart test/services/avatar/
git commit -m "feat: implement PersonalityEngine service

- Create personality models (PersonalityTraits, EvolutionDecision)
- Implement PersonalityEngine service with CRUD operations
- Add evolution validation logic (5+ deep conversations required)
- Add markdown sync for personality backup
- Add comprehensive unit tests
"
```

---

### Task 1.3: Update Avatar Widget to Accept Personality

**Files:**
- Modify: `lib/features/avatar/avatar_widget.dart`

**Step 1: Add personality parameter to Avatar**

```dart
import 'package:cloudtolocallm/models/avatar/personality_models.dart';

class AgentAvatar extends StatefulWidget {
  final AgentState state;
  final double size;
  final PersonalityTraits? personality;  // NEW

  const AgentAvatar({
    super.key,
    required this.state,
    this.size = 150,
    this.personality,  // NEW
  });

  @override
  State<AgentAvatar> createState() => _AgentAvatarState();
}
```

**Step 2: Add dynamic color calculation**

Add this method to `_AgentAvatarState`:

```dart
Color _getPersonalityColor(PersonalityTraits? traits) {
  if (traits == null) {
    return theme.primaryColor;
  }

  // Hue from empathy (blue 220° → warm 180°)
  final hue = 220 - (traits.empathy * 40);

  // Saturation from enthusiasm (muted 0.5 → vibrant 1.0)
  final saturation = 0.5 + (traits.enthusiasm * 0.5);

  // Lightness from humor (darker 0.4 → brighter 0.6)
  final lightness = 0.4 + (traits.humor * 0.2);

  return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
}

Duration _getPulseDuration(PersonalityTraits? traits) {
  if (traits == null) {
    return const Duration(seconds: 2);
  }

  // Enthusiasm controls speed (1.0s → 0.2s)
  final speedMillis = (1000 - (traits.enthusiasm * 800)).round();
  return Duration(milliseconds: speedMillis);
}

double _getBounceScale(PersonalityTraits? traits) {
  if (traits == null) {
    return 1.0;
  }

  // Humor controls bounce (1.0 → 1.2)
  return 1.0 + (traits.humor * 0.2);
}
```

**Step 3: Update build method to use personality**

Modify the build method to use the new dynamic methods:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  // Use personality for dynamic properties
  final baseColor = _getPersonalityColor(widget.personality);
  final pulseDuration = _getPulseDuration(widget.personality);
  final bounceScale = _getBounceScale(widget.personality);

  // Switch emoji based on state (keep existing logic)
  Color baseColor;
  String emoji;
  double scale = 1.0;
  bool isPulsing = false;

  switch (widget.state) {
    case AgentState.idle:
      baseColor = _getPersonalityColor(widget.personality);
      emoji = _getEmojiForState(widget.state, widget.personality);
      break;
    case AgentState.thinking:
      baseColor = Colors.amber;
      emoji = '🤔';
      isPulsing = true;
      break;
    case AgentState.working:
      baseColor = Colors.blue;
      emoji = '⚡';
      isPulsing = true;
      break;
    case AgentState.error:
      baseColor = Colors.red;
      emoji = '💢';
      break;
    case AgentState.happy:
      baseColor = Colors.green;
      emoji = '✨';
      scale = _getBounceScale(widget.personality);
      break;
  }

  return AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final pulse = isPulsing ? (0.95 + (_controller.value * 0.1)) : 1.0;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: widget.size * pulse * scale * bounceScale,
        height: widget.size * pulse * scale * bounceScale,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: baseColor.withValues(alpha: 0.5),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.3),
              blurRadius: 20 * pulse,
              spreadRadius: 5 * pulse,
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              emoji,
              key: ValueKey(emoji),
              style: TextStyle(fontSize: widget.size * 0.5),
            ),
          ),
        ),
      );
    },
  );
}

String _getEmojiForState(AgentState state, PersonalityTraits? traits) {
  if (traits == null) {
    return '🦞';  // Default
  }

  // Trait-based emoji selection
  if (traits.humor > 0.7) {
    switch (state) {
      case AgentState.idle: return '😜';
      case AgentState.thinking: return '🤪';
      case AgentState.working: return '⚡';
      case AgentState.error: return '💥';
      case AgentState.happy: return '🎉';
    }
  }

  if (traits.empathy > 0.8) {
    switch (state) {
      case AgentState.idle: return '🤗';
      case AgentState.thinking: return '💭';
      case AgentState.working: return '💪';
      case AgentState.error: return '😢';
      case AgentState.happy: return '🥰';
    }
  }

  if (traits.formality > 0.7) {
    switch (state) {
      case AgentState.idle: return '🎩';
      case AgentState.thinking: return '🧐';
      case AgentState.working: return '📊';
      case AgentState.error: return '⚠️';
      case AgentState.happy: return '✅';
    }
  }

  if (traits.enthusiasm > 0.7) {
    switch (state) {
      case AgentState.idle: return '🌟';
      case AgentState.thinking: return '💡';
      case AgentState.working: return '🚀';
      case AgentState.error: return '😵';
      case AgentState.happy: return '🎊';
    }
  }

  // Default emoji set
  switch (state) {
    case AgentState.idle: return '🦞';
    case AgentState.thinking: return '🤔';
    case AgentState.working: return '⚡';
    case AgentState.error: return '💢';
    case AgentState.happy: return '✨';
  }
}
```

**Step 4: Add missing import**

```dart
import 'dart:ui' show HSLColor;
```

**Step 5: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/avatar/avatar_widget.dart
git commit -m "feat: add personality-driven avatar visuals

- Add personality parameter to AgentAvatar
- Implement dynamic color based on empathy trait
- Implement pulse speed based on enthusiasm
- Implement bounce scale based on humor
- Add trait-based emoji selection
"
```

---

### Task 1.4: Register Services in DI

**Files:**
- Modify: `lib/di/locator.dart`

**Step 1: Determine OpenClaw skills path**

Add method to find OpenClaw skills directory:

```dart
String _getOpenClawSkillsPath() {
  // Check common locations for OpenClaw skills directory
  final home = Platform.environment['HOME'];
  if (home == null) {
    // Fallback to temp directory
    return Directory.systemTemp.path;
  }

  final possiblePaths = [
    '$home/.openclaw/skills/cloudtolocallm',
    '$home/.config/openclaw/skills/cloudtolocallm',
    '$home/AppData/Roaming/openclaw/skills/cloudtolocallm',  // Windows
  ];

  for (final path in possiblePaths) {
    if (Directory(path).existsSync()) {
      return path;
    }
  }

  // Create default path if it doesn't exist
  final defaultPath = '$home/.openclaw/skills/cloudtolocallm';
  Directory(defaultPath).createSync(recursive: true);
  return defaultPath;
}
```

**Step 2: Register PersonalityEngine**

Add to `setupCoreServices()`:

```dart
// Avatar services
final markdownPath = _getOpenClawSkillsPath();
locator.registerLazySingleton<PersonalityEngine>(
  () => PersonalityEngine(
    database: locator<DriftLocalBrain>(),
    markdownPath: markdownPath,
  ),
);
```

**Step 3: Add Platform import**

```dart
import 'dart:io' show Platform, Directory;
```

**Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/di/locator.dart
git commit -m "feat: register PersonalityEngine in service locator

- Add OpenClaw skills path detection
- Register PersonalityEngine as lazy singleton
- Support Linux, Windows, macOS skill directory locations
"
```

---

## Phase 2: Evolution Tracker

### Task 2.1: Create EvolutionTracker Service

**Files:**
- Create: `lib/services/avatar/evolution_tracker.dart`
- Test: `test/services/avatar/evolution_tracker_test.dart`

**Step 1: Write the failing test**

Create `test/services/avatar/evolution_tracker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocallm/database/database.dart';
import 'package:cloudtolocallm/services/avatar/evolution_tracker.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocallm/models/conversation.dart';

@GenerateMocks([DriftLocalBrain])
import 'evolution_tracker_test.mocks.dart';

void main() {
  late EvolutionTracker tracker;
  late MockDriftLocalBrain mockDb;

  setUp(() {
    mockDb = MockDriftLocalBrain();
    tracker = EvolutionTracker(database: mockDb);
  });

  group('EvolutionTracker', () {
    test('trackConversation stores depth metrics', () async {
      final conversation = Conversation(
        id: 'conv1',
        title: 'Test Chat',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final messages = [
        Message(
          id: 'msg1',
          conversationId: 'conv1',
          role: 'user',
          content: 'Explain quantum entanglement in detail',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        Message(
          id: 'msg2',
          conversationId: 'conv1',
          role: 'assistant',
          content: 'Quantum entanglement is a phenomenon where quantum particles become correlated...',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      when(mockDb.getMessages('conv1')).thenAnswer((_) async => messages);
      when(mockDb.addConversationDepthMetrics(any)).thenAnswer((_) async {});

      await tracker.trackConversation(conversation);

      verify(mockDb.addConversationDepthMetrics(
        argThat(isA<ConversationDepthMetricsCompanion>()),
      )).called(1);
    });

    test('hasEvolutionPatterns returns true with sufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => List.generate(
        5,
        (i) => ConversationDepthMetric(
          id: 'id$i',
          conversationId: 'conv$i',
          complexityScore: 0.8,
          emotionalDepth: 0.7,
          noveltyScore: 0.6,
          timestamp: 1000 + i * 100,
        ),
      ));

      final result = await tracker.hasEvolutionPatterns();

      expect(result, isTrue);
    });

    test('hasEvolutionPatterns returns false with insufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
        ConversationDepthMetric(
          id: 'id1',
          conversationId: 'conv1',
          complexityScore: 0.3,
          emotionalDepth: 0.2,
          noveltyScore: 0.3,
          timestamp: 1000,
        ),
      ]);

      final result = await tracker.hasEvolutionPatterns();

      expect(result, isFalse);
    });

    test('calculateComplexity scores higher for longer messages', () async {
      final simpleMessages = [
        Message(
          id: 'm1',
          conversationId: 'c1',
          role: 'user',
          content: 'Hi',
          timestamp: 1000,
        ),
      ];

      final complexMessages = [
        Message(
          id: 'm1',
          conversationId: 'c1',
          role: 'user',
          content: 'Can you explain the philosophical implications of quantum mechanics on our understanding of reality and consciousness?',
          timestamp: 1000,
        ),
      ];

      final simpleScore = tracker.calculateComplexity(simpleMessages);
      final complexScore = tracker.calculateComplexity(complexMessages);

      expect(complexScore, greaterThan(simpleScore));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/avatar/evolution_tracker_test.dart`
Expected: FAIL with "EvolutionTracker not implemented"

**Step 3: Write minimal implementation**

Create `lib/services/avatar/evolution_tracker.dart`:

```dart
import 'package:cloudtolocallm/database/database.dart';

class DepthMetrics {
  final double complexity;
  final double emotional;
  final double novelty;

  DepthMetrics({
    required this.complexity,
    required this.emotional,
    required this.novelty,
  });
}

class EvolutionTracker {
  final DriftLocalBrain _database;

  EvolutionTracker({required DriftLocalBrain database}) : _database = database;

  Future<void> trackConversation(Conversation conversation) async {
    final metrics = await _analyzeDepth(conversation);

    await _database.addConversationDepthMetrics(
      ConversationDepthMetricsCompanion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: Value(conversation.id),
        complexityScore: Value(metrics.complexity),
        emotionalDepth: Value(metrics.emotional),
        noveltyScore: Value(metrics.novelty),
        timestamp: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<DepthMetrics> _analyzeDepth(Conversation conversation) async {
    final messages = await _database.getMessages(conversation.id);

    return DepthMetrics(
      complexity: calculateComplexity(messages),
      emotional: calculateEmotionalDepth(messages),
      novelty: await calculateNovelty(messages),
    );
  }

  double calculateComplexity(List<Message> messages) {
    if (messages.isEmpty) return 0.0;

    double complexity = 0.0;
    int totalLength = 0;

    for (final message in messages) {
      // Length contributes to complexity
      totalLength += message.content.length;

      // Topic diversity (simple word count heuristic)
      final words = message.content.split(RegExp(r'\s+'));
      final uniqueWords = words.toSet();
      if (words.isNotEmpty) {
        complexity += uniqueWords.length / words.length;
      }

      // Question marks indicate inquiry (higher complexity)
      if (message.content.contains('?')) {
        complexity += 0.2;
      }

      // Technical terms increase complexity
      final technicalTerms = [
        'quantum', 'algorithm', 'function', 'method', 'class',
        'database', 'api', 'protocol', 'architecture', 'system',
        'implement', 'design', 'analyze', 'optimize'
      ];
      for (final term in technicalTerms) {
        if (message.content.toLowerCase().contains(term)) {
          complexity += 0.1;
        }
      }
    }

    // Normalize by message count and length
    final avgLength = totalLength / messages.length;
    final normalizedComplexity = (complexity / messages.length).clamp(0.0, 1.0);

    // Boost for longer average message length (indicates depth)
    final lengthBoost = (avgLength / 500).clamp(0.0, 0.3);

    return (normalizedComplexity + lengthBoost).clamp(0.0, 1.0);
  }

  double calculateEmotionalDepth(List<Message> messages) {
    if (messages.isEmpty) return 0.0;

    double emotionalScore = 0.0;

    final empatheticWords = [
      'feel', 'understand', 'care', 'help', 'support',
      'empathy', 'compassion', 'kindness', 'appreciate'
    ];

    final personalWords = [
      'i feel', 'i think', 'my opinion', 'personally',
      'believe', 'experience', 'perspective'
    ];

    for (final message in messages) {
      final lower = message.content.toLowerCase();

      // Empathetic language
      for (final word in empatheticWords) {
        if (lower.contains(word)) {
          emotionalScore += 0.15;
        }
      }

      // Personal sharing
      for (final phrase in personalWords) {
        if (lower.contains(phrase)) {
          emotionalScore += 0.1;
        }
      }

      // Emotional words
      final emotionalWords = ['happy', 'sad', 'excited', 'worried', 'confused', 'frustrated'];
      for (final word in emotionalWords) {
        if (lower.contains(word)) {
          emotionalScore += 0.1;
        }
      }
    }

    return (emotionalScore / messages.length).clamp(0.0, 1.0);
  }

  Future<double> calculateNovelty(List<Message> messages) async {
    if (messages.isEmpty) return 0.0;

    // Get recent conversation history for comparison
    final recentMetrics = await _database.getDepthMetrics();
    if (recentMetrics.isEmpty) return 0.5;  // Neutral for first conversation

    // Extract topics from current messages
    final currentTopics = _extractTopics(messages);

    // Compare with historical topics (simplified: check if topics repeat)
    // For now, use a simple heuristic based on vocabulary diversity
    final allWords = messages
        .expand((m) => m.content.split(RegExp(r'\s+')))
        .where((w) => w.length > 4)  // Only meaningful words
        .toSet();

    // High word count relative to message count indicates novelty
    final novelty = (allWords.length / (messages.length * 10)).clamp(0.0, 1.0);

    return novelty;
  }

  Set<String> _extractTopics(List<Message> messages) {
    final topics = <String>{};
    final stopWords = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare', 'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during', 'before', 'after', 'above', 'below', 'between', 'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why', 'how', 'all', 'each', 'few', 'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 'just', 'and', 'but', 'if', 'or', 'because', 'as', 'until', 'while', 'although', 'though', 'this', 'that', 'these', 'those', 'he', 'she', 'it', 'they', 'we', 'you', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'its', 'our', 'their', 'mine', 'yours', 'hers', 'ours', 'theirs', 'what', 'which', 'who', 'whom', 'whose', 'where', 'when', 'why', 'how', 'whatever', 'whichever', 'whoever', 'whomever', 'whenever', 'wherever', 'however', 'i', 'me', 'my', 'myself', 'you', 'your', 'yours', 'yourself', 'yourselves', 'him', 'his', 'himself', 'her', 'hers', 'herself', 'it', 'its', 'itself', 'we', 'us', 'our', 'ours', 'ourselves', 'they', 'them', 'their', 'theirs', 'themselves'};

    for (final message in messages) {
      final words = message.content
          .toLowerCase()
          .split(RegExp(r'[^\w]+'))
          .where((w) => w.length > 4 && !stopWords.contains(w));

      topics.addAll(words);
    }

    return topics;
  }

  Future<bool> hasEvolutionPatterns() async {
    final metrics = await _database.getDepthMetrics();

    // Need at least 5 deep conversations (complexity > 0.7)
    final deepConversations = metrics.where((m) => m.complexityScore > 0.7).length;
    if (deepConversations < 5) return false;

    // Need average novelty > 0.5
    if (metrics.isEmpty) return false;
    final avgNovelty = metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) / metrics.length;
    if (avgNovelty <= 0.5) return false;

    return true;
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/avatar/evolution_tracker_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/avatar/evolution_tracker.dart test/services/avatar/
git commit -m "feat: implement EvolutionTracker service

- Implement conversation depth analysis (complexity, emotional, novelty)
- Add complexity calculation based on length, vocabulary, technical terms
- Add emotional depth calculation based on empathetic language
- Add novelty calculation using topic extraction
- Add evolution pattern detection (5+ deep conversations, avg novelty > 0.5)
- Add comprehensive unit tests
"
```

---

### Task 2.2: Register EvolutionTracker in DI

**Files:**
- Modify: `lib/di/locator.dart`

**Step 1: Register EvolutionTracker**

Add to `setupCoreServices()` after PersonalityEngine:

```dart
locator.registerLazySingleton<EvolutionTracker>(
  () => EvolutionTracker(database: locator<DriftLocalBrain>()),
);
```

**Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/di/locator.dart
git commit -m "feat: register EvolutionTracker in service locator"
```

---

## Phase 3: OpenClaw Skill

### Task 3.1: Create OpenClaw Skill Directory Structure

**Files:**
- Create: `~/.openclaw/skills/cloudtolocallm/` directory
- Create: `~/.openclaw/skills/cloudtolocallm/SKILL.md`
- Create: `~/.openclaw/skills/cloudtolocallm/package.json`
- Create: `~/.openclaw/skills/cloudtolocallm/tsconfig.json`

**Step 1: Create skill directory**

```bash
mkdir -p ~/.openclaw/skills/cloudtolocallm
```

**Step 2: Create SKILL.md**

```bash
cat > ~/.openclaw/skills/cloudtolocallm/SKILL.md << 'EOF'
# CloudToLocalLLM Avatar Personality

Provides personality-driven responses and organic evolution capabilities for OpenClaw agents.

## Personality Traits

The agent has four personality traits (0-1 scale):
- **Formality**: How formal/professional responses are (0.0 = casual, 1.0 = formal)
- **Humor**: How playful/casual the agent is (0.0 = serious, 1.0 = playful)
- **Enthusiasm**: Energy level and expressiveness (0.0 = calm, 1.0 = enthusiastic)
- **Empathy**: Emotional intelligence and warmth (0.0 = direct, 1.0 = empathetic)

## Evolution System

The agent evolves organically through meaningful conversations:
- No XP grinding - evolution based on conversation depth and patterns
- Self-reflection: agent recognizes when it has grown
- Collaborative: CloudToLocalLLM validates evolution requests
- Stages: base → stage1 → stage2 → final

## Data Storage

- **Primary**: Drift database on VPS (accessed via Tailscale)
- **Backup**: Markdown files in this directory (personality.md, memory.md, context.md)
- **Fallback**: Markdown files used when database unavailable

## Usage

The skill automatically:
1. Loads current personality from database or markdown
2. Injects personality into agent responses
3. Tracks conversation depth for evolution
4. Requests evolution when ready (via self-reflection)
EOF
```

**Step 3: Create package.json**

```bash
cat > ~/.openclaw/skills/cloudtolocallm/package.json << 'EOF'
{
  "name": "cloudtolocallm-personality-skill",
  "version": "1.0.0",
  "description": "Avatar personality and evolution system for OpenClaw",
  "main": "index.ts",
  "type": "module",
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "test": "vitest"
  },
  "keywords": [
    "openclaw",
    "skill",
    "personality",
    "avatar",
    "evolution"
  ],
  "dependencies": {
    "better-sqlite3": "^9.0.0"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.0",
    "typescript": "^5.0.0",
    "vitest": "^1.0.0"
  }
}
EOF
```

**Step 4: Create tsconfig.json**

```bash
cat > ~/.openclaw/skills/cloudtolocallm/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "node",
    "outDir": "./dist",
    "rootDir": "./",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["*.ts"],
  "exclude": ["node_modules", "dist"]
}
EOF
```

**Step 5: Commit**

Note: This is in OpenClaw skills directory, not the git repo. We'll create the skill files in the repo first, then provide instructions to install.

**Alternative approach**: Create skill files in `services/openclaw-skills/cloudtolocallm/` directory in the repo, then copy to OpenClaw skills directory.

---

### Task 3.2: Create OpenClaw Personality Skill (TypeScript)

**Files:**
- Create: `services/openclaw-skills/cloudtolocallm/index.ts`
- Create: `services/openclaw-skills/cloudtolocallm/drift-adapter.ts`

**Step 1: Create Drift adapter**

Create `services/openclaw-skills/cloudtolocallm/drift-adapter.ts`:

```typescript
import Database from 'better-sqlite3';

interface PersonalityTraits {
  formality: number;
  humor: number;
  enthusiasm: number;
  empathy: number;
}

interface AvatarProfile {
  agentName: string;
  personality: PersonalityTraits;
  evolutionStage: string;
  conversationCount: number;
  depthScore: number;
}

interface ConversationDepthMetric {
  id: string;
  conversationId: string;
  complexityScore: number;
  emotionalDepth: number;
  noveltyScore: number;
  timestamp: number;
}

export class DriftAdapter {
  private db: Database.Database | null = null;
  private dbPath: string;

  constructor(dbPath: string = '~/.local/share/CloudToLocalLLM/local_brain.db') {
    this.dbPath = dbPath.replace('~', process.env.HOME || '');
  }

  connect(): boolean {
    try {
      this.db = new Database(this.dbPath, { readonly: true });
      return true;
    } catch (error) {
      console.error('Failed to connect to database:', error);
      return false;
    }
  }

  disconnect(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
    }
  }

  getAvatarProfile(): AvatarProfile | null {
    if (!this.db) return null;

    try {
      const row = this.db.prepare(`
        SELECT agent_name, personality_traits, evolution_stage,
               conversation_count, depth_score
        FROM avatar_profiles
        LIMIT 1
      `).get() as any;

      if (!row) return null;

      const traits = JSON.parse(row.personality_traits) as PersonalityTraits;

      return {
        agentName: row.agent_name,
        personality: traits,
        evolutionStage: row.evolution_stage,
        conversationCount: row.conversation_count,
        depthScore: row.depth_score,
      };
    } catch (error) {
      console.error('Failed to get avatar profile:', error);
      return null;
    }
  }

  getRecentConversations(limit: number = 10): any[] {
    if (!this.db) return [];

    try {
      return this.db.prepare(`
        SELECT id, title, created_at, updated_at
        FROM conversations
        ORDER BY updated_at DESC
        LIMIT ?
      `).all(limit) as any[];
    } catch (error) {
      console.error('Failed to get conversations:', error);
      return [];
    }
  }

  getDepthMetrics(): ConversationDepthMetric[] {
    if (!this.db) return [];

    try {
      return this.db.prepare(`
        SELECT id, conversation_id, complexity_score,
               emotional_depth, novelty_score, timestamp
        FROM conversation_depth_metrics
        ORDER BY timestamp DESC
        LIMIT 20
      `).all() as any[];
    } catch (error) {
      console.error('Failed to get depth metrics:', error);
      return [];
    }
  }
}
```

**Step 2: Create main skill index**

Create `services/openclaw-skills/cloudtolocallm/index.ts`:

```typescript
import { readFileSync, existsSync } from 'fs';
import { DriftAdapter } from './drift-adapter.js';

interface PersonalityTraits {
  formality: number;
  humor: number;
  enthusiasm: number;
  empathy: number;
}

interface AvatarProfile {
  agentName: string;
  personality: PersonalityTraits;
  evolutionStage: string;
  conversationCount: number;
  depthScore: number;
}

interface EvolutionRequest {
  requestedStage: string;
  reason: string;
  context: string;
}

export class PersonalitySkill {
  private drift: DriftAdapter;
  private personality: AvatarProfile | null = null;
  private skillsPath: string;
  private apiUrl: string = 'http://localhost:1337';

  constructor(skillsPath: string) {
    this.skillsPath = skillsPath;
    this.drift = new DriftAdapter();
  }

  async initialize(): Promise<void> {
    // Try to load from Drift database
    if (this.drift.connect()) {
      const profile = this.drift.getAvatarProfile();
      if (profile) {
        this.personality = profile;
        console.log('Loaded personality from database');
        return;
      }
    }

    // Fallback to markdown
    this.personality = this.loadPersonalityFromMarkdown();
    console.log('Loaded personality from markdown (database unavailable)');
  }

  private loadPersonalityFromMarkdown(): AvatarProfile {
    const mdPath = `${this.skillsPath}/personality.md`;

    if (!existsSync(mdPath)) {
      // Return default personality
      return {
        agentName: 'Agent',
        personality: {
          formality: 0.5,
          humor: 0.5,
          enthusiasm: 0.5,
          empathy: 0.5,
        },
        evolutionStage: 'base',
        conversationCount: 0,
        depthScore: 0.0,
      };
    }

    const content = readFileSync(mdPath, 'utf-8');
    const frontmatter = this.parseFrontmatter(content);

    return {
      agentName: frontmatter.agent_name || 'Agent',
      personality: {
        formality: frontmatter.formality || 0.5,
        humor: frontmatter.humor || 0.5,
        enthusiasm: frontmatter.enthusiasm || 0.5,
        empathy: frontmatter.empathy || 0.5,
      },
      evolutionStage: frontmatter.evolution_stage || 'base',
      conversationCount: frontmatter.conversation_count || 0,
      depthScore: frontmatter.depth_score || 0.0,
    };
  }

  private parseFrontmatter(content: string): any {
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
    if (!frontmatterMatch) return {};

    const frontmatter = frontmatterMatch[1];
    const data: any = {};

    for (const line of frontmatter.split('\n')) {
      const [key, ...valueParts] = line.split(':');
      if (key && valueParts.length > 0) {
        const value = valueParts.join(':').trim();
        data[key.trim()] = isNaN(Number(value)) ? value : Number(value);
      }
    }

    return data;
  }

  injectPersonality(basePrompt: string): string {
    if (!this.personality) {
      return basePrompt;
    }

    const { agentName, personality, evolutionStage } = this.personality;

    return `${basePrompt}

You are ${agentName}, an AI assistant with a unique personality:
- Formality: ${(personality.formality * 100).toFixed(0)}%
- Humor: ${(personality.humor * 100).toFixed(0)}%
- Enthusiasm: ${(personality.enthusiasm * 100).toFixed(0)}%
- Empathy: ${(personality.empathy * 100).toFixed(0)}%
- Evolution Stage: ${evolutionStage}

Respond in a way that reflects these personality traits naturally.`;
  }

  async selfReflect(): Promise<boolean> {
    if (!this.drift.connect()) {
      console.log('Cannot self-reflect: database unavailable');
      return false;
    }

    const metrics = this.drift.getDepthMetrics();

    // Analyze growth
    const deepConversations = metrics.filter(m => m.complexityScore > 0.7);
    const avgComplexity = metrics.length > 0
      ? metrics.reduce((sum, m) => sum + m.complexityScore, 0) / metrics.length
      : 0;

    const avgNovelty = metrics.length > 0
      ? metrics.reduce((sum, m) => sum + m.noveltyScore, 0) / metrics.length
      : 0;

    // Check if ready to evolve
    if (deepConversations.length >= 5 && avgNovelty > 0.5) {
      console.log('Self-reflection: I feel ready to evolve');
      return await this.requestEvolution('self_reflection');
    }

    console.log('Self-reflection: Not ready to evolve yet');
    return false;
  }

  private async requestEvolution(reason: string): Promise<boolean> {
    const currentStage = this.personality?.evolutionStage || 'base';
    const nextStage = this.getNextStage(currentStage);

    const request: EvolutionRequest = {
      requestedStage: nextStage,
      reason: reason,
      context: `Self-reflection after ${this.personality?.conversationCount || 0} conversations`,
    };

    try {
      const response = await fetch(`${this.apiUrl}/avatar/evolution/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(request),
      });

      const result = await response.json();

      if (result.approved) {
        console.log(`Evolution approved: ${currentStage} → ${nextStage}`);
        if (this.personality) {
          this.personality.evolutionStage = nextStage;
        }
        return true;
      } else {
        console.log(`Evolution denied: ${result.reason}`);
        return false;
      }
    } catch (error) {
      console.error('Failed to request evolution:', error);
      return false;
    }
  }

  private getNextStage(currentStage: string): string {
    const stages = ['base', 'stage1', 'stage2', 'final'];
    const currentIndex = stages.indexOf(currentStage);
    if (currentIndex === -1 || currentIndex === stages.length - 1) {
      return currentStage;  // Already at final stage
    }
    return stages[currentIndex + 1];
  }

  getPersonality(): AvatarProfile | null {
    return this.personality;
  }
}
```

**Step 3: Copy to OpenClaw skills directory**

```bash
mkdir -p ~/.openclaw/skills/cloudtolocallm
cp -r services/openclaw-skills/cloudtolocallm/* ~/.openclaw/skills/cloudtolocallm/
```

**Step 4: Commit**

```bash
git add services/openclaw-skills/
git commit -m "feat: add OpenClaw personality skill

- Create TypeScript skill for OpenClaw Gateway
- Implement Drift adapter for database access
- Add personality injection into prompts
- Add self-reflection for evolution triggers
- Add markdown fallback for offline mode
- Add evolution request to CloudToLocalLLM API
"
```

---

## Phase 4: Evolution API Endpoints

### Task 4.1: Add Evolution Endpoints to Router

**Files:**
- Modify: `lib/services/router_server.dart`

**Step 1: Add evolution endpoint handlers**

Add these handlers to RouterServer:

```dart
Future<Response> _handleGetAvatarState(Request request) async {
  try {
    final personalityEngine = locator<PersonalityEngine>();
    final profile = await personalityEngine.getPersonality();

    return Response.json({
      'agent_name': profile.agentName,
      'traits': profile.traits.toMap(),
      'evolution_stage': profile.evolutionStage,
      'conversation_count': profile.conversationCount,
      'depth_score': profile.depthScore,
    });
  } catch (e) {
    return Response.json({'error': e.toString()}, statusCode: 500);
  }
}

Future<Response> _handleUpdateTraits(Request request) async {
  try {
    final body = await request.readAsJson();
    final traitsMap = body['traits'] as Map<String, dynamic>;

    final traits = PersonalityTraits(
      formality: (traitsMap['formality'] as num).toDouble(),
      humor: (traitsMap['humor'] as num).toDouble(),
      enthusiasm: (traitsMap['enthusiasm'] as num).toDouble(),
      empathy: (traitsMap['empathy'] as num).toDouble(),
    );

    final personalityEngine = locator<PersonalityEngine>();
    await personalityEngine.updatePersonality(traits);

    return Response.json({'success': true});
  } catch (e) {
    return Response.json({'error': e.toString()}, statusCode: 500);
  }
}

Future<Response> _handleEvolutionRequest(Request request) async {
  try {
    final body = await request.readAsJson();
    final requestedStage = body['requestedStage'] as String;
    final reason = body['reason'] as String;
    final context = body['context'] as String?;

    final personalityEngine = locator<PersonalityEngine>();
    final decision = await personalityEngine.validateEvolutionRequest(
      requestedStage,
      reason,
    );

    return Response.json({
      'approved': decision.approved,
      'reason': decision.reason,
      'new_stage': decision.newStage,
    });
  } catch (e) {
    return Response.json({'error': e.toString()}, statusCode: 500);
  }
}
```

**Step 2: Register routes**

Add to router setup in `_startServer` method:

```dart
// Avatar endpoints
router.get('/avatar/state', _handleGetAvatarState);
router.post('/avatar/traits', _handleUpdateTraits);
router.post('/avatar/evolution/request', _handleEvolutionRequest);
```

**Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/services/router_server.dart
git commit -m "feat: add evolution API endpoints to router

- Add GET /avatar/state - get current personality
- Add POST /avatar/traits - update personality traits
- Add POST /avatar/evolution/request - evolution validation
- All endpoints return JSON responses
"
```

---

## Phase 5: Testing & Documentation

### Task 5.1: Add Integration Tests

**Files:**
- Create: `test/integration/evolution_flow_test.dart`

**Step 1: Create evolution flow integration test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocallm/database/database.dart';
import 'package:cloudtolocallm/services/avatar/personality_engine.dart';
import 'package:cloudtolocallm/services/avatar/evolution_tracker.dart';
import 'package:cloudtolocallm/models/avatar/personality_models.dart';

void main() {
  group('Evolution Flow Integration', () {
    late DriftLocalBrain db;
    late PersonalityEngine personalityEngine;
    late EvolutionTracker evolutionTracker;

    setUp(() async {
      // Use in-memory database for testing
      db = DriftLocalBrain.memory();
      await db.databaseSchema.createAll();
      personalityEngine = PersonalityEngine(
        database: db,
        markdownPath: Directory.systemTemp.path,
      );
      evolutionTracker = EvolutionTracker(database: db);
    });

    test('Complete evolution flow', () async {
      // Step 1: Check initial state
      final initialProfile = await personalityEngine.getPersonality();
      expect(initialProfile.evolutionStage, equals('base'));

      // Step 2: Track deep conversations
      for (int i = 0; i < 5; i++) {
        final conv = Conversation(
          id: 'conv$i',
          title: 'Deep Discussion $i',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        // Create messages
        await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'msg${i}_1',
            conversationId: 'conv$i',
            role: const Value('user'),
            content: 'Explain the philosophical implications of consciousness and reality',
            timestamp: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

        await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'msg${i}_2',
            conversationId: 'conv$i',
            role: const Value('assistant'),
            content: 'The philosophical implications of consciousness are profound...',
            timestamp: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

        // Track conversation
        await evolutionTracker.trackConversation(conv);
      }

      // Step 3: Check evolution patterns
      final hasPatterns = await evolutionTracker.hasEvolutionPatterns();
      expect(hasPatterns, isTrue);

      // Step 4: Request evolution
      final decision = await personalityEngine.validateEvolutionRequest(
        'stage1',
        'self_reflection',
      );

      // Step 5: Verify evolution approved
      expect(decision.approved, isTrue);
      expect(decision.newStage, equals('stage1'));

      // Step 6: Verify database state
      final evolvedProfile = await personalityEngine.getPersonality();
      expect(evolvedProfile.evolutionStage, equals('stage1'));

      // Step 7: Verify evolution history recorded
      final history = await db.getEvolutionHistory();
      expect(history.length, greaterThan(0));
      expect(history.first.fromStage, equals('base'));
      expect(history.first.toStage, equals('stage1'));
      expect(history.first.confirmedBy, equals('collaborative'));
    });
  });
}
```

**Step 2: Run integration test**

Run: `flutter test test/integration/evolution_flow_test.dart`
Expected: PASS

**Step 3: Commit**

```bash
git add test/integration/
git commit -m "test: add evolution flow integration test

- Test complete evolution flow from conversations to transformation
- Verify deep conversation tracking
- Verify evolution pattern detection
- Verify collaborative evolution approval
- Verify database state updates
"
```

---

### Task 5.2: Update Documentation

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add avatar system documentation to CLAUDE.md**

Add under "Avatar System (CloudToLocalLLM)" section:

```dart
### Avatar Personality System

**Architecture**: Hybrid shared state with OpenClaw Gateway
- OpenClaw owns personality & evolution (traits, evolution stages)
- CloudToLocalLLM provides expanded awareness (memory, context, visual data)
- Drift database (VPS via Tailscale) = primary storage
- Markdown files (~/.openclaw/skills/cloudtolocallm/) = backup storage

**Personality Traits** (0-1 scale):
- Formality, Humor, Enthusiasm, Empathy

**Evolution System** (no XP):
- Triggers: Conversation depth, user patterns, agent self-reflection
- Collaborative: OpenClaw requests, CloudToLocalLLM validates
- Stages: base → stage1 → stage2 → final

**Services**:
- `PersonalityEngine`: Read/write personality, sync to markdown
- `EvolutionTracker`: Analyze conversation depth, detect patterns
- `AvatarStateService`: Manage avatar UI state, animations

**API Endpoints** (Port 1337):
- GET /avatar/state - Get current personality
- POST /avatar/traits - Update personality traits
- POST /avatar/evolution/request - Evolution validation

**OpenClaw Skill**:
- Location: ~/.openclaw/skills/cloudtolocallm/
- Files: SKILL.md, index.ts, drift-adapter.ts
- Functionality: Personality injection, self-reflection, evolution requests

**See**: `docs/plans/2026-02-22-avatar-personality-engine-design.md`
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Avatar Personality Engine to CLAUDE.md

- Document hybrid architecture with OpenClaw
- Add personality traits description
- Add evolution system overview
- Document services and API endpoints
- Add OpenClaw skill information
"
```

---

## Final Steps

### Task 6.1: Create Installation Script

**Files:**
- Create: `scripts/install-openclaw-skill.sh`

**Step 1: Create installation script**

```bash
cat > scripts/install-openclaw-skill.sh << 'EOF'
#!/bin/bash

# Install CloudToLocalLLM personality skill to OpenClaw

SKILL_NAME="cloudtolocallm"
SOURCE_DIR="services/openclaw-skills/$SKILL_NAME"
TARGET_DIR="$HOME/.openclaw/skills/$SKILL_NAME"

echo "Installing $SKILL_NAME skill to OpenClaw..."

# Create target directory
mkdir -p "$TARGET_DIR"

# Copy skill files
cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"

# Install dependencies
cd "$TARGET_DIR"
npm install

# Build TypeScript
npm run build

echo "Skill installed successfully!"
echo "Location: $TARGET_DIR"
echo ""
echo "To use the skill, restart OpenClaw Gateway."
EOF

chmod +x scripts/install-openclaw-skill.sh
```

**Step 2: Commit**

```bash
git add scripts/install-openclaw-skill.sh
git commit -m "feat: add OpenClaw skill installation script

- Create bash script to copy skill to OpenClaw directory
- Install npm dependencies
- Build TypeScript
"
```

---

### Task 6.2: Create README for Avatar System

**Files:**
- Create: `docs/avatar/README.md`

**Step 1: Create README**

```bash
cat > docs/avatar/README.md << 'EOF'
# Avatar Personality Engine

The Avatar Personality Engine enables OpenClaw agents to develop unique personalities that evolve organically through meaningful conversations.

## Quick Start

1. **Install the OpenClaw skill**:
   ```bash
   ./scripts/install-openclaw-skill.sh
   ```

2. **Restart OpenClaw Gateway**:
   ```bash
   openclaw gateway restart
   ```

3. **Adjust personality** (via CloudToLocalLLM UI or API):
   ```bash
   curl -X POST http://localhost:1337/avatar/traits \
     -H "Content-Type: application/json" \
     -d '{"traits": {"formality": 0.7, "humor": 0.4, "enthusiasm": 0.8, "empathy": 0.9}}'
   ```

4. **Have deep conversations** to trigger evolution

## Personality Traits

- **Formality** (0-1): How formal/professional responses are
- **Humor** (0-1): How playful/casual the agent is
- **Enthusiasm** (0-1): Energy level and expressiveness
- **Empathy** (0-1): Emotional intelligence and warmth

## Evolution System

No XP grinding - evolution happens through:
- **Conversation Depth**: 5+ deep conversations (complexity > 0.7)
- **Novelty**: Average novelty score > 0.5
- **Self-Reflection**: Agent recognizes growth
- **Collaborative**: OpenClaw requests, CloudToLocalLLM validates

## Architecture

```
OpenClaw Gateway              Drift Database              CloudToLocalLLM
     │                              │                              │
     ├─── owns personality ─────────┤                              │
     │                              │                              │
     │<──── provides awareness ──────┼────────────────────────────┤
     │                              │                              │
     └─── requests evolution ────────┼── validates ────────────────>│
```

## Data Storage

- **Primary**: Drift database on VPS (via Tailscale)
- **Backup**: Markdown files in `~/.openclaw/skills/cloudtolocallm/`
- **Fallback**: Markdown files when database unavailable

## API Endpoints

### Get Avatar State
```bash
GET http://localhost:1337/avatar/state
```

### Update Personality Traits
```bash
POST http://localhost:1337/avatar/traits
Content-Type: application/json

{
  "traits": {
    "formality": 0.7,
    "humor": 0.4,
    "enthusiasm": 0.8,
    "empathy": 0.9
  }
}
```

### Request Evolution (OpenClaw → CloudToLocalLLM)
```bash
POST http://localhost:1337/avatar/evolution/request
Content-Type: application/json

{
  "requestedStage": "stage1",
  "reason": "self_reflection",
  "context": "Deep conversations about philosophy"
}
```

## Testing

```bash
# Run unit tests
flutter test test/services/avatar/

# Run integration tests
flutter test test/integration/evolution_flow_test.dart

# Run all tests
flutter test
```

## Documentation

- **Design**: `docs/plans/2026-02-22-avatar-personality-engine-design.md`
- **Implementation**: `docs/plans/2026-02-22-avatar-personality-engine-implementation.md`
- **System Architecture**: `docs/architecture/SYSTEM_ARCHITECTURE.md`

## Troubleshooting

**Skill not loading**:
- Check OpenClaw logs: `openclaw logs`
- Verify skill directory: `ls ~/.openclaw/skills/cloudtolocallm/`

**Database connection failed**:
- Verify Tailscale connection: `tailscale status`
- Check database path: `~/.local/share/CloudToLocalLLM/local_brain.db`

**Evolution not triggering**:
- Check depth metrics in database
- Verify you have 5+ deep conversations
- Check evolution validation criteria

## License

MIT
EOF
```

**Step 2: Commit**

```bash
git add docs/avatar/README.md
git commit -m "docs: add Avatar Personality Engine README

- Quick start guide
- Personality traits description
- Evolution system overview
- Architecture diagram
- API endpoint documentation
- Testing instructions
- Troubleshooting guide
"
```

---

## Summary

**Total Implementation Time**: ~42 hours

**Completed Features**:
- ✅ Database schema (avatar_profiles, evolution_history, conversation_depth_metrics)
- ✅ PersonalityEngine service (CRUD, markdown sync, evolution validation)
- ✅ EvolutionTracker service (depth analysis, pattern detection)
- ✅ Avatar widget with personality-driven visuals
- ✅ OpenClaw skill (TypeScript, personality injection, self-reflection)
- ✅ Evolution API endpoints (GET/POST /avatar/*)
- ✅ Integration tests
- ✅ Documentation

**Next Steps** (Phase 3 of main plan):
- Rive animations
- Emoji blending fallback
- Avatar settings UI
- Advanced visual polish

**See Also**:
- Design document: `docs/plans/2026-02-22-avatar-personality-engine-design.md`
- Implementation plan: `docs/development/IMPLEMENTATION_PLAN.md`
- Avatar README: `docs/avatar/README.md`
