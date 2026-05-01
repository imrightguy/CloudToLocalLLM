# CloudToLocalLLM Specification

## Project Vision

**CloudToLocalLLM** is a local-first companion and desktop capability layer for user-selected agent runtimes. It gives Hermes, OpenClaw, and other compatible runtimes a secure channel to the user and permissioned hands and eyes on the user's desktops.

The setup wizard is the authority for runtime selection. The app must not assume a single default runtime. A user can connect a runtime on this device, another private device, a Tailscale device, a manual private URL, or an optional paid CloudToLocalLLM-hosted runtime.

Hermes is the current first test path. OpenClaw remains a supported runtime and original integration, but it is not the universal default.

## Product Model

CloudToLocalLLM has three product layers:

1. **Local/user-network runtime**: the normal path. The user runs Hermes, OpenClaw, or another runtime on hardware they control.
2. **Cloud connector and sync**: an optional per-user cloud connector container that can join the user's Tailscale tailnet for secure channel sync, presence, and web/mobile access.
3. **Cloud-hosted runtime**: an optional paid compute add-on for users who want CloudToLocalLLM to run an isolated agent runtime for them.

Cloud services coordinate identity, sync, presence, and optional hosted compute. They are not required for the core single-device local experience.

## Core Pillars

### 1. Secure Agent Channel

- Main window is a direct, secure channel to the selected active runtime.
- Hermes is the first target for development and testing.
- Channel state can sync across authorized devices when cloud mode is enabled.
- Device presence, runtime status, and action approvals attach to the channel.
- The UI should be calm and direct, not a management dashboard first.

### 2. Avatar And Voice Companion

- The avatar is the companion surface, not only an in-app decoration.
- Voice belongs with the avatar companion.
- The avatar/voice companion should be able to open as its own sidecar window.
- It reflects listening, engaged, speaking, thinking, working, and error states.
- It can escalate from lightweight conversation to the active runtime when needed.

### 3. Desktop Control

- Desktop control is a core feature.
- The active runtime can request permissioned hands-on access to a selected device.
- Capabilities include app launch, window control, click/type/keyboard actions, clipboard, file operations, system state, and command execution where supported.
- Risky actions must remain explicit, device-scoped, auditable, and user-controlled.

### 4. Vision

- Vision gives the runtime controlled eyes on selected devices.
- Capabilities include screen capture, region capture, OCR, camera input, and later continuous monitoring.
- Camera and screen monitoring must be visible, opt-in, and device-scoped.

### 5. Runtime And Agent Management

- Agent/runtime management remains important, but it is not the first surface.
- Management covers Hermes, OpenClaw, other compatible runtimes, sessions, skills, models, providers, and diagnostics.
- Users should be able to start, stop, restart, inspect, and troubleshoot runtimes when needed.

### 6. Multi-Device Sync And Secure Mesh

- CloudToLocalLLM can be installed on all of a user's devices.
- Tailscale is the preferred private transport for device-to-device and cloud-connector communication.
- Conversation/channel state can sync globally.
- Desktop actions, vision, files, clipboard, and commands are always targeted to a specific authorized device.

## Setup Wizard

The first-run setup wizard must guide users through runtime selection without assuming a default.

Supported setup paths:

1. **This device**: runtime running locally.
2. **Another private device**: runtime running on another desktop, workstation, or server.
3. **Tailscale device**: runtime discovered through the user's tailnet.
4. **Manual/private URL**: custom LAN, VPN, tailnet DNS, or private endpoint.
5. **Cloud-hosted runtime**: optional paid CloudToLocalLLM-managed runtime.
6. **No runtime yet**: guide the user through installing or configuring Hermes, OpenClaw, or another supported runtime.

## Technical Architecture

### Flutter App

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry point |
| `lib/di/locator.dart` | GetIt service registration and two-phase DI |
| `lib/database/` | Drift/SQLite local brain and platform database connections |
| `lib/services/` | Service layer |
| `lib/services/hermes_manager/` | Hermes runtime management and streaming |
| `lib/services/openclaw_manager/` | OpenClaw Gateway control |
| `lib/services/avatar/` | Avatar state, personality, memory, evolution, markdown sync |
| `lib/services/voice/` | Avatar companion voice state and TTS foundation |
| `lib/services/desktop_control/` | Clipboard and desktop window control |
| `lib/services/vision/` | Camera, OCR, region capture, vision orchestration |
| `lib/services/providers/` | OpenAI-compatible provider adapters |
| `lib/screens/` | Main app screens |
| `lib/widgets/` | Shared widgets and companion controls |

### Backend And Cloud

| Service | Role |
| --- | --- |
| API Backend | Auth, user/device metadata, admin APIs, optional cloud coordination |
| Streaming Proxy | Legacy/fallback streaming path and web transport support |
| Per-user cloud connector | Isolated optional container that joins the user's Tailscale tailnet |
| Tailscale Relay | Existing service area for Tailscale integration |
| Auth Backend | Lightweight Auth0 JWT validation |
| SDK | TypeScript SDK |
| OpenClaw Skills | Avatar personality/evolution skill package |

### Secure Device Mesh

Primary private transport should be Tailscale:

```text
Client UI / Web / Phone
        |
Optional per-user CloudToLocalLLM cloud connector
        |
User's Tailscale tailnet
        |
CloudToLocalLLM desktop apps and user-selected runtimes
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
- The active runtime location is chosen by setup, not assumed.
- User-owned runtimes normally live inside the user's network or tailnet.
- Cloud-hosted runtime is optional paid compute.
- Desktop control and vision are always device-scoped and permissioned.
- Cloud sync must not grant direct desktop access without local app approval.
- Local data ownership remains central through LocalBrain/SQLite and explicit sync settings.

## Success Metrics

1. **Runtime setup**: user can connect Hermes, OpenClaw, or another supported runtime through setup without editing config files.
2. **Secure channel**: main window provides a reliable direct channel to the active runtime.
3. **Companion**: avatar/voice companion can run as a sidecar and reflect channel/runtime state.
4. **Desktop control**: runtime can complete useful permissioned desktop actions on a selected device.
5. **Vision**: runtime can inspect selected screen/camera context with user consent.
6. **Multi-device sync**: channel state can continue across authorized devices.
7. **Isolation**: cloud connector and cloud-hosted runtime paths are isolated per user.

## Out Of Scope For The Immediate MVP

- Treating any one runtime as universal default.
- Public, unauthenticated desktop access.
- Background desktop control without user-visible state.
- Mandatory cloud-hosted agent runtime.
- Full mobile-native apps beyond web/cloud channel access.
- Advanced 3D avatar rendering.
