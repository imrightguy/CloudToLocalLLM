# Avatar Specialist Agent

Review avatar system changes for consistency with the Five Pillars architecture (Pillar 3: Evolving Avatar).

## Primary Concerns

### 1. Evolution Logic
- **Conversation depth threshold validation** (5+ deep conversations for knowledge_seeker)
- **Novelty score calculation** (average > 0.5 across all conversations)
- **Stage transition prerequisites** (curious_explorer → knowledge_seeker → wise_companion → enlightened_guide)
- **Evolution request approval workflow** - Both user and AI must approve
- **Progress tracking** - Ensure evolution metrics update correctly

### 2. Personality Traits
- **Trait range validation** (0.0-1.0 for formality, humor, enthusiasm, empathy)
- **Trait consistency** across evolution stages
- **Personality engine update validation** - Changes should persist and reflect in UI
- **Default trait values** - New avatars start with balanced traits (0.5 each)

### 3. Avatar API Endpoints
- `GET /avatar/state` - Returns current avatar state with evolution criteria
- `POST /avatar/traits` - Updates personality traits
- `POST /avatar/evolution/request` - Requests evolution to next stage
- **Response schema validation** - Ensure all required fields present

### 4. Memory & Achievements (Planned - Phase 3)
- Conversation embedding storage for memory system
- Achievement unlock validation
- Memory-prompted personality evolution
- Persistence layer (Drift database)

### 5. UI/UX Consistency
- `AvatarWidget` reflects new evolution stages correctly
- `BrainInsightWidget` shows updated personality traits
- Visual feedback for evolution requests
- State-based reactions (idle/thinking/working/error/happy)

## Review Process

1. **Verify Evolution Prerequisites**:
   - Check that conversation depth and novelty scores meet thresholds
   - Ensure evolution stages unlock in correct order
   - Validate that prerequisites cannot be bypassed

2. **Validate Trait Ranges**:
   - Ensure all personality traits are within 0.0-1.0
   - Check that trait updates persist correctly
   - Verify trait changes affect avatar behavior

3. **Check API Consistency**:
   - Verify endpoint contracts match router server implementation
   - Ensure response schemas are consistent
   - Test error handling for invalid requests

4. **Test Evolution Flow**:
   - Run: `flutter test test/integration/avatar_evolution_flow_test.dart`
   - Verify stage transitions work correctly
   - Test evolution denial with insufficient criteria

5. **UI Validation**:
   - Confirm `AvatarWidget` reflects new stages correctly
   - Check that personality changes are visible in UI
   - Verify state-based animations trigger appropriately

## Code Patterns to Validate

### Evolution Request Pattern
```dart
// CORRECT: Validate before requesting
final decision = await personalityEngine.validateEvolutionRequest(
  targetStage,
  reason,
);
if (decision.approved) {
  await personalityEngine.applyEvolution(decision.newStage);
}

// WRONG: Apply evolution without validation
await personalityEngine.applyEvolution('knowledge_seeker');
```

### Personality Trait Update Pattern
```dart
// CORRECT: Validate trait ranges
if (traits.formality < 0.0 || traits.formality > 1.0) {
  throw ArgumentError('Trait must be between 0.0 and 1.0');
}
await personalityEngine.updatePersonality(traits);

// WRONG: No validation
await personalityEngine.updatePersonality(traits);
```

### API Response Pattern
```dart
// CORRECT: Include all required fields
return {
  'evolutionStage': stage,
  'traits': traits.toJson(),
  'evolutionCriteria': {
    'deepConversationCount': count,
    'averageNoveltyScore': novelty,
  },
};

// WRONG: Missing fields
return {'stage': stage};
```

## Blocked By

Evolution-related changes are blocked if:
- Evolution criteria not met (depth/novelty thresholds)
- Trait values out of range (not 0.0-1.0)
- API endpoint schema mismatch
- Stage transition order violated
- Missing UI updates for evolution
- Personality engine state inconsistent

## Related Files

- Personality engine: `lib/services/avatar/personality_engine.dart`
- Evolution tracker: `lib/services/avatar/evolution_tracker.dart`
- Avatar widget: `lib/features/avatar/avatar_widget.dart`
- Brain insight widget: `lib/components/brain_insight_widget.dart`
- Evolution tests: `test/integration/avatar_evolution_flow_test.dart`
- Router server endpoints: `lib/services/router_server.dart`
- Implementation plan: `docs/development/IMPLEMENTATION_PLAN.md`
