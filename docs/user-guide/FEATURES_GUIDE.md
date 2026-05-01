# CloudToLocalLLM Features Guide

CloudToLocalLLM is a local-first secure agent companion for Hermes, OpenClaw, and compatible private agent runtimes. The app is not tied to one default runtime. The setup wizard selects and validates the agent runtime path for each user and device.

Hermes is the first agent runtime path used for current testing. OpenClaw remains supported as the original agent integration target.

Ollama, LM Studio, and similar local model servers are optional support model providers for memory and background app features. They are not primary app runtimes.

---

## Core Features

### 1. Secure Agent Channel

| Feature | Description |
| --- | --- |
| Unified chat | Main interaction point with the selected agent runtime |
| Streaming | Real-time token-by-token responses |
| Conversations | Create, save, and organize chats |
| History | Persistent local history with search |
| Agent runtime support | Hermes, OpenClaw, and compatible custom agent gateways |
| Runtime health | Connection, latency, session, tool, and capability checks |

### 2. Avatar And Voice Companion

| Feature | Description |
| --- | --- |
| Pop-out companion | Avatar and voice can open as a sidecar outside the main app window |
| Avatar states | Idle, listening, thinking, speaking, working, error, and success states |
| Voice conversation | Voice shell for the selected agent runtime |
| Speech output | Runtime or CloudToLocalLLM fallback text-to-speech |
| Planned speech input | Microphone capture, VAD, direct-address detection, and barge-in |
| Planned evolution | Memory, traits, levels, achievements, and learned preferences |

### 3. Desktop Control

Desktop control is a core feature, not an advanced add-on.

| Feature | Status |
| --- | --- |
| Screenshot capture | Available |
| Vision analysis | Available through supported agent runtime paths |
| System commands | Available when explicitly enabled |
| Notifications | Available |
| Clipboard | In progress or platform-dependent |
| Window management | In progress or platform-dependent |
| File operations | Planned behind explicit permissions |
| Macro/action replay | Planned behind explicit approvals |

Desktop actions are scoped to the device that granted permission. Cloud sync does not automatically grant control over other devices. Local model providers do not receive desktop-control authority.

### 4. Vision Capabilities

| Feature | Status |
| --- | --- |
| Full-screen capture | Available |
| Screen analysis | Available through supported agent runtime paths |
| Region capture | Planned or partially implemented depending on platform |
| OCR | Planned or partially implemented depending on runtime/local support model |
| Camera input | Planned or platform-dependent |
| Continuous monitor | Planned for selected regions |

### 5. Agent Runtime Management

| Feature | Description |
| --- | --- |
| Runtime discovery | Detect Hermes, OpenClaw, and configured custom agent gateways |
| Runtime setup | Wizard-driven selection and testing |
| Agent sessions | Inspect and manage active agent sessions |
| Runtime model selection | Choose from models exposed by the active agent runtime, when supported |
| Capability review | Show available tools, desktop permissions, voice, and vision support |

Runtime management remains available, but it should not dominate the first screen of the app.

### 6. Local Intelligence Support

| Feature | Description |
| --- | --- |
| Local model provider discovery | Detect Ollama, LM Studio, or custom local model endpoints |
| Memory embeddings | Use a support model provider for semantic memory when enabled |
| Summaries | Generate conversation summaries or compaction locally when enabled |
| Classification | Run lightweight local classifiers for app-owned workflows |
| OCR cleanup | Improve OCR text using local model support |

Support model providers are optional and separate from the main agent channel.

### 7. Secure Device Mesh

| Feature | Description |
| --- | --- |
| Tailscale-first transport | Preferred path for remote device and agent runtime connectivity |
| Multi-device install | Run CloudToLocalLLM on all user devices |
| Presence sync | See which devices and agent runtimes are available |
| Conversation sync | Optional account-backed conversation sync |
| Per-user cloud connector | Isolated container joined to the user's tailnet after approval |
| Optional hosted agent runtime | Paid cloud compute path, isolated per user |

The older custom tunnel stack is legacy or fallback architecture. New design and documentation should prefer Tailscale unless a specific platform cannot support it.

---

## Authentication

- Auth0 integration for account-backed features.
- Desktop uses native authentication with secure local token storage.
- Web uses session-based authentication through the bridge service.
- Local-only usage should remain possible where the chosen runtime and features do not need cloud sync.

---

## Integrations

### Agent Runtimes

#### Hermes

Hermes is the first agent runtime path to test during the current product direction. Configure the endpoint through the setup wizard.

#### OpenClaw Gateway

OpenClaw was the original agent runtime integration and remains supported.

- Typical endpoint: `http://localhost:18789`
- Health check: `GET /health`

#### Custom Agent Gateway

Use a custom endpoint for private servers, VPS deployments, or compatible agent gateways. Prefer putting remote endpoints inside the user's Tailscale tailnet.

### Support Model Providers

#### LM Studio

- Typical endpoint: `http://localhost:1234`
- Useful as an OpenAI-compatible local model provider for memory/background features.

#### Ollama

- Typical endpoint: `http://localhost:11434`
- Useful for local model hosting, embeddings, summaries, and other app-owned support tasks.

---

## Data And Storage

| Location | Description |
| --- | --- |
| `~/.config/cloudtolocalllm/` | Configuration files |
| `~/.local/share/cloudtolocalllm/` | Logs and app data |
| LocalBrain SQLite | Encrypted local companion database |
| Optional cloud account | Sync metadata and conversation state when enabled |

Sensitive desktop permissions, local agent runtime secrets, local model provider secrets, and local command access should stay device-scoped unless an explicit secure storage design is approved.

---

## Troubleshooting

### Agent Runtime Connection Issues

```bash
# Example OpenClaw health check
curl http://localhost:18789/health
```

Use the setup wizard connection test for Hermes and custom agent gateways.

### Support Model Provider Issues

```bash
# Example local model health checks
curl http://localhost:1234/v1/models
curl http://localhost:11434/api/tags
```

If these pass but the main app channel is disconnected, check agent runtime settings instead.

### Tailscale Issues

```bash
tailscale status
tailscale ping <device-name-or-ip>
```

Confirm both the app device and agent runtime device are in the expected tailnet.

### Logs

- Linux: `~/.local/share/cloudtolocalllm/logs/`
- Windows: `%LOCALAPPDATA%\cloudtolocalllm\logs\`

---

## Documentation

- [Specification](../../SPEC.md)
- [Setup Guide](SETUP_GUIDE.md)
- [User Guide](USER_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](../architecture/AGENT_RUNTIME_CONTRACT.md)
- [Secure Device Mesh](../architecture/SECURE_DEVICE_MESH.md)
