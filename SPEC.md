# CloudToLocalLLM Specification

## Project Vision

**CloudToLocalLLM** is a local-first companion and desktop capability layer for user-selected agent runtimes. It gives Hermes, OpenClaw, and compatible agent gateways a secure channel to the user and permissioned hands and eyes on the user's desktops.

The primary audience is personal users — individuals who want a private, capable AI companion on their own hardware. Business and team usage is a secondary path that follows the personal foundation.

The main app does not connect directly to raw local model providers as its primary experience. Ollama, LM Studio, and similar endpoints are support model providers for app-owned features such as memory, embeddings, summarization, classification, OCR cleanup, and speech helpers.

Hermes is the current first test path. OpenClaw remains a supported agent runtime and original integration, but it is not the universal default.

## Product Model

CloudToLocalLLM has four product layers:

1. **User-owned agent runtime**: the normal path. The user runs Hermes, OpenClaw, or a compatible agent gateway on hardware they control.
2. **Support model provider**: optional local model infrastructure such as Ollama or LM Studio for memory and other app-owned background features.
3. **Cloud connector and sync**: optional per-user cloud connector container that can join the user's Tailscale tailnet for secure channel sync, presence, and web/mobile access.
4. **Hosted agent runtime**: optional paid compute add-on for users who want CloudToLocalLLM to run an isolated agent runtime for them.

Cloud services coordinate identity, sync, presence, and optional hosted compute. They are not required for the core single-device local experience.

## Core Pillars

### 1. Secure Agent Channel

- Main window is a direct, secure channel to the selected active agent runtime.
- Hermes is the first target for development and testing.
- Channel state can sync across authorized devices when cloud mode is enabled.
- Device presence, runtime status, session state, and action approvals attach to the channel.
- The UI should be calm and direct, not a management dashboard first.

### 2. Avatar And Voice Companion

- The avatar is the companion surface, not only an in-app decoration.
- Voice belongs with the avatar companion.
- The avatar/voice companion should be able to open as its own sidecar window.
- It reflects listening, engaged, speaking, thinking, working, and error states.
- It can escalate from lightweight conversation to the active agent runtime when needed.

### 3. Desktop Control

- Desktop control is a core feature.
- The active agent runtime can request permissioned hands-on access to a selected device.
- The local CloudToLocalLLM device node approves, executes, and audits the action through a capability broker.
- Capabilities include app launch, window control, click/type/keyboard actions, clipboard, file operations, system state, and command execution where supported.
- Risky actions must remain explicit, device-scoped, auditable, and user-controlled.

### 4. Vision

- Vision gives the active agent runtime controlled eyes on selected devices.
- Capabilities include screen capture, region capture, OCR, camera input, and later continuous monitoring.
- Camera and screen monitoring must be visible, opt-in, and device-scoped.

### 5. Agent Runtime And Session Management

- Agent/runtime management remains important, but it is not the first surface.
- Management covers Hermes, OpenClaw, compatible agent gateways, sessions, skills, tools, models exposed by the runtime, diagnostics, and lifecycle controls.
- Users should be able to start, stop, restart, inspect, and troubleshoot runtimes when needed.

### 6. Local Intelligence Support

- Local model providers are optional support infrastructure.
- Ollama, LM Studio, and similar providers can power embeddings, memory summarization, semantic search, classification, OCR cleanup, local STT/TTS helpers, and other app-owned background intelligence.
- Local model providers are not primary agent runtime targets unless wrapped by a compatible agent gateway.

### 7. Multi-Device Sync And Secure Mesh

- CloudToLocalLLM can be installed on all of a user's devices.
- Tailscale is the preferred private transport for device-to-device and cloud-connector communication.
- Conversation/channel state can sync globally.
- Desktop actions, vision, files, clipboard, and commands are always targeted to a specific authorized device.

## Setup Wizard

The first-run setup wizard must guide users through agent runtime selection without assuming a default.

Agent runtime setup paths:

1. **This device**: Hermes, OpenClaw, or a compatible agent gateway running locally.
2. **Another private device**: agent runtime running on another desktop, workstation, or server.
3. **Tailscale device**: agent runtime discovered through the user's tailnet.
4. **Manual/private URL**: custom LAN, VPN, tailnet DNS, or private compatible agent gateway.
5. **Cloud-hosted agent runtime**: optional paid CloudToLocalLLM-managed runtime.
6. **No runtime yet**: guide the user through installing or configuring Hermes, OpenClaw, or another compatible agent gateway.

Optional support model setup paths:

1. **None**: use only the active agent runtime and built-in app features.
2. **Ollama**: local model provider for memory and background intelligence.
3. **LM Studio**: local OpenAI-compatible model provider for support tasks.
4. **Custom local model endpoint**: support model provider for app-owned features.

The wizard must not present Ollama or LM Studio as primary agent runtime choices.

## Technical Architecture

### Flutter App

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry point |
| `lib/di/locator.dart` | GetIt service registration and two-phase DI |
| `lib/database/` | Drift/SQLite local brain and platform database connections |
| `lib/services/` | Service layer |
| `lib/services/hermes_manager/` | Hermes agent runtime management and streaming |
| `lib/services/openclaw_manager/` | OpenClaw agent runtime control |
| `lib/services/avatar/` | Avatar state, personality, memory, evolution, markdown sync |
| `lib/services/voice/` | Avatar companion voice state and TTS foundation |
| `lib/services/desktop_control/` | Clipboard and desktop window control |
| `lib/services/vision/` | Camera, OCR, region capture, vision orchestration |
| `lib/services/providers/` | Support model and router provider adapters |
| `lib/screens/` | Main app screens |
| `lib/widgets/` | Shared widgets and companion controls |

### Backend And Cloud

| Service | Role |
| --- | --- |
| API Backend | Auth, user/device metadata, admin APIs, optional cloud coordination |
| Streaming Proxy | Legacy/fallback streaming path and web transport support |
| Per-user cloud connector | Isolated optional container that joins the user's Tailscale tailnet |
| Tailscale Relay | Existing service area for Tailscale integration |
| Hosted agent runtime | Optional paid isolated runtime compute |
| Auth Backend | Lightweight Auth0 JWT validation |
| SDK | TypeScript SDK |
| OpenClaw Skills | Avatar personality/evolution skill package |

### Agent Runtime Contract

See [Agent Runtime Contract](docs/architecture/AGENT_RUNTIME_CONTRACT.md).

The minimum required capabilities are:

- runtime health
- agent session list/create/resume/end
- chat streaming
- agent status
- tool list
- desktop action requests through the device capability broker
- vision context requests through the device capability broker

Memory and voice integration are important but may phase in behind the first Hermes/OpenClaw connection work.

### Secure Device Mesh

Primary private transport should be Tailscale:

```text
Client UI / Web / Phone
        |
Optional per-user CloudToLocalLLM cloud connector
        |
User's Tailscale tailnet
        |
CloudToLocalLLM desktop apps and user-selected agent runtimes
```

Rules:

- Use one isolated cloud connector container per user.
- The connector joins only that user's tailnet.
- The connector should use a narrow service identity such as a Tailscale tag.
- ACLs should allow only the device APIs needed by CloudToLocalLLM.
- The cloud connector coordinates channel sync and presence; it does not bypass local desktop permissions.
- Custom SSH/WebSocket tunnel infrastructure should be treated as legacy or fallback unless a specific use case still requires it.

## Privacy And Security Model

- Core single-device use must work without mandatory cloud dependencies.
- The active agent runtime location is chosen by setup, not assumed.
- User-owned agent runtimes normally live inside the user's network or tailnet.
- Cloud-hosted agent runtime is optional paid compute.
- Desktop control and vision are always device-scoped and permissioned.
- Cloud sync must not grant direct desktop access without local app approval.
- Local model providers do not receive desktop-control authority.
- Local data ownership remains central through LocalBrain/SQLite and explicit sync settings.

## Success Metrics

1. **Agent runtime setup**: user can connect Hermes, OpenClaw, or another compatible agent gateway through setup without editing config files.
2. **Secure channel**: main window provides a reliable direct channel to the active agent runtime.
3. **Companion**: avatar/voice companion can run as a sidecar and reflect channel/runtime state.
4. **Desktop control**: runtime can complete useful permissioned desktop actions on a selected device.
5. **Vision**: runtime can inspect selected screen/camera context with user consent.
6. **Local intelligence**: optional local model providers can support memory and background features without becoming the main agent endpoint.
7. **Multi-device sync**: channel state can continue across authorized devices.
8. **Isolation**: cloud connector and cloud-hosted agent runtime paths are isolated per user.

## Out Of Scope For The Immediate MVP

- Treating any one runtime as universal default.
- Treating raw Ollama or LM Studio endpoints as primary app runtimes.
- Public, unauthenticated desktop access.
- Background desktop control without user-visible state.
- Mandatory cloud-hosted agent runtime.
- Full mobile-native apps beyond web/cloud channel access.
- Advanced 3D avatar rendering.
