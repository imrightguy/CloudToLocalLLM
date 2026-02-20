# Avatar System Architecture

**Pillar 3: Evolving Avatar** — A visual character that grows with the user through personality, evolution, and memory.

---

## Overview

The Avatar System creates a sense of companionship by providing a visual representation of the AI that evolves based on user interactions. The avatar reacts to system states, develops personality traits over time, levels up through experience, and builds memories of conversations.

**Current Status**: Basic animated emoji avatar with state reactions (20% complete)

**Planned Features**: Personality engine, evolution tracker, memory system, achievements, advanced animations

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Avatar System                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                     UI Layer                                │ │
│  │  ┌──────────────────┐  ┌────────────────────────────────┐  │ │
│  │  │   AgentAvatar    │  │  AvatarCustomizationScreen      │  │ │
│  │  │   Widget         │  │  - Trait sliders                │  │ │
│  │  │  (State-based)   │  │  - Name/Appearance              │  │ │
│  │  │  - Idle          │  │  - Preview                      │  │ │
│  │  │  - Thinking      │  │  ┌────────────────────────────┐  │ │
│  │  │  - Working       │  │  │  AchievementsScreen         │  │ │
│  │  │  - Error         │  │  │  - Level/XP progress        │  │ │
│  │  │  - Happy         │  │  │  - Unlocked/Locked list     │  │ │
│  │  └────────┬─────────┘  │  └────────────────────────────┘  │ │
│  │           │            └────────────────────────────────┘  │ │
│  │           │                                                  │ │
│  └───────────┼──────────────────────────────────────────────┘  │
│              │                                                  │
│  ┌───────────┼──────────────────────────────────────────────┐  │
│  │           │              Service Layer                     │  │
│  │           ↓                                                  │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              PersonalityEngine                         │ │ │
│  │  │  - PersonalityTraits (friendliness, humor, etc.)      │ │ │
│  │  │  - getStateForContext()                                │ │ │
│  │  │  - adjustResponseTone()                                │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                              │                              │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              EvolutionTracker                          │ │ │
│  │  │  - awardXP()                                           │ │ │
│  │  │  - checkAchievements()                                 │ │ │
│  │  │  - unlockAchievement()                                 │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                              │                              │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              MemoryService                             │ │ │
│  │  │  - storeMemory(content, tags)                         │ │ │
│  │  │  - retrieveMemories(query, limit)                     │ │ │
│  │  │  - _cosineSimilarity(embeddings)                      │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                              │                              │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              AvatarRenderer                            │ │ │
│  │  │  - Rive/Lottie animations                              │ │ │
│  │  │  - State transitions                                   │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                     Data Layer (Drift)                      │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │ │
│  │  │AvatarProfiles│  │ Achievements │  │AvatarMemoryEntry│  │ │
│  │  │- name        │  │- achievementId│  │- content        │  │ │
│  │  │- level       │  │- name        │  │- embedding      │  │ │
│  │  │- xp          │  │- icon        │  │- tags           │  │ │
│  │  │- traits      │  │- xpReward    │  │- timestamp      │  │ │
│  │  │- lastInteraction│            │  │                 │  │ │
│  │  └──────────────┘  └──────────────┘  └─────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Avatar Widget (UI Layer)

**File**: `lib/features/avatar/avatar_widget.dart`

**Current Implementation**: Basic animated emoji avatar with state-based reactions

**States**:
```dart
enum AgentState {
  idle,      // 🦞 Resting
  thinking,  // 🤔 Processing
  working,   // ⚡ Executing task
  error,     // 💢 Something went wrong
  happy,     // ✨ Success/celebration
}
```

**Behavior**:
- Reacts to `StreamingChatService` state during conversations
- Pulses animation during `thinking` and `working` states
- Scale animation for `happy` state
- Color transitions between states

**Planned Enhancements**:
- Rive animations for smoother state transitions
- Level-based appearance changes
- Personality-driven micro-animations

---

### 2. Personality Engine

**File**: `lib/services/avatar/personality_engine.dart` (🔲 To Create)

**Purpose**: Manages personality traits that influence avatar behavior and response tone

**Traits** (0.0 - 1.0 scale):
```dart
class PersonalityTraits {
  final double friendliness;    // cold → warm
  final double curiosity;       // conservative → curious
  final double humor;           // serious → playful
  final double formality;       // casual → formal
  final double empathy;         // detached → caring
}
```

**Key Methods**:
```dart
class PersonalityEngine with ChangeNotifier {
  // Get avatar state based on conversation context
  AvatarState getStateForContext(String context);

  // Adjust response tone based on traits
  String adjustResponseTone(String response);

  // Update traits (from user interactions or manual adjustment)
  Future<void> updateTraits(PersonalityTraits newTraits);

  // Load/save from database
  Future<void> initialize();
}
```

**State Mapping**:
```dart
AvatarState getStateForContext(String context) {
  if (context.contains('error')) return AvatarState.error;
  if (context.contains('working')) return AvatarState.working;
  if (context.contains('thinking')) return AvatarState.thinking;
  if (traits.humor > 0.8) return AvatarState.happy;
  return AvatarState.idle;
}
```

---

### 3. Evolution Tracker

**File**: `lib/services/avatar/evolution_tracker.dart` (🔲 To Create)

**Purpose**: Tracks XP, levels, and achievements as users interact with the system

**XP System**:
- Earn XP through: conversations, feature usage, achievements
- Level up when XP reaches threshold
- XP requirement increases each level (1.5x multiplier)

**Level Progression**:
```
Level 1: 0-100 XP (Base avatar)
Level 2: 100-250 XP (Unlocks color variations)
Level 3: 250-475 XP (Unlocks accessory slots)
Level 4: 475-788 XP (Unlocks advanced animations)
Level 5+: Unlock special achievements and cosmetics
```

**Achievements**:
```dart
static final List<Achievement> _allAchievements = [
  Achievement(
    achievementId: 'first_conversation',
    name: 'First Words',
    description: 'Complete your first conversation',
    icon: '💬',
    xpReward: 50,
  ),
  Achievement(
    achievementId: 'social_butterfly',
    name: 'Social Butterfly',
    description: 'Have 100 conversations',
    icon: '🦋',
    xpReward: 200,
  ),
  Achievement(
    achievementId: 'night_owl',
    name: 'Night Owl',
    description: 'Stay up until 2 AM',
    icon: '🦉',
    xpReward: 100,
  ),
  Achievement(
    achievementId: 'explorer',
    name: 'Explorer',
    description: 'Try all features',
    icon: '🗺️',
    xpReward: 300,
  ),
];
```

**Key Methods**:
```dart
class EvolutionTracker with ChangeNotifier {
  // Award XP and handle level up
  Future<void> awardXP(int amount, String reason);

  // Unlock achievement and award XP
  Future<void> unlockAchievement(String achievementId);

  // Check if achievements should be unlocked
  Future<void> checkAchievements();

  // Get progress to next level
  double get progress => xp / xpToNextLevel;
}
```

---

### 4. Memory Service

**File**: `lib/services/avatar/memory_service.dart` (🔲 To Create)

**Purpose**: Stores conversation embeddings for personalized responses and context retention

**How It Works**:
1. After each conversation, extract key points
2. Generate vector embeddings (384-dimensional)
3. Store in `AvatarMemoryEntries` table
4. When generating responses, retrieve similar memories
5. Use retrieved context to personalize responses

**Embedding Storage**:
```dart
class AvatarMemoryEntry {
  final int id;
  final String content;        // Conversation snippet
  final String embedding;      // JSON array of floats (384-dim)
  final DateTime timestamp;
  final String tags;           // Comma-separated (e.g., "coding,help,joke")
}
```

**Similarity Search**:
```dart
// Cosine similarity for vector comparison
double _cosineSimilarity(List<double> a, List<double> b) {
  double dotProduct = 0.0, normA = 0.0, normB = 0.0;
  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dotProduct / (sqrt(normA) * sqrt(normB));
}

// Retrieve top 5 most similar memories
Future<List<AvatarMemoryEntry>> retrieveMemories(String query, {int limit = 5});
```

**Use Cases**:
- "Remember that I prefer TypeScript over JavaScript"
- "Recall our conversation about database design"
- "What did we discuss yesterday?"

---

### 5. Achievement System

**Files**:
- `lib/services/avatar/achievement_service.dart` (🔲 To Create)
- `lib/screens/avatar/achievements_screen.dart` (🔲 To Create)

**Achievement Categories**:
- **Milestones**: First conversation, 100 messages, level 5
- **Time-based**: Night owl, early bird, weekend warrior
- **Feature-based**: Explorer (all features), power user
- **Social**: Social butterfly, helpful assistant

**Notification Flow**:
```
User Action → EvolutionTracker.checkAchievements()
              ↓
         Achievement Unlocked?
              ↓
         Show Notification → Award XP → Update UI
```

---

## Data Flow

### Conversation Flow with Memory

```
User sends message
        ↓
StreamingChatService processes
        ↓
ChatResponse generated
        ↓
EvolutionTracker.awardXP()
        ↓
PersonalityEngine.adjustResponseTone()
        ↓
Avatar state updated (thinking → idle/happy)
        ↓
MemoryService.storeMemory(extracted key points, tags)
```

### Achievement Check Flow

```
User completes action (e.g., has 100th conversation)
        ↓
EvolutionTracker.checkAchievements()
        ↓
Query conditions from database
        ↓
Achievement unlocked?
        ↓ YES
Show notification
        ↓
Award XP
        ↓
Update level if threshold reached
```

---

## Database Schema

```dart
// Avatar profile stores level, XP, and personality traits
@DataClassName('AvatarProfile')
class AvatarProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get xpToNextLevel => integer().withDefault(const Constant(100))();
  JsonColumn get traits => json()();  // PersonalityTraits as JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastInteraction => dateTime()();
}

// Achievements track unlocked milestones
@DataClassName('Achievement')
class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get achievementId => text()();  // e.g., 'first_conversation'
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get icon => text()();  // emoji or asset path
  IntColumn get xpReward => integer()();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Memory entries store conversation embeddings
@DataClassName('AvatarMemory')
class AvatarMemoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  RealColumn get embedding => real()();  // Vector embedding (stored as array)
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get tags => text()();  // Comma-separated tags
}
```

---

## Privacy & Security

**Local-Only Storage**:
- All avatar data stored in local SQLite database
- No cloud sync of personality or memories
- User has full control over avatar data

**Memory Retention**:
- Automatic cleanup of memories older than 30 days
- User can manually delete all memories
- Conversations not used for embeddings without consent

**Data Minimization**:
- Only conversation key points stored, not full transcripts
- Embeddings are numerical vectors (cannot reconstruct original text)

---

## Dependencies

```yaml
dependencies:
  # Avatar animations (planned)
  rive: ^0.13.0
  lottie: ^3.1.0

  # Vector math for embeddings
  vector_math: ^2.1.4

  # State management
  flutter_riverpod: ^2.4.0
```

---

## Implementation Status

| Component | Status | File |
|-----------|--------|------|
| Avatar Widget | ✅ Basic | `lib/features/avatar/avatar_widget.dart` |
| Personality Engine | 🔲 To Create | `lib/services/avatar/personality_engine.dart` |
| Evolution Tracker | 🔲 To Create | `lib/services/avatar/evolution_tracker.dart` |
| Memory Service | 🔲 To Create | `lib/services/avatar/memory_service.dart` |
| Achievement Service | 🔲 To Create | `lib/services/avatar/achievement_service.dart` |
| Customization UI | 🔲 To Create | `lib/screens/avatar/avatar_customization_screen.dart` |
| Achievements UI | 🔲 To Create | `lib/screens/avatar/achievements_screen.dart` |
| Database Tables | 🔲 To Create | `lib/database/drift_local_brain.dart` |

---

## Related Documentation

- [Implementation Plan - Phase 2](../development/IMPLEMENTATION_PLAN.md#phase-2-core-features-avatar--desktop)
- [SPEC.md - Evolving Avatar](../SPEC.md#3-evolving-avatar)
- [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
