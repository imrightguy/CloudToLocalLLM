---
name: avatar-evolution
description: Avatar evolution development workflow with personality trait templates, conversation depth validation, and stage transition checklists for CloudToLocalLLM's evolving avatar system (Pillar 3)
user-invocable: true
---

# Avatar Evolution Development

Streamline avatar (Zoidbot) evolution feature development with personality trait templates, conversation depth analysis scripts, and stage transition validation.

## Context

The avatar system (Pillar 3 of CloudToLocalLLM's Five Core Pillars) features an evolving character with:
- **Personality traits** (0.0-1.0 scale): formality, humor, enthusiasm, empathy
- **Evolution stages**: curious_explorer → knowledge_seeker → wise_companion → enlightened_guide
- **Organic growth**: Evolution based on conversation depth and novelty patterns
- **Collaborative approval**: Both user and AI must agree on evolution

### Evolution Criteria

| Stage | Deep Conversations | Avg Novelty | Description |
|-------|-------------------|-------------|-------------|
| curious_explorer | 0 | - | Initial stage for new avatars |
| knowledge_seeker | 5+ | > 0.5 | Unlocks after consistent deep learning |
| wise_companion | 15+ | > 0.6 | Advanced companion with rich context |
| enlightened_guide | 30+ | > 0.7 | Highest evolution stage |

### Key Files

- `lib/services/avatar/personality_engine.dart` - Trait management and evolution validation
- `lib/services/avatar/evolution_tracker.dart` - Conversation depth analysis
- `lib/features/avatar/avatar_widget.dart` - Visual avatar renderer
- `lib/features/avatar/brain_insight_widget.dart` - Personality visualization
- Router API: `GET /avatar/state`, `POST /avatar/traits`, `POST /avatar/evolution/request`

## Quick Start

### Get Current Avatar State
```bash
curl http://localhost:1337/avatar/state | jq '.'
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

### Request Evolution
```bash
curl -X POST http://localhost:1337/avatar/evolution/request \
  -H "Content-Type: application/json" \
  -d '{
    "stage": "knowledge_seeker",
    "reason": "User has completed 5 deep conversations with avg novelty 0.65"
  }'
```

## Templates

### Personality Traits Update Template
Location: `templates/personality_traits.dart`

```dart
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';

/// Update avatar personality traits
///
/// Usage:
/// ```dart
/// final engine = PersonalityEngine();
/// await engine.updatePersonality(PersonalityTraits(
///   formality: 0.7,
///   humor: 0.6,
///   enthusiasm: 0.8,
///   empathy: 0.9,
/// ));
/// ```
Future<void> updateAvatarPersonality() async {
  final engine = PersonalityEngine();

  // Get current personality
  final current = await engine.getPersonality();
  print('Current traits: ${current.traits}');

  // Define new personality traits
  final newTraits = PersonalityTraits(
    formality: 0.7,    // How formal (0.0 = casual, 1.0 = formal)
    humor: 0.6,        // How playful (0.0 = serious, 1.0 = playful)
    enthusiasm: 0.8,   // Energy level (0.0 = calm, 1.0 = enthusiastic)
    empathy: 0.9,      // Emotional warmth (0.0 = direct, 1.0 = empathetic)
  );

  // Validate trait ranges
  if (!_isValidTraitRange(newTraits)) {
    throw ArgumentError('Personality traits must be between 0.0 and 1.0');
  }

  // Update personality
  await engine.updatePersonality(newTraits);
  print('✓ Personality updated');

  // Verify update
  final updated = await engine.getPersonality();
  print('New traits: ${updated.traits}');
}

bool _isValidTraitRange(PersonalityTraits traits) {
  return traits.formality >= 0.0 && traits.formality <= 1.0 &&
         traits.humor >= 0.0 && traits.humor <= 1.0 &&
         traits.enthusiasm >= 0.0 && traits.enthusiasm <= 1.0 &&
         traits.empathy >= 0.0 && traits.empathy <= 1.0;
}
```

### Evolution Request Template
Location: `templates/evolution_request.dart`

```dart
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';

/// Request avatar evolution to the next stage
///
/// Evolution requires meeting conversation depth and novelty criteria.
/// Both user and AI must approve the evolution request.
Future<void> requestAvatarEvolution() async {
  final engine = PersonalityEngine();

  // Get current state
  final currentState = await engine.getPersonality();
  print('Current stage: ${currentState.evolutionStage}');

  // Check evolution prerequisites
  final criteria = await engine.getEvolutionCriteria();
  print('Deep conversations: ${criteria.deepConversationCount}');
  print('Average novelty: ${criteria.averageNoveltyScore}');

  // Define target stage
  const targetStage = 'knowledge_seeker';

  // Provide reasoning for evolution
  const reason = 'User has demonstrated consistent deep learning patterns '
      'with 8 deep conversations and average novelty score of 0.72';

  // Request evolution
  final decision = await engine.validateEvolutionRequest(
    targetStage,
    reason,
  );

  if (decision.approved) {
    print('✓ Evolution approved!');
    print('New stage: ${decision.newStage}');
    print('Reason: ${decision.approvalReason}');

    // Apply evolution
    await engine.applyEvolution(decision.newStage);
    print('✓ Evolution applied');
  } else {
    print('✗ Evolution denied');
    print('Reason: ${decision.denialReason}');
    print('Suggestions: ${decision.suggestions}');
  }
}
```

## Scripts

### Validate Evolution Prerequisites
Location: `scripts/validate-evolution.sh`

```bash
#!/bin/bash
# Validate avatar evolution prerequisites
#
# Usage:
#   ./validate-evolution.sh <target_stage>
#
# Example:
#   ./validate-evolution.sh knowledge_seeker

set -euo pipefail

TARGET_STAGE="${1:-knowledge_seeker}"
ROUTER_URL="${ROUTER_URL:-http://localhost:1337}"

echo "🔍 Avatar Evolution Validation"
echo "==============================="
echo "Target stage: $TARGET_STAGE"
echo ""

# Get current avatar state
echo "Fetching current avatar state..."
state=$(curl -s "$ROUTER_URL/avatar/state")

if ! echo "$state" | jq empty 2>/dev/null; then
  echo "❌ Error: Failed to fetch avatar state"
  echo "Make sure the router server is running on port 1337"
  exit 1
fi

current_stage=$(echo "$state" | jq -r '.evolutionStage')
deep_conversations=$(echo "$state" | jq -r '.evolutionCriteria.deepConversationCount // 0')
avg_novelty=$(echo "$state" | jq -r '.evolutionCriteria.averageNoveltyScore // 0')

echo "Current stage: $current_stage"
echo "Deep conversations: $deep_conversations"
echo "Average novelty: $avg_novelty"
echo ""

# Define stage requirements
declare -A requirements
requirements["knowledge_seeker_deep"]=5
requirements["knowledge_seeker_novelty"]=0.5
requirements["wise_companion_deep"]=15
requirements["wise_companion_novelty"]=0.6
requirements["enlightened_guide_deep"]=30
requirements["enlightened_guide_novelty"]=0.7

# Get requirements for target stage
req_deep_key="${TARGET_STAGE}_deep"
req_novelty_key="${TARGET_STAGE}_novelty"

req_deep=${requirements[$req_deep_key]:-999}
req_novelty=${requirements[$req_novelty_key]:-1.0}

# Validate
echo "Validation for: $TARGET_STAGE"
echo "------------------------------"
echo "Required deep conversations: $req_deep (you have: $deep_conversations)"
echo "Required average novelty: $req_novelty (you have: $avg_novelty)"
echo ""

if [ "$deep_conversations" -ge "$req_deep" ] && \
   (( $(echo "$avg_novelty >= $req_novelty" | bc -l) )); then
  echo "✅ Evolution prerequisites met!"
  echo ""
  echo "You can request evolution with:"
  echo "  curl -X POST $ROUTER_URL/avatar/evolution/request \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"stage\":\"$TARGET_STAGE\",\"reason\":\"Prerequisites met\"}'"
  exit 0
else
  echo "❌ Evolution prerequisites not met"
  echo ""
  if [ "$deep_conversations" -lt "$req_deep" ]; then
    echo "  → Need $((req_deep - deep_conversations)) more deep conversations"
  fi
  if (( $(echo "$avg_novelty < $req_novelty" | bc -l) )); then
    echo "  → Need higher novelty scores (current: $avg_novelty, required: $req_novelty)"
  fi
  exit 1
fi
```

### Test Avatar API Endpoints
Location: `scripts/test-avatar-api.sh`

```bash
#!/bin/bash
# Test avatar API endpoints
#
# Usage: ./test-avatar-api.sh

set -euo pipefail

ROUTER_URL="${ROUTER_URL:-http://localhost:1337}"

echo "🧪 Avatar API Endpoint Tests"
echo "============================="
echo ""

# Test 1: Get avatar state
echo "Test 1: GET /avatar/state"
response=$(curl -s -w "\n%{http_code}" "$ROUTER_URL/avatar/state")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
  echo "✓ PASSED (HTTP $http_code)"
  echo "$body" | jq '.'
else
  echo "✗ FAILED (HTTP $http_code)"
  echo "$body"
fi
echo ""

# Test 2: Update personality traits
echo "Test 2: POST /avatar/traits"
response=$(curl -s -w "\n%{http_code}" -X POST "$ROUTER_URL/avatar/traits" \
  -H "Content-Type: application/json" \
  -d '{"traits":{"formality":0.5,"humor":0.5,"enthusiasm":0.5,"empathy":0.5}}')
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
  echo "✓ PASSED (HTTP $http_code)"
  echo "$body" | jq '.'
else
  echo "✗ FAILED (HTTP $http_code)"
  echo "$body"
fi
echo ""

# Test 3: Request evolution (may fail if prerequisites not met)
echo "Test 3: POST /avatar/evolution/request"
response=$(curl -s -w "\n%{http_code}" -X POST "$ROUTER_URL/avatar/evolution/request" \
  -H "Content-Type: application/json" \
  -d '{"stage":"knowledge_seeker","reason":"Test evolution request"}')
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 400 ]; then
  echo "✓ PASSED (HTTP $http_code)"
  echo "$body" | jq '.'
else
  echo "✗ FAILED (HTTP $http_code)"
  echo "$body"
fi

echo ""
echo "============================="
echo "Tests complete!"
```

## Development Checklist

### Adding New Personality Traits
- [ ] Trait value range validated (0.0-1.0)
- [ ] Trait added to `PersonalityTraits` model
- [ ] Trait included in API endpoint response
- [ ] UI updated to display new trait
- [ ] Evolution logic accounts for new trait
- [ ] Tests updated for new trait

### Implementing Evolution Stages
- [ ] Stage name follows naming convention (lowercase_with_underscores)
- [ ] Evolution criteria defined (deep conversations, novelty threshold)
- [ ] Personality adjustments for stage configured
- [ ] Avatar visual updated for stage (if applicable)
- [ ] API endpoint accepts new stage
- [ ] Evolution request validation includes new stage
- [ ] Tests cover evolution to/from new stage

### Avatar Widget Updates
- [ ] New state visual defined (idle, thinking, working, error, happy)
- [ ] State transitions are smooth
- [ ] Personality traits reflected in appearance
- [ ] Evolution stage visually distinct
- [ ] Widget responds to personality changes
- [ ] Performance tested (60 FPS target)

## Testing

### Run Avatar Evolution Tests
```bash
flutter test test/integration/avatar_evolution_flow_test.dart
```

### Run Personality Engine Tests
```bash
flutter test test/services/avatar/personality_engine_test.dart
```

### Run Evolution Tracker Tests
```bash
flutter test test/services/avatar/evolution_tracker_test.dart
```

### Run Widget Tests
```bash
flutter test test/widgets/avatar_widget_test.dart
```

## Related Files
- Personality engine: `lib/services/avatar/personality_engine.dart`
- Evolution tracker: `lib/services/avatar/evolution_tracker.dart`
- Avatar widget: `lib/features/avatar/avatar_widget.dart`
- Brain insight widget: `lib/components/brain_insight_widget.dart`
- Implementation plan: `docs/development/IMPLEMENTATION_PLAN.md`
- Architecture: `docs/architecture/SYSTEM_ARCHITECTURE.md`
