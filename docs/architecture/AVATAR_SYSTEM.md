# Avatar And Voice Companion Architecture

The avatar is the companion surface for the secure agent channel. It provides persistent personality, evolution state, long-term memory, visual presence, and voice conversation.

Voice belongs with the avatar companion. It should not be treated as a separate standalone feature. The intended UX is a sidecar avatar/voice window that can stay open beside the user's desktop while the main app remains a simple secure channel and control center.

## Current Status

The core avatar system is implemented. It uses Drift/SQLite through `LocalBrain`, service classes under `lib/services/avatar/`, UI under `lib/features/avatar/` and `lib/screens/avatar/`, and a TypeScript OpenClaw skill under `services/openclaw-skills/cloudtolocallm/`.

The voice companion foundation is implemented under `lib/services/voice/` and `lib/widgets/voice/`. It currently tracks conversation mode, Hermes bridge status, TTS output, and companion status panels. A full microphone/STT/barge-in path is still planned.

The old XP/achievement design is not the current implementation. Current evolution is based on conversation depth, novelty, and collaborative approval.

## Current Components

| Component | Status | File |
| --- | --- | --- |
| Avatar renderer | Implemented | `lib/features/avatar/avatar_widget.dart` |
| Avatar state service | Implemented | `lib/services/avatar/avatar_state_service.dart` |
| Personality engine | Implemented | `lib/services/avatar/personality_engine.dart` |
| Evolution tracker | Implemented | `lib/services/avatar/evolution_tracker.dart` |
| Memory service | Implemented | `lib/services/avatar/memory_service.dart` |
| Markdown sync | Implemented | `lib/services/avatar/markdown_sync_service.dart` |
| Voice conversation state | Implemented | `lib/services/voice/voice_conversation_service.dart` |
| Hermes voice bridge | Implemented | `lib/services/voice/hermes_voice_bridge_service.dart` |
| Local TTS foundation | Implemented | `lib/services/voice/cloud_tts_service.dart` |
| Voice status/control UI | Implemented | `lib/widgets/voice/` |
| Customization UI | Implemented | `lib/screens/avatar/avatar_customization_screen.dart` |
| OpenClaw skill | Implemented | `services/openclaw-skills/cloudtolocallm/SKILL.md` |
| Pop-out avatar/voice sidecar | Planned | Build on popout/window services |
| Real microphone/STT path | Planned | Not present |
| Achievement service/UI | Planned | Not present |

## Data Model

Avatar data lives in `lib/database/drift_local_brain.dart`.

Important tables and concepts:

- Avatar profile: agent name, personality traits, evolution stage, conversation count, depth score.
- Evolution history: stage transitions, trigger reasons, confirmation source.
- Conversation depth metrics: complexity, emotional signal, novelty, topic extraction.
- Conversation memories: summarized conversation content and optional embedding JSON.

After changing any Drift table or query definitions, regenerate code with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Personality

`PersonalityEngine` reads and updates avatar traits through `LocalBrain`. Current traits are defined in `lib/models/avatar/personality_models.dart`.

Implemented evolution stages:

- `curious_explorer`
- `knowledge_seeker`
- `wise_companion`
- `enlightened_guide`

Evolution is approved only when the requested stage is valid and conversation metrics meet the depth/novelty thresholds.

## Evolution

`EvolutionTracker` analyzes conversations and stores depth metrics. It detects technical terms, emotional markers, and novelty signals so the avatar can evolve organically from conversation quality instead of simple usage counters.

Current evolution flow:

1. Conversation messages are analyzed for complexity, emotion, novelty, and topics.
2. Depth metrics are stored in the local database.
3. `PersonalityEngine.validateEvolutionRequest()` checks whether a requested stage is valid.
4. Approved changes are recorded in evolution history and persisted to the avatar profile.

## Memory

`MemoryService` stores and retrieves long-term avatar memories in `conversation_memories`.

Current behavior:

- Stores memory content, optional summary, and optional embedding JSON.
- Retrieves memories for a conversation.
- Retrieves recent memories.
- Searches memories by content through database queries.

Embedding generation and full semantic vector search are still planned work; the storage shape already allows embedding data.

## Voice Companion

The voice companion is attached to the avatar and the active secure agent channel.

Current foundation:

- `VoiceConversationMode`: idle, listening, engaged, speaking, cooling down.
- Engagement hold window for short natural back-and-forth.
- Direct-address heuristics and fast acknowledgements.
- Hermes bridge polling for external voice reactor state.
- Local OpenAI-compatible TTS route through `/v1/audio/speech`.

Planned path:

1. Pop out the avatar/voice companion as its own sidecar window.
2. Add a desktop microphone streaming adapter.
3. Add VAD and wake/direct-address detection.
4. Add partial transcript updates.
5. Add barge-in and playback interruption.
6. Route lightweight replies locally and escalate deeper turns to Hermes/runtime only when needed.

The companion should show enough state for trust: listening, engaged, speaking, target runtime, and target device where relevant.

## Markdown Sync

`MarkdownSyncService` maintains markdown backup/sync data for avatar state. It has a platform stub so web and desktop builds can compile without direct native filesystem assumptions.

## OpenClaw Skill

The avatar skill package in `services/openclaw-skills/cloudtolocallm/` provides OpenClaw-side personality/evolution integration.

Useful commands:

```bash
cd services/openclaw-skills/cloudtolocallm
npm run build
npm test
```

## Privacy

- Avatar profile, memories, and evolution history are local-first.
- Memory storage is under user control through the local database.
- Markdown sync should not introduce cloud persistence unless explicitly wired through user-approved sync features.

## Planned Work

- Real embedding generation for semantic memory search.
- Achievement service and achievements UI if the product still needs gamified milestones.
- Richer avatar renderer beyond the current widget implementation.
- Pop-out avatar/voice sidecar companion window.
- Real microphone/STT/turn-taking pipeline.
- More explicit privacy controls for memory retention and deletion.

## Related Documentation

- [System Architecture](SYSTEM_ARCHITECTURE.md)
- [Voice Conversation System](VOICE_CONVERSATION_SYSTEM.md)
- [Implementation Plan](../development/IMPLEMENTATION_PLAN.md)
- [Avatar User Documentation](../avatar/README.md)
- [Product Specification](../../SPEC.md)
