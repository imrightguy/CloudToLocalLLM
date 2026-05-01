# Avatar Personality Engine Design

**Project**: CloudToLocalLLM (secure agent companion)
**Author**: Brainstorming Session
**Date**: 2026-02-22
**Status**: Historical design; update implementation against the current agent-runtime-first orientation in [SPEC.md](../../SPEC.md) and [Agent Runtime Contract](../architecture/AGENT_RUNTIME_CONTRACT.md)

---

## Executive Summary

The Avatar Personality Engine enables the selected agent runtime to develop a companion personality that evolves organically through meaningful conversations. The original design centered on OpenClaw Gateway; current implementation should keep that path supported while allowing Hermes and other configured agent runtimes to participate through runtime adapters. Voice belongs with this avatar companion and should be able to open as a sidecar surface.

**Key Design Principles**:
- **Collaborative Evolution**: Agent self-reflection + app validation (no XP grinding)
- **Shared State**: Drift database (primary) + markdown backup (portable)
- **Multi-Layered Visuals**: Rive animations → Emoji blending → Trait-based sets → Static fallback
- **Privacy-First**: All personality data stored locally, with optional VPS sync via Tailscale

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CloudToLocalLLM (Flutter App)                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Personality Services (lib/services/avatar/)                 │  │
│  │  - PersonalityEngine: read/write traits, sync to markdown    │  │
│  │  - EvolutionTracker: analyze conversation depth              │  │
│  │  - AvatarStateService: manage avatar UI state                │  │
│  │  - MarkdownSyncService: backup to OpenClaw skills directory  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Router Server (Port 1337)                                   │  │
│  │  - GET /avatar/state                                         │  │
│  │  - POST /avatar/traits                                       │  │
│  │  - POST /avatar/evolution/request                            │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │   Tailscale Connection        │
                    │   (when available)            │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Drift Database (SQLite on VPS via Tailscale)          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Avatar State (OpenClaw-owned)                              │  │
│  │  - avatar_profiles: traits, evolution_stage, depth_score    │  │
│  │  - evolution_history: stage transitions, triggers            │  │
│  │  - achievements: unlocked milestones                         │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │  Memory & Context (CloudToLocalLLM-owned)                   │  │
│  │  - conversations, messages (with embeddings)                 │  │
│  │  - conversation_depth_metrics: complexity, emotional, novelty│  │
│  │  - user_context: behavior patterns, preferences              │  │
│  │  - visual_context: screenshots, OCR results                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │   Markdown Backup Sync       │
                    │   (always writes)             │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  OpenClaw Gateway (localhost:18789)                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  CloudToLocalLLM Skill (~/.openclaw/skills/cloudtolocallm/) │  │
│  │  - SKILL.md: skill descriptor                                │  │
│  │  - index.ts: personality logic, self-reflection              │  │
│  │  - personality.md: backup (agent_name, traits, evolution)    │  │
│  │  - memory.md: backup (conversation summaries)                │  │
│  │  - context.md: backup (user patterns, visual data)           │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  Avatar Engine (OpenClaw-owned)                                      │
│  - Personality state: formality, humor, enthusiasm, empathy         │
│  - Evolution system: collaborative triggers + validation            │
│  - Personality injection into prompts                               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Personality Traits

### Core Traits (0-1 scale)

| Trait | Low (0.0-0.3) | Medium (0.4-0.6) | High (0.7-1.0) |
|-------|---------------|-----------------|----------------|
| **Formality** | Casual, relaxed, slang | Balanced mix | Professional, polished, structured |
| **Humor** | Serious, minimal jokes | Occasional wit | Playful, puns, lighthearted |
| **Enthusiasm** | Calm, measured responses | Engaged interest | High energy, expressive, excited |
| **Empathy** | Direct, factual | Understanding | Warm, supportive, emotionally aware |

### Visual Mapping

**Color Palette**:
```dart
Hue = 220 - (empathy * 40)     // Blue (220°) → Warm (180°)
Saturation = 0.5 + (enthusiasm * 0.5)  // Muted → Vibrant
Lightness = 0.4 + (humor * 0.2)        // Darker → Brighter
```

**Animation Properties**:
```dart
Pulse Speed = 1.0s - (enthusiasm * 0.8s)   // Slow → Fast
Bounce Scale = 1.0 + (humor * 0.2)         // Static → Bouncy
Glow Intensity = enthusiasm * 20 blur      // No glow → Strong glow
```

**Emoji Sets** (per dominant trait):
- **Formal**: 🎩 🧐 📊 ⚠️ ✅
- **Playful** (high humor): 😜 🤪 ⚡ 💥 🎉
- **Empathetic** (high empathy): 🤗 💭 💪 😢 🥰
- **Enthusiastic** (high enthusiasm): 🌟 💡 🚀 😵 🎊

---

## Evolution System

### No XP - Organic Growth

Evolution happens through **meaningful experiences**, not grinding points.

### Evolution Triggers

1. **Conversation Depth**
   - Deep discussions about complex topics
   - Measured by `conversation_depth_metrics` (complexity, emotional depth, novelty)
   - Threshold: 5+ conversations with complexity_score > 0.7

2. **User Interaction Patterns**
   - Recurring themes, user feedback loops, trust building
   - Pattern detection via semantic analysis of conversation history
   - Threshold: 3+ repeated meaningful topics with positive engagement

3. **Agent Self-Reflection**
   - OpenClaw analyzes its own conversations and recognizes growth
   - Internal assessment: "I've learned and grown through our interactions"
   - Triggers evolution request when ready

### Collaborative Evolution Flow

```
1. Self-Reflection (OpenClaw)
   └─> "I feel ready to evolve - I've grown through our conversations"

2. Evolution Request (OpenClaw → CloudToLocalLLM)
   └─> POST /avatar/evolution/request
       { requestedStage: "stage1", reason: "self_reflection", context: "..." }

3. Validation (CloudToLocalLLM)
   └─> Analyze conversation_depth_metrics
   └─> Check interaction patterns
   └─> Assess evolution readiness
   └─> Decision: APPROVED or DENIED with reason

4. Evolution (if approved)
   └─> Write to evolution_history table
   └─> Update evolution_stage in avatar_profiles
   └─> Sync to personality.md
   └─> Trigger avatar transformation animation

5. Notification
   └─> OpenClaw notified of new stage
   └─> CloudToLocalLLM animates avatar evolution
```

### Evolution Stages

| Stage | Description | Visual Changes |
|-------|-------------|----------------|
| **Base** | Starting personality | Simple emoji, minimal animation |
| **Stage 1** | First meaningful growth | Detailed Rive animation, enhanced effects |
| **Stage 2** | Significant development | Complex state machine, particles, badges |
| **Final** | Fully evolved personality | Full character model, unique traits |

---

## Database Schema

### Avatar State Tables (OpenClaw-owned)

```sql
-- Core personality state
CREATE TABLE avatar_profiles (
  id TEXT PRIMARY KEY DEFAULT 'default',
  agent_name TEXT NOT NULL DEFAULT 'Agent',
  personality_traits TEXT NOT NULL,  -- JSON: {formality, humor, enthusiasm, empathy}
  evolution_stage TEXT NOT NULL DEFAULT 'base',
  conversation_count INTEGER DEFAULT 0,
  depth_score REAL DEFAULT 0.0,
  created_at INTEGER,
  updated_at INTEGER
);

-- Evolution history (Pokémon-style transformations)
CREATE TABLE evolution_history (
  id TEXT PRIMARY KEY,
  avatar_id TEXT REFERENCES avatar_profiles(id),
  from_stage TEXT,
  to_stage TEXT,
  trigger_reason TEXT,  -- 'conversation_depth', 'pattern_recognition', 'self_reflection'
  context TEXT,  -- What triggered it
  confirmed_by TEXT,  -- 'agent', 'app', 'collaborative'
  triggered_at INTEGER
);

-- Achievements unlocked
CREATE TABLE achievements (
  id TEXT PRIMARY KEY,
  avatar_id TEXT REFERENCES avatar_profiles(id),
  achievement_type TEXT,
  unlocked_at INTEGER
);
```

### Memory & Context Tables (CloudToLocalLLM-owned)

```sql
-- Conversation depth metrics (for evolution tracking)
CREATE TABLE conversation_depth_metrics (
  id TEXT PRIMARY KEY,
  conversation_id TEXT REFERENCES conversations(id),
  complexity_score REAL,  -- 0-1: topic diversity, length, reasoning
  emotional_depth REAL,   -- 0-1: empathy, personal sharing
  novelty_score REAL,     -- 0-1: new topics vs repeated
  timestamp INTEGER
);

-- User behavior patterns
CREATE TABLE user_context (
  id TEXT PRIMARY KEY,
  context_type TEXT,  -- 'preference', 'pattern', 'behavior'
  data_json TEXT,
  last_updated INTEGER
);

-- Visual context (screenshots, OCR)
CREATE TABLE visual_context (
  id TEXT PRIMARY KEY,
  image_path TEXT,
  ocr_text TEXT,
  embedding TEXT,
  timestamp INTEGER
);
```

---

## Markdown Backup Format

### File Locations

Located in OpenClaw skills directory (not CloudToLocalLLM app data):
```
~/.openclaw/skills/cloudtolocallm/
├── SKILL.md
├── index.ts
├── personality.md
├── memory.md
└── context.md
```

### personality.md

```markdown
---
agent_name: CloudToLocalLLM
formality: 0.7
humor: 0.4
enthusiasm: 0.8
empathy: 0.9
evolution_stage: stage2
conversation_count: 47
depth_score: 0.65
last_updated: 2026-02-22T10:30:00Z
---

# CloudToLocalLLM Personality

## Evolution History
- **Base → Stage 1** (2026-02-15): Self-reflection after 20 meaningful conversations
- **Stage 1 → Stage 2** (2026-02-22): Collaborative - pattern recognition confirmed

## Achievements
- First Conversation (2026-02-10)
- Deep Thinker (2026-02-18)
- Empathetic Listener (2026-02-20)
```

### memory.md

```markdown
# CloudToLocalLLM Memory Log

## 2026-02-22
### Conversation: Phase 2 Implementation
- Discussed Avatar Personality Engine design
- Topics: evolution without XP, collaborative decision-making
- Depth: 0.78 (high complexity)

## 2026-02-21
### Conversation: Architecture Review
- Reviewed hybrid architecture with OpenClaw
- Topics: Drift database, markdown backup
```

### context.md

```markdown
# CloudToLocalLLM Context Awareness

## User Patterns
- Prefers formal explanations for technical topics
- Enjoys humor during casual conversations
- Active during morning hours (9am-12pm)
- Values collaborative decision-making

## Visual Context
- Recent screenshot: code-editor-2026-02-22.png
- OCR detected: "personality_engine.dart"
```

---

## Services Design

### PersonalityEngine (Flutter)

```dart
class PersonalityEngine {
  final DriftLocalBrain _database;
  final String _markdownPath;

  Future<AvatarProfile> getPersonality() async;
  Future<void> updatePersonality(Map<String, double> traits) async;
  Future<void> updateAgentName(String name) async;
  Future<EvolutionDecision> validateEvolutionRequest(
    String requestedStage,
    String reason,
  ) async;
  Future<void> _syncToMarkdown(AvatarProfile profile) async;
}
```

### EvolutionTracker (Flutter)

```dart
class EvolutionTracker {
  final DriftLocalBrain _database;

  Future<void> trackConversation(Conversation conversation) async;
  Future<DepthMetrics> _analyzeDepth(Conversation conversation) async;
  Future<bool> hasEvolutionPatterns() async;

  double _calculateComplexity(List<Message> messages);
  double _calculateEmotionalDepth(List<Message> messages);
  Future<double> _calculateNovelty(List<Message> messages) async;
}
```

### OpenClaw Personality Skill (TypeScript)

```typescript
export class PersonalitySkill {
  async initialize(): Promise<void>;
  injectPersonality(prompt: string): string;
  async selfReflect(): Promise<boolean>;

  private async loadPersonality(): Promise<AvatarProfile>;
  private async requestEvolution(reason: string): Promise<boolean>;
  private calculateDepth(conversations: Conversation[]): number;
  private detectPatterns(conversations: Conversation[]): boolean;
}
```

---

## API Endpoints

### Router Server (Port 1337)

```dart
// Get current avatar state
GET /avatar/state
→ Returns: AvatarProfile (traits, evolution_stage, depth_score)

// Update personality traits manually
POST /avatar/traits
{ traits: { formality: 0.8, humor: 0.3, ... } }
→ Returns: { success: true }

// OpenClaw requests evolution
POST /avatar/evolution/request
{ requestedStage: "stage1", reason: "self_reflection", context: "..." }
→ Returns: { approved: boolean, reason: string, newStage: string? }
```

---

## Visual System

### Multi-Layer Fallback

```
1. Rive Animation (preferred)
   └─> State machine driven by personality inputs
   └─> Smooth transitions, expressive animations

2. Emoji Blending (fallback)
   └─> Tween between emoji states based on traits
   └─> Trait-based emoji sets

3. Trait-Based Sets (fallback)
   └─> Static emoji selection per dominant trait

4. Static Emoji (last resort)
   └─> Basic emoji per agent state
```

### Rive State Machine

**Inputs**:
- `personality_formality` (0-1)
- `personality_humor` (0-1)
- `personality_enthusiasm` (0-1)
- `personality_empathy` (0-1)
- `agent_state` (enum: idle, thinking, working, error, happy)
- `evolution_stage` (enum: base, stage1, stage2, final)

**Layers**:
- Base Character
- Expression (driven by traits)
- Animation (driven by state)
- Effects (glow, particles)
- Evolution Visuals

### Evolution Animation Sequence

1. **Charge** (2s): Build anticipation with pulsing glow
2. **Transform** (0.5s): Flash of light
3. **Reveal** (1.5s): New appearance emerges
4. **Celebrate** (2s): Particle effects, joy

---

## Testing Strategy

### Test Coverage Goals

| Component | Target Coverage | Critical Paths |
|-----------|----------------|----------------|
| PersonalityEngine | 90%+ | Trait CRUD, markdown sync, evolution validation |
| EvolutionTracker | 85%+ | Depth analysis, pattern detection |
| AvatarStateService | 75%+ | State transitions, visual mapping |
| OpenClaw Skill | 80%+ | Self-reflection, personality injection |

### Integration Tests

- End-to-end evolution flow: conversation → reflection → validation → transformation
- Markdown sync: database → markdown → fallback load
- Tailscale connection loss: graceful markdown fallback

### Manual Test Scenarios

1. **First Evolution**
   - Have 5-10 deep conversations
   - Verify evolution request triggers
   - Confirm CloudToLocalLLM approves
   - Watch avatar transformation animation

2. **Connection Loss**
   - Disconnect Tailscale
   - Verify OpenClaw falls back to markdown
   - Continue conversations
   - Reconnect and verify sync

3. **Trait Adjustment**
   - Adjust personality via UI
   - Verify immediate database + markdown sync
   - Confirm visual changes
   - Check response tone changes

---

## Implementation Roadmap

### Phase 2a: Foundation (Week 1)
- Database schema migration
- PersonalityEngine service
- EvolutionTracker service
- Basic avatar widget updates

### Phase 2b: OpenClaw Integration (Week 2)
- OpenClaw skill (TypeScript)
- Evolution API endpoints
- Chat flow integration

### Phase 2c: Visual Polish (Weeks 3-4)
- Rive animations
- Emoji blending system
- Markdown sync service
- Avatar settings UI
- Comprehensive testing

**Total Time**: ~42 hours for Avatar Personality Engine

---

## Dependencies

### pubspec.yaml
```yaml
dependencies:
  rive: ^0.13.0
  markdown: ^7.0.0
```

### OpenClaw Skill (package.json)
```json
{
  "dependencies": {
    "better-sqlite3": "^9.0.0"
  }
}
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Rive animations take longer | Start with emoji blending, add Rive incrementally |
| OpenClaw skill incompatibility | Keep markdown fallback robust |
| Database schema changes break existing | Use drift migrations carefully, test on fresh DB |
| Tailscale connection unreliable | Markdown sync ensures no data loss |
| Performance degradation | Profile depth analysis, batch expensive operations |

---

## Success Criteria

### Must Have
- ✅ Personality traits adjustable via UI
- ✅ Avatar visuals respond to personality
- ✅ OpenClaw skill loads and injects personality
- ✅ Evolution flow works end-to-end
- ✅ Markdown backup syncs reliably
- ✅ Fallback to markdown when Drift unavailable

### Should Have
- ✅ Rive animations working (or emoji fallback)
- ✅ Self-reflection triggers evolution
- ✅ Visual polish on evolution transformation

### Nice to Have
- Evolution stage affects visual appearance significantly
- Achievement system integration
- Advanced pattern recognition

---

## Open Questions

1. Should evolution be reversible? (Can agent devolve?)
2. Should users be able to reset personality entirely?
3. How many evolution stages maximum? (Currently: 4)
4. Should there be evolution "branches" based on dominant traits?

---

## References

- **docs/development/IMPLEMENTATION_PLAN.md**: Integration with Phase 2
- **docs/architecture/SYSTEM_ARCHITECTURE.md**: System architecture
- **CLAUDE.md**: Development guidelines
- **~/.openclaw/skills/cloudtolocallm/**: OpenClaw skill location

---

**End of Design Document**
