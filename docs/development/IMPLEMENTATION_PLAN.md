# Implementation Plan - OpenClaw Agent Manager

**CloudToLocalLLM** is an OpenClaw Agent Manager — a privacy-first desktop AI companion organized around five core pillars.

> **Last Updated**: 2026-02-25 | **Overall Progress**: ~55% complete | **Estimated Timeline**: 8 weeks

---

## Recent Updates

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
| **Chat** | ✅ Phase 1 Complete | 90% | Multi-model attachments |
| **OpenClaw Manager** | ✅ Phase 1 Complete | 90% | Advanced metrics |
| **Evolving Avatar** | 🟡 Supervisor Feature Added | 30% | Implementing personality + supervisor |
| **Desktop Control** | 🟡 Partial | 40% | Window management |
| **Vision** | 🟡 Partial | 30% | Region capture + OCR |

---

## Implementation Phases Overview

| Phase | Focus | Duration | Status | Key Deliverables |
|-------|-------|----------|--------|------------------|
| **Phase 0** | Setup Wizard | Week 1 | ✅ Complete | Onboarding flow, provider detection |
| **Phase 1** | Foundation | Weeks 2-3 | ✅ Complete | Provider selector, gateway control, chat search |
| **Phase 2** | Core Features | Weeks 4-6 | 🔲 Pending | Avatar personality/evolution, clipboard, file ops |
| **Phase 3** | Advanced | Weeks 7-8 | 🔲 Pending | Camera/OCR, avatar memory, achievements, macros |

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
                    │  LLM Router     │
                    │  (localhost:1337)│
                    │  OpenAI-compatible│
                    └────────┬─────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │  OpenClaw Gateway     │
                  │  (localhost:18789)   │
                  │  Privacy Router      │
                  └──────────┬───────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
     ┌─────────────────┐          ┌─────────────────┐
     │  Cloud Providers│          │  Local Models   │
     │  (Performance)  │          │  (Privacy)      │
     │                 │          │                 │
     │  • Zhipu (GLM)  │          │  • Llama        │
     │  • Google Gemini│          │  • Qwen         │
     │  • Moonshot Kimi│          │  • Mistral      │
     └─────────────────┘          └─────────────────┘
```

**How It Works:**
1. **LLM Router** (localhost:1337) provides OpenAI-compatible API for the app
2. All requests route through **OpenClaw Gateway** (localhost:18789)
3. OpenClaw intelligently routes based on content:
   - **Sensitive/private data** → Local models (stays on machine)
   - **Regular queries** → Cloud providers (faster, more capable)
4. **Model Selector** switches OpenClaw's active cloud provider

---

## Phase 0: Setup Wizard ✅ COMPLETE

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

| Task | File(s) | Time | Priority |
|------|---------|------|----------|
| **Avatar System** | | | |
| Database schema migration | `lib/database/drift_local_brain.dart` | 2h | P0 |
| PersonalityEngine service | `lib/services/avatar/personality_engine.dart` | 4h | P1 |
| EvolutionTracker service | `lib/services/avatar/evolution_tracker.dart` | 5h | P1 |
| AvatarStateService | `lib/services/avatar/avatar_state_service.dart` | 3h | P1 |
| MarkdownSyncService | `lib/services/avatar/markdown_sync_service.dart` | 4h | P1 |
| OpenClaw personality skill | `~/.openclaw/skills/cloudtolocallm/` | 6h | P0 |
| Evolution API endpoints | `lib/services/router_server.dart` | 3h | P1 |
| Rive avatar animations | `assets/animations/avatar.riv` | 8h | P2 |
| Emoji blending fallback | `lib/features/avatar/emoji_blending_avatar.dart` | 3h | P2 |
| Avatar settings UI | `lib/screens/avatar/avatar_settings_screen.dart` | 4h | P2 |
| **Desktop Control** | | | |
| Clipboard service | `lib/services/desktop_control/clipboard_service.dart` | 4h | P1 |
| File operations UI | `lib/screens/desktop/file_operations_screen.dart` | 5h | P1 |

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
| OpenClaw | `gateway_control_service.dart` | None (already exists) |
| Avatar | `avatar_widget.dart` | Personality, evolution, memory services |
| Desktop | `gui_automation_service.dart` | `clipboard_service.dart` |
| Vision | `gui_automation_service.dart` | `camera_capture.dart`, `ocr_engine.dart` |

---

## Success Criteria

### Phase 0 (Setup Wizard) ✅
- ✅ New users complete setup in <3 minutes
- ✅ OpenClaw Gateway required and verified
- ✅ Local, Tailscale, and custom options work

### Phase 1 (Foundation) 🟡
- ✅ Gateway auto-restart working
- ✅ Chat search UI functional
- ✅ Rich message rendering with markdown
- 🔲 Provider selector switches OpenClaw cloud providers

### Phase 2 (Core Features)
- 🔲 Database schema: avatar_profiles, evolution_history, conversation_depth_metrics
- 🔲 Personality engine with 4 traits (formality, humor, enthusiasm, empathy)
- 🔲 Evolution tracker (no XP - organic growth via conversation depth)
- 🔲 OpenClaw skill: ~/.openclaw/skills/cloudtolocallm/
- 🔲 Markdown backup sync (personality.md, memory.md, context.md)
- 🔲 Avatar visuals respond to personality (Rive + emoji blending)
- 🔲 Clipboard service with history

### Phase 3 (Advanced)
- 🔲 Avatar memory system with embeddings
- 🔲 Region capture, camera input, OCR
- 🔲 Avatar customization UI

---

## Reference

- **SPEC.md**: Master specification
- **README.md**: User-facing overview
- **docs/architecture/SYSTEM_ARCHITECTURE.md**: Technical deep dive
- **CLAUDE.md**: Development guidelines
- **docs/plans/YYYY-MM-DD-avatar-personality-engine-design.md**: Detailed personality engine design
