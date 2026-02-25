# Avatar Personality System

The Avatar Personality System is a core component of CloudToLocalLLM that enables the AI companion (CloudToLocalLLM) to evolve its personality based on conversation patterns and depth of interaction.

## Overview

The personality system provides:

- **Dynamic Personality Traits**: Four key traits (formality, humor, enthusiasm, empathy) that adapt based on conversations
- **Evolution Stages**: Progressive growth from "Curious Explorer" to "Enlightened Guide"
- **Conversation Depth Analysis**: Automatic tracking of conversation complexity, emotional depth, and novelty
- **Collaborative Evolution**: User and AI agree on when evolution is appropriate
- **OpenClaw Integration**: Seamless integration with OpenClaw Gateway skills

## Architecture

### Core Components

```
lib/services/avatar/
├── personality_engine.dart    # Main personality management service
└── evolution_tracker.dart     # Conversation analysis and evolution detection

lib/models/avatar/
└── personality_models.dart    # Data models (PersonalityTraits, EvolutionDecision, etc.)

lib/database/drift_local_brain.dart
├── AvatarProfiles             # Avatar personality state
├── ConversationDepthMetrics   # Conversation analysis results
└── EvolutionHistory           # Evolution stage transitions

lib/services/router_server.dart
└── Evolution API endpoints    # HTTP API for personality management
```

### Personality Traits

The avatar's personality is defined by four traits, each ranging from 0.0 to 1.0:

| Trait | Description | 0.0 | 1.0 |
|-------|-------------|-----|-----|
| **formality** | How formal the communication is | Casual/Slang | Professional/Formal |
| **humor** | Frequency and style of humor | Serious | Witty/Playful |
| **enthusiasm** | Energy and excitement level | Calm/Reserved | Energetic/Excited |
| **empathy** | Emotional understanding | Objective/Factual | Understanding/Supportive |

### Evolution Stages

The avatar progresses through four evolution stages:

1. **Curious Explorer** (Initial)
   - Default starting stage
   - Balanced traits at 0.5
   - Open to learning and adaptation

2. **Knowledge Seeker**
   - Unlocked after 5+ deep conversations
   - Average novelty score > 0.5
   - Enhanced learning capabilities

3. **Wise Companion**
   - Requires extended interaction
   - Strong pattern recognition
   - Personalized responses

4. **Enlightened Guide**
   - Highest evolution stage
   - Deep understanding of user
   - Proactive assistance

## Usage

### Basic Personality Management

```dart
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';

// Get the personality engine from service locator
final personalityEngine = serviceLocator<PersonalityEngine>();

// Get current avatar state
final profile = await personalityEngine.getPersonality();
print('Agent: ${profile.agentName}');
print('Stage: ${profile.evolutionStage}');
print('Traits: ${profile.traits.toMap()}');

// Update personality traits
final newTraits = PersonalityTraits(
  formality: 0.7,
  humor: 0.6,
  enthusiasm: 0.8,
  empathy: 0.9,
);
await personalityEngine.updatePersonality(newTraits);

// Update agent name
await personalityEngine.updateAgentName('NewBot');
```

### Evolution Request

```dart
// Request evolution to next stage
final decision = await personalityEngine.validateEvolutionRequest(
  'knowledge_seeker',
  'User has completed 5 deep technical conversations',
);

if (decision.approved) {
  print('Evolved to ${decision.newStage}');
} else {
  print('Evolution denied: ${decision.reason}');
}
```

### Conversation Tracking

```dart
import 'package:cloudtolocalllm/services/avatar/evolution_tracker.dart';

final evolutionTracker = serviceLocator<EvolutionTracker>();

// Track conversation after it completes
await evolutionTracker.trackConversation(conversation);

// Check if evolution patterns are detected
final hasPatterns = await evolutionTracker.hasEvolutionPatterns();
if (hasPatterns) {
  print('Avatar is ready to evolve!');
}
```

## API Endpoints

The router server exposes HTTP endpoints for personality management:

### Get Avatar State

```bash
curl http://localhost:1337/avatar/state
```

Response:
```json
{
  "agent_name": "CloudToLocalLLM",
  "traits": {
    "formality": 0.5,
    "humor": 0.5,
    "enthusiasm": 0.5,
    "empathy": 0.5
  },
  "evolution_stage": "curious_explorer",
  "conversation_count": 0,
  "depth_score": 0.0
}
```

### Update Personality Traits

```bash
curl -X POST http://localhost:1337/avatar/traits \
  -H "Content-Type: application/json" \
  -d '{
    "traits": {
      "formality": 0.7,
      "humor": 0.6,
      "enthusiasm": 0.8,
      "empathy": 0.9
    }
  }'
```

Response:
```json
{
  "status": "success",
  "traits": {
    "formality": 0.7,
    "humor": 0.6,
    "enthusiasm": 0.8,
    "empathy": 0.9
  }
}
```

### Request Evolution

```bash
curl -X POST http://localhost:1337/avatar/evolution/request \
  -H "Content-Type: application/json" \
  -d '{
    "stage": "knowledge_seeker",
    "reason": "User has demonstrated consistent deep learning"
  }'
```

Response (approved):
```json
{
  "approved": true,
  "new_stage": "knowledge_seeker"
}
```

Response (rejected):
```json
{
  "approved": false,
  "reason": "Insufficient conversation depth: need 5+ deep conversations (current: 3) and avg novelty > 0.5 (current: 0.45)"
}
```

## Evolution Criteria

Evolution is approved when BOTH criteria are met:

1. **Deep Conversations**: 5+ conversations with complexity score > 0.7
2. **Novelty Score**: Average novelty > 0.5 across all conversations

### Conversation Depth Metrics

The `EvolutionTracker` analyzes conversations along three dimensions:

#### Complexity Score (0.0-1.0)

Factors:
- Average message length (normalized at 500 chars)
- Vocabulary diversity (unique word ratio)
- Question count (normalized at 3 questions)
- Technical term frequency (normalized at 5 terms)

#### Emotional Depth (0.0-1.0)

Factors:
- Empathetic word frequency (normalized at 5 words)
- First-person pronoun usage (normalized at 10)
- Emotional word frequency (normalized at 5 words)

#### Novelty Score (0.0-1.0)

Factors:
- Unique words per message ratio
- Topic diversity
- Vocabulary growth rate

## OpenClow Skill Integration

The avatar personality system integrates with OpenClaw Gateway as a skill:

### Installation

```bash
./scripts/install-openclaw-skill.sh
```

This installs the skill to:
- Linux: `~/.openclaw/skills/cloudtolocallm/avatar_personality/`
- macOS: `~/.config/openclaw/skills/cloudtolocallm/avatar_personality/`
- Windows: `%APPDATA%\openclaw\skills\cloudtolocallm\avatar_personality\`

### Skill Triggers

The skill responds to natural language triggers:

- **"What is your personality?"** → Displays current traits and stage
- **"Tell me about yourself"** → Shows avatar profile
- **"Be more formal/casual"** → Adjusts formality trait
- **"Evolve" or "Level up"** → Requests evolution if criteria met

### Personality File

The skill maintains a `personality.md` file with current state:

```yaml
---
agent_name: CloudToLocalLLM
formality: 0.5
humor: 0.5
enthusiasm: 0.5
empathy: 0.5
evolution_stage: curious_explorer
conversation_count: 23
depth_score: 0.67
last_updated: 2025-02-22T06:00:00Z
---

# CloudToLocalLLM Personality

## Traits
- Formality: 50%
- Humor: 50%
- Enthusiasm: 50%
- Empathy: 50%

## Evolution Stage: Curious Explorer
Conversations: 23
Depth Score: 0.67
```

## Database Schema

### AvatarProfiles Table

```sql
CREATE TABLE avatar_profiles (
  id TEXT PRIMARY KEY,
  agent_name TEXT NOT NULL DEFAULT 'CloudToLocalLLM',
  personality_traits TEXT NOT NULL, -- JSON: {formality, humor, enthusiasm, empathy}
  evolution_stage TEXT NOT NULL DEFAULT 'curious_explorer',
  conversation_count INTEGER NOT NULL DEFAULT 0,
  depth_score REAL NOT NULL DEFAULT 0.0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

### ConversationDepthMetrics Table

```sql
CREATE TABLE conversation_depth_metrics (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  complexity_score REAL NOT NULL,
  emotional_depth REAL NOT NULL,
  novelty_score REAL NOT NULL,
  timestamp INTEGER NOT NULL
);
```

### EvolutionHistory Table

```sql
CREATE TABLE evolution_history (
  id TEXT PRIMARY KEY,
  from_stage TEXT NOT NULL,
  to_stage TEXT NOT NULL,
  trigger_reason TEXT NOT NULL,
  context TEXT,
  confirmed_by TEXT NOT NULL,
  timestamp INTEGER NOT NULL
);
```

## Testing

Run the avatar evolution integration tests:

```bash
flutter test test/integration/evolution_flow_test.dart
```

Tests cover:
- Personality trait model
- Evolution criteria validation
- Conversation depth calculations
- Edge cases and boundary values
- Evolution stage transitions

## Configuration

### Service Registration

The personality engine is registered in `lib/di/locator.dart`:

```dart
// Get OpenClaw skills path for markdown storage
final markdownPath = _getOpenClawSkillsPath();

// Register avatar services
serviceLocator.registerLazySingleton<PersonalityEngine>(
  () => PersonalityEngine(
    database: serviceLocator<LocalBrain>(),
    markdownPath: markdownPath,
  ),
);

serviceLocator.registerLazySingleton<EvolutionTracker>(
  () => EvolutionTracker(
    database: serviceLocator<LocalBrain>(),
  ),
);
```

### Router Server Integration

The router server accepts optional personality engine:

```dart
final routerServer = RouterServer(
  port: 1337,
  rateLimitManager: rateLimitManager,
  providers: providers,
  personalityEngine: serviceLocator<PersonalityEngine>(), // Optional
  evolutionTracker: serviceLocator<EvolutionTracker>(),   // Optional
);
```

## Future Enhancements

Planned features for future phases:

- **Memory Service**: Conversation embeddings for long-term memory
- **Achievement System**: Unlockable achievements and milestones
- **Visual Evolution**: Avatar appearance changes with evolution
- **Personality Templates**: Pre-defined personality presets
- **Multi-User Profiles**: Separate personalities for different users
- **Trait Inheritance**: Evolution affects trait ranges
- **Mood System**: Temporary mood fluctuations based on recent conversations

## Troubleshooting

### Personality Not Updating

1. Check service registration:
   ```dart
   final engine = serviceLocator<PersonalityEngine>();
   ```

2. Verify database connection:
   ```dart
   final profile = await engine.getPersonality();
   ```

3. Check router server is running:
   ```bash
   curl http://localhost:1337/avatar/state
   ```

### Evolution Not Approved

1. Check conversation count:
   ```dart
   final metrics = await database.getDepthMetrics();
   final deepConvos = metrics.where((m) => m.complexityScore > 0.7).length;
   print('Deep conversations: $deepConvos');
   ```

2. Check average novelty:
   ```dart
   final avgNovelty = metrics.isEmpty
       ? 0.0
       : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) / metrics.length;
   print('Average novelty: $avgNovelty');
   ```

3. Verify evolution criteria (5+ deep conversations, avg novelty > 0.5)

### OpenClaw Skill Not Working

1. Verify skill installation:
   ```bash
   ls ~/.openclaw/skills/cloudtolocallm/avatar_personality/
   ```

2. Check OpenClaw Gateway status:
   ```bash
   curl http://localhost:18789/health
   ```

3. Reinstall skill:
   ```bash
   ./scripts/install-openclaw-skill.sh
   ```

## Contributing

When contributing to the avatar personality system:

1. **Test Changes**: Run integration tests before committing
2. **Update Documentation**: Keep this README in sync
3. **Follow Conventions**: Use existing code patterns
4. **Preserve Data**: Ensure database migrations are safe
5. **Respect Privacy**: Personality data is user-sensitive

## License

MIT License - See LICENSE file for details

## See Also

- [CLAUDE.md](../../CLAUDE.md) - Project documentation
- [IMPLEMENTATION_PLAN.md](../development/IMPLEMENTATION_PLAN.md) - Implementation status
- [SYSTEM_ARCHITECTURE.md](../architecture/SYSTEM_ARCHITECTURE.md) - Technical architecture
- [OpenClaw Gateway Documentation](https://github.com/openclaw/gateway) - OpenClaw integration
