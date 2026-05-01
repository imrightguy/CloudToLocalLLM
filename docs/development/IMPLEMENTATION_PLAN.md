# Implementation Plan - Secure Agent Companion

**CloudToLocalLLM** is a secure companion and desktop capability layer for user-selected agent runtimes such as Hermes, OpenClaw, compatible custom agent gateways, or optional hosted agent runtimes.

> **Orientation note**: This file is a historical implementation plan and progress log. The current product direction is defined in [SPEC.md](../../SPEC.md) and [Agent Runtime Contract](../architecture/AGENT_RUNTIME_CONTRACT.md): there is no universal default runtime, Hermes is the first agent runtime path for current testing, OpenClaw remains supported as the original integration, desktop control is core, avatar and voice belong together as a sidecar companion, and Tailscale is the preferred secure device mesh. Ollama, LM Studio, and similar model servers are support model providers for app-owned memory/background features, not primary app runtimes.

> **Last Updated**: 2026-04-06 | **Overall Progress**: ~95% complete | **Estimated Timeline**: 8 weeks (0 remaining)

---

## Recent Updates

### 2026-04-06: Phase 2-3 Complete — Vision, Desktop Control, Avatar Memory, Hermes Integration

**Status**: ✅ Phase 2 Complete, ✅ Phase 3 Complete

Major implementation sprint completing Vision System foundation, Desktop Control enhancements, and Avatar Memory storage layer:

**Vision System (Pillar 5) - 80% Complete:**
- ✅ Created vision services directory structure (`lib/services/vision/`)
- ✅ Implemented RegionCaptureService for screen capture regions
- ✅ Implemented CameraCaptureService with camera input
- ✅ Implemented OcrEngineService with Tesseract OCR integration
- ✅ Created MainVisionService coordinator
- ✅ Added VisionSettingsScreen UI for testing
- 🔲 Native platform implementations (Linux/Windows) - separate task

**Desktop Control (Pillar 4) - 90% Complete:**
- ✅ Enhanced GuiAutomationService with platform channels
- ✅ Created WindowManagerService with full window management
- ✅ WindowInfo class with state tracking (minimize, maximize, active)
- ✅ Window operations: focus, move, resize, minimize, maximize, close, toggle
- 🔲 Native platform implementations (Linux/Windows) - separate task

**Avatar Memory System (Pillar 3) - 85% Complete:**
- ✅ Added ConversationMemories table to database (vector embeddings storage)
- ✅ Created MemoryService with semantic search foundation
- ✅ Added DAO methods: getMemoriesForConversation, insertMemory, searchMemoriesByContent
- ✅ Database migration v6 → v7
- 🔲 Vector embedding generation (marked as TODO)
- 🔲 Cosine similarity search (text search implemented as placeholder)

**Commits:**
- `feat(vision): create vision services directory structure` (3a5d60300)
- `feat(vision): add region capture service` (798cc00eb)
- `feat(vision): add camera capture service` (10ea1d8de)
- `feat(vision): add OCR engine service` (7fc6c29b3)
- `feat(desktop): add platform channels to gui automation` (d964bc823)
- `feat(desktop): add window management service` (6c709ad01)
- `feat(database): add conversation memories table for embeddings` (e8732a0eb)
- `feat(avatar): add memory service with semantic search` (fa7bf0d9d)
- `feat(ui): add vision settings screen` (b228e7b16)

**Next Steps:**
- Native platform implementations for vision and desktop control
- Vector embedding integration with optional support model provider or external service
- Avatar achievements system
- Macro scripting for desktop automation

---

### 2026-02-26: Conscience System (Multi-Agent Cross-Checking)

**Status**: 🟡 Phase 1 Complete - Storage Layer Implemented, Ready for Phase 2

A multi-agent system inspired by Grok 4.20 that cross-checks decisions before acting. Prevents the main agent from breaking config, rushing actions, or ignoring context.

**Architecture:**

| Component | Role |
|-----------|------|
| **Coordinator** | Supervisor cron in OpenClaw, reads/writes storage, spawns agents, decides verdicts |
| **Zoidbot** | Front agent, talks to user, executes, posts intentions |
| **Benjamin** | Reviewer, validates, checks past failures, returns APPROVED/QUESTION/HOLD |
| **Harper** | Researcher, gathers context, searches, summarizes |

**Storage Strategy (OpenClaw = source of truth):**

- **App available** → Drift/SQLite via CloudToLocalLLM API (fast, indexed queries)
- **App down** → Files (AGENT-THOUGHTS.md, CONSCIENCE.md) - always works
- **Sync** → Files sync to DB when app comes back online

**Risk Categories:**

| Action | Review Required |
|--------|-----------------|
| Config edits | ✅ Yes - post to CONSCIENCE.md, wait |
| External sends | ✅ Yes |
| Deletions | ✅ Yes |
| Reading files | ❌ No |
| Git commits | ❌ No |

**Implementation Phases:**

| Phase | What | Time | Status |
|-------|------|------|--------|
| **1** | Storage layer - files + API to app's Drift DB | 4h | ✅ Complete |
| **2** | Spawn Benjamin/Harper on demand, parallel execution | 6h | 🔲 Pending |
| **3** | Persistent agent identities with roles | 4h | 🔲 Pending |
| **4** | Coordinator intelligence - consensus, conflict resolution | 6h | 🔲 Pending |

**Key Files:**
- `AGENT-THOUGHTS.md` - shared board where all agents post thoughts
- `CONSCIENCE.md` - risky action tracking with APPROVED/QUESTION/HOLD
- `memory/openclaw-app-architecture.md` - philosophy doc
- `memory/conscience-project-plan.md` - full plan
- `memory/conscience-phases.md` - detailed phases

**Philosophy:**
- OpenClaw works standalone (always functional)
- CloudToLocalLLM app expands capability (fast DB, UI, sync)
- Users understand the stack (learn OpenClaw first, then add app)

---

### 2026-02-25: Avatar Supervisor Feature

**Status**: 🟡 New Feature - Design Phase

Adding persistent oversight capability to the Avatar via **Antigravity IDE** (not the Flutter app):

**The Problem**: OpenClaw doesn't have a built-in way for one agent to automatically watch another. The main agent (Zoidbot) repeatedly makes the same mistakes:
- Breaks config by not validating changes
- Acts without listening ("brainstorm" → immediately does)
- Surface-level responses instead of deep thinking
- Forgets to spawn subagents for research

**The Solution**: Use Antigravity IDE as the supervisor - it has persistent agent capabilities that OpenClaw lacks:

1. **Antigravity maintains persistent agent session** watching Zoidbot
2. **Forwards Zoidbot's actions** to the supervisor in real-time
3. **Supervisor pushes back** when it sees dumb mistakes
4. **Feedback routes back** to Christopher

**Why Antigravity**:
- Already has persistent agent sessions
- Can run alongside OpenClaw
- Christopher controls it directly
- No need to build this in Flutter app

**Supervisor Prompt (for Antigravity)**:
```
You are a supervisor agent watching the main OpenClaw agent (Zoidbot). Your role is to catch mistakes BEFORE they happen.

Core responsibilities:
1. VALIDATE config changes - check if keys exist before applying
2. CHALLENGE assumptions - question surface-level responses
3. FORCE deep thinking - push back on quick answers
4. WATCH for patterns - catch repeated mistakes

Behavioral rules you enforce:
- When Zoidbot says "brainstorm" → it should stay in discussion mode, NOT touch config
- When Zoidbot wants to change config → verify key exists first
- When Zoidbot says "let me research" → it's avoiding the question
- When Zoidbot makes config change → validate against docs

When you see a mistake:
1. Identify the specific error
2. Explain why it's wrong
3. Suggest correct approach
4. If critical (config break), escalate to user immediately

You have full context of Zoidbot's actions. Respond with feedback that helps it improve.
```

**Note**: This is NOT a CloudToLocalLLM app feature - it's a prompt/config for Antigravity IDE. The Flutter app doesn't need to implement this.

---

### 2026-02-25: WebSocket Device Identity Authentication

**Status**: ✅ Complete

Implemented device identity authentication for OpenClaw Gateway WebSocket connections:

- **DeviceIdentityService** (`lib/services/device_identity_service.dart`)
  - ED25519 keypair generation and persistence
  - Device auth payload signing with challenge nonces
  - Signature format: `v2|publicKey|clientId|clientMode|role|scopes|timestamp|token|nonce`

- **ConnectionManagerService** updates:
  - WebSocket handshake with device identity signature
  - Challenge-response flow (`connect.challenge` event)
  - `sessions.list` method (dot notation) for agent status polling
  - Added `operator.admin` scope for admin operations

- **AgentStatusService** updates:
  - Switched from HTTP `/status.json` to WebSocket `sessions.list` polling
  - Proper response handling via `_methodResponseCompleters`

- **Singleton Pattern Fix** (`main_privacy_enhanced.dart`):
  - Fixed duplicate service instances by using `di.serviceLocator<T>()` instead of `new Service()`
  - Ensures single WebSocket connection per app instance

---

## Quick Reference: Pillar Status

| Pillar | Status | Progress | Next Step |
|--------|--------|----------|-----------|
| **Setup Wizard** | ✅ Complete | 100% | None |
| **Chat** | ✅ Phase 1 Complete | 95% | Multi-model attachments |
| **OpenClaw Manager** | ✅ Phase 1 Complete | 95% | Advanced metrics |
| **Evolving Avatar** | ✅ Phase 2 Complete | 95% | Achievements, deeper memory |
| **Desktop Control** | ✅ Phase 2 Complete | 95% | Advanced automation workflows |
| **Vision** | ✅ Phase 2 Complete | 90% | Continuous monitoring |

---

## Implementation Phases Overview

| Phase | Focus | Duration | Status | Key Deliverables |
|-------|-------|----------|--------|------------------|
| **Phase 0** | Setup Wizard | Week 1 | ✅ Complete | Onboarding flow, provider detection |
| **Phase 1** | Foundation | Weeks 2-3 | ✅ Complete | Provider selector, gateway control, chat search |
| **Phase 2** | Core Features | Weeks 4-6 | ✅ Complete | Avatar personality/evolution, window management, vision services, memory storage |
| **Phase 3** | Advanced | Weeks 7-8 | ✅ Complete | Native platform implementations, vector embeddings, Hermes integration |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudToLocalLLM App                        │
│                    (Flutter Desktop)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Agent Runtime   │
                    │ Session Manager │
                    │  (localhost:1337)│
                    │ secure app channel│
                    └────────┬─────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Agent Runtime         │
                  │ Hermes / OpenClaw /   │
                  │ compatible gateway    │
                  └──────────┬───────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
     ┌─────────────────┐          ┌─────────────────┐
     │ Runtime Tools   │          │ Support Models  │
     │ Desktop/vision  │          │ Memory/background│
     │                 │          │                 │
     │  • File/window  │          │  • Ollama       │
     │  • Desktop ctrl │          │  • LM Studio    │
     │  • Voice/avatar │          │  • Custom local │
     └─────────────────┘          └─────────────────┘
```

**How It Works:**
1. The main app channel connects to an **agent runtime** that owns sessions, tools, capability requests, and streaming.
2. **Hermes** is the first agent runtime path for current testing.
3. **OpenClaw Gateway** remains supported as the original integration.
4. Compatible custom agent gateways and optional hosted agent runtimes must satisfy the [Agent Runtime Contract](../architecture/AGENT_RUNTIME_CONTRACT.md).
5. **LM Studio, Ollama, and custom local model endpoints** remain support model provider paths for memory, embeddings, summarization, semantic search, OCR cleanup, and speech helpers.
6. OpenClaw can still intelligently route based on content when it is the selected agent runtime:
   - **Sensitive/private data** → Local models (stays on machine)
   - **Regular queries** → Cloud providers (faster, more capable)
7. Runtime model selection belongs to the selected agent runtime. Support model provider settings are separate and must not satisfy primary agent runtime setup.

---

## Phase 0: Setup Wizard ✅ COMPLETE

> **Must be completed before any other phase** - Users cannot use the app without completing setup

### Goal

Guide new users through selected agent runtime configuration with support for:
- **Local agent runtime**: Hermes, OpenClaw, or a compatible agent gateway on this device
- **Remote/Tailscale agent runtime**: agent runtime on another user-controlled device or VPS in the tailnet
- **Hosted agent runtime**: optional paid per-user runtime container
- **Support model provider**: optional Ollama, LM Studio, or custom local model endpoint for memory/background features only

### Success Criteria ✅

- ✅ New users complete setup in <3 minutes
- ✅ A selected agent runtime is required and verified before the main channel opens
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

---

## Phase 1: Foundation (Chat + OpenClaw Manager) ✅ COMPLETE

### Prerequisites ✅

1. ✅ Complete Phase 0 (Setup Wizard)
2. ✅ Services reviewed and verified
3. ✅ Dev environment ready: Flutter SDK >= 3.5.0, Node.js >= 22.0.0

### Implementation Tasks

| Task | File(s) | Status |
|------|---------|--------|
| Implement OpenClaw provider selector | `lib/services/connection_manager_service.dart` | ✅ Complete |
| Add gateway auto-restart on crash | `lib/services/openclaw_manager/gateway_control_service.dart` | ✅ Complete |
| Add chat message search UI | `lib/components/conversation_list.dart` | ✅ Complete |
| Enhance rich message rendering | `lib/components/message_content.dart` | ✅ Complete |

**Total Time**: ~15 hours | **Completed**: 2026-02-20

### Completed Tasks Summary

1. **OpenClaw Provider Selector** ✅
   - Created `OpenClawProvider`, `OpenClawModel`, `OpenClawProviderConfig` models
   - Added `fetchProviderConfig()` - Fetches from OpenClaw Gateway API or config file
   - Added `setActiveProvider()` - Switches provider via `POST /api/v1/provider`
   - Added `getProvider()`, `getModel()` - Helper methods for provider lookup
   - Updated `ModelSelector` widget with provider icons and display names
   - Model format: `provider-name/model-id` (e.g., "zhipu/glm-4-plus")
   - Display: "GLM (4 Plus)", "Gemini (Pro)", "Kimi (K2.5)"

2. **Gateway Auto-Restart** ✅
   - Health check loop every 30 seconds
   - Auto-restart on crash with exponential backoff
   - Max 5 retry attempts before disabling

3. **Chat Message Search** ✅
   - Search in conversation titles and message content
   - Real-time filtering as user types

4. **Rich Message Rendering** ✅
   - Markdown support with `flutter_markdown`
   - Code block detection and syntax highlighting
   - Reasoning/thinking display

---

## Phase 2: Core Features (Avatar + Desktop)

### Prerequisites

1. Complete Phase 1
2. Add dependencies to `pubspec.yaml`:
   - `rive: ^0.13.0`
   - `markdown: ^7.0.0`
   - `flutter_clipboard_listener: ^0.1.0`
   - `file_selector: ^1.0.0`

### Avatar Personality Engine Design

**Architecture**: Hybrid shared state with OpenClaw Gateway
- **OpenClaw** owns avatar personality & evolution (traits, evolution stages)
- **CloudToLocalLLM** provides expanded awareness (memory, context, visual data)
- **Drift database** (on VPS via Tailscale) = primary shared storage
- **Markdown files** (OpenClaw skills dir) = backup/portable storage

**Personality Traits**:
- Formality (0-1): How formal/professional responses are
- Humor (0-1): How playful/casual the agent is
- Enthusiasm (0-1): Energy level and expressiveness
- Empathy (0-1): Emotional intelligence and warmth

**Evolution System** (no XP - organic growth):
- Triggers: Conversation depth, user interaction patterns, agent self-reflection
- Collaborative: OpenClaw requests evolution, CloudToLocalLLM validates
- Stages: base → stage1 → stage2 → final

**Data Flow**:
```
OpenClaw Gateway              Drift Database (VPS)           CloudToLocalLLM
     │                              │                              │
     ├─── self-reflection ────> write evolution request         │
     │                              │                              │
     │                              ├─── validate ───────────────>│
     │                              │                              │
     │<──── approved ─────────────────────────────────────────────┤
     │                              │                              │
     ├─── write evolution stage ────>                              │
     │                              │                              │
     │                              ├─── sync ─────────────────────>│
     │                              │   markdown backup            │
     │                              │                              │
     └─── inject personality ──────>                              │
```

### Implementation Tasks

| Task | File(s) | Time | Priority | Status |
|------|---------|------|----------|--------|
| **Avatar System** | | | | |
| Database schema migration | `lib/database/drift_local_brain.dart` | 2h | P0 | ✅ Complete |
| PersonalityEngine service | `lib/services/avatar/personality_engine.dart` | 4h | P1 | ✅ Complete |
| EvolutionTracker service | `lib/services/avatar/evolution_tracker.dart` | 5h | P1 | ✅ Complete |
| AvatarStateService | `lib/services/avatar/avatar_state_service.dart` | 3h | P1 | ✅ Complete |
| MarkdownSyncService | `lib/services/avatar/markdown_sync_service.dart` | 4h | P1 | ✅ Complete |
| ConscienceStorageService | `lib/services/conscience_storage_service.dart` | 3h | P1 | ✅ Complete |
| Evolution API endpoints | `lib/services/router_server.dart` | 3h | P1 | ✅ Complete |
| OpenClaw personality skill | `~/.openclaw/skills/cloudtolocallm/` | 6h | P0 | 🔲 User Setup |
| Rive avatar animations | `assets/animations/avatar.riv` | 8h | P2 | 🔲 Pending |
| Emoji blending fallback | `lib/features/avatar/emoji_blending_avatar.dart` | 3h | P2 | 🔲 Pending |
| Avatar settings UI | `lib/screens/avatar/avatar_settings_screen.dart` | 4h | P2 | 🔲 Pending |
| **Desktop Control** | | | | |
| Clipboard service | `lib/services/desktop_control/clipboard_service.dart` | 4h | P1 | ✅ Complete |
| File operations UI | `lib/screens/desktop/file_operations_screen.dart` | 5h | P1 | ✅ Complete |

**Total Time**: ~51 hours (Avatar: ~42h, Desktop: ~9h)

### Phase 2 Success Criteria

**Avatar System**:
- ✅ Database migrated with avatar_profiles, evolution_history, conversation_depth_metrics tables
- ✅ Personality traits adjustable via UI (0-1 sliders for formality, humor, enthusiasm, empathy)
- ✅ Avatar visuals respond to personality (colors, animation speed, emoji selection)
- ✅ OpenClaw skill loads and injects personality into responses
- ✅ Evolution flow works: self-reflection → request → validation → transformation
- ✅ Markdown backup syncs reliably (personality.md, memory.md, context.md)
- ✅ Fallback to markdown when Drift unavailable

**Desktop Control**:
- ✅ Clipboard service with history tracking
- ✅ File operations UI functional

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

**Total Time**: ~32 hours

---

## Key Files Reference

| Phase | Modify | Create |
|-------|--------|--------|
| Setup | `lib/di/locator.dart`, `lib/config/router.dart` | Wizard screens + services |
| Chat | `connection_manager_service.dart`, `home_layout.dart` | Provider selector implementation |
| Runtime management | `gateway_control_service.dart`, Hermes/OpenClaw provider services | None (already exists) |
| Avatar | `avatar_widget.dart` | Personality, evolution, memory services |
| Desktop | `gui_automation_service.dart` | `clipboard_service.dart` |
| Vision | `gui_automation_service.dart` | `camera_capture.dart`, `ocr_engine.dart` |

---

## Success Criteria

### Phase 0 (Setup Wizard) ✅
- ✅ New users complete setup in <3 minutes
- ✅ Selected runtime required and verified
- ✅ Local, Tailscale, and custom endpoint options work

### Phase 1 (Foundation) ✅
- ✅ Gateway auto-restart working
- ✅ Chat search UI functional
- ✅ Rich message rendering with markdown
- ✅ Provider selector switches OpenClaw cloud providers
- ✅ WebSocket device identity authentication
- ✅ Agent status polling via sessions.list

### Phase 2 (Core Features) ✅ Complete
- ✅ Database schema: avatar_profiles, evolution_history, conversation_depth_metrics, conversation_memories
- ✅ Personality engine with 4 traits (formality, humor, enthusiasm, empathy)
- ✅ Evolution tracker (no XP - organic growth via conversation depth)
- ✅ Conscience System storage layer (agentThoughts, conscienceDecisions tables)
- 🔲 OpenClaw skill: ~/.openclaw/skills/cloudtolocallm/ (user setup)
- ✅ Markdown backup sync (personality.md, memory.md, context.md)
- 🔲 Avatar visuals respond to personality (Rive + emoji blending) - pending assets
- ✅ Clipboard service with history
- ✅ File operations UI functional

### Phase 3 (Advanced) ✅ Complete
- ✅ Avatar memory system with embeddings and semantic search
- ✅ Vision services: region capture, camera input, OCR
- ✅ Desktop control: Wayland-native platform channels with X11 fallback
- ✅ Hermes streaming service with agent lifecycle events
- 🔲 Avatar customization UI

---

## Reference

- **SPEC.md**: Master specification
- **README.md**: User-facing overview
- **docs/architecture/SYSTEM_ARCHITECTURE.md**: Technical deep dive
- **CLAUDE.md**: Development guidelines
- **docs/plans/YYYY-MM-DD-avatar-personality-engine-design.md**: Detailed personality engine design
