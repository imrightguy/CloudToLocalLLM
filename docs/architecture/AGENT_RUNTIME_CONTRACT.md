# Agent Runtime Contract

CloudToLocalLLM is agent-first. The main application channel connects to an agent runtime, not directly to a raw local model provider.

## Terms

| Term | Meaning |
| --- | --- |
| Agent runtime | Hermes, OpenClaw, or a compatible gateway that manages agents, sessions, tools, and runtime state. |
| Agent session | A live assistant, task, or persona running inside an agent runtime. |
| Device node | An installed CloudToLocalLLM desktop app exposing local capabilities under local permission rules. |
| Capability broker | The app-side broker that approves, executes, and audits desktop, vision, clipboard, file, and command actions. |
| Local model provider | Ollama, LM Studio, llama.cpp, or similar model endpoints used for app support features such as embeddings or summarization. |
| Cloud connector | Optional isolated per-user container joined to the user's Tailscale tailnet for sync and reachability. |
| Hosted agent runtime | Optional paid CloudToLocalLLM-managed agent runtime compute, isolated per user. |

## Non-Negotiable Rules

- The main secure channel connects to an agent runtime.
- Hermes is the first agent runtime path for current testing.
- OpenClaw remains a supported agent runtime and original integration.
- Ollama and LM Studio are not primary app runtimes unless wrapped by an agent runtime.
- Local model providers can support app-owned features: memory embeddings, summarization, semantic search, classification, OCR cleanup, STT/TTS helpers, or other background intelligence.
- The cloud connector is not a hosted agent runtime and must not execute desktop actions.
- Desktop control is always device-scoped, permissioned, visible, and auditable.

## Channels

### Agent Channel

The agent channel is the main user-facing surface.

Responsibilities:

- chat and streaming
- agent session lifecycle
- runtime health and capability state
- tool requests
- desktop action requests
- vision context requests
- voice/avatar state handoff
- multi-device channel sync

Valid primary targets:

- Hermes on this device
- Hermes on another private or Tailscale device
- OpenClaw on this device
- OpenClaw on another private or Tailscale device
- compatible custom agent gateway
- optional paid CloudToLocalLLM-hosted agent runtime

### Support Model Channel

The support model channel is internal app infrastructure.

Valid targets:

- Ollama
- LM Studio
- llama.cpp-compatible local servers
- custom local/OpenAI-compatible model endpoint

Valid uses:

- memory embeddings
- memory summarization
- conversation compaction
- semantic search
- local classification
- OCR cleanup
- optional STT/TTS helpers
- other app-owned background intelligence

Invalid use:

- presenting the raw model provider as the main agent endpoint
- granting desktop control to a raw model provider
- treating model availability as agent runtime readiness

## Minimum Agent Runtime Capabilities

| Capability | Required | Purpose |
| --- | --- | --- |
| `health` | Yes | Check runtime availability and compatibility. |
| `sessions.list` | Yes | Show existing agent sessions. |
| `sessions.create` | Yes | Start a new agent session. |
| `sessions.resume` | Yes | Resume an existing agent session. |
| `sessions.end` | Yes | End or archive an agent session. |
| `chat.stream` | Yes | Main secure channel streaming. |
| `agent.status` | Yes | Reflect idle, thinking, working, speaking, error, and offline states. |
| `tools.list` | Yes | Show tools the runtime may request. |
| `desktop.requestAction` | Yes for desktop control | Request local app action through the capability broker. |
| `vision.requestContext` | Yes for vision | Request screen, region, OCR, or camera context through the capability broker. |
| `memory.query` | Optional | Query app-owned LocalBrain memory. |
| `memory.update` | Optional | Propose memory writes through app policy. |
| `voice.state` | Optional initially | Share listening/speaking/engaged state with the companion. |
| `voice.input` | Optional initially | Accept transcript or audio handoff. |
| `voice.output` | Optional initially | Return speech-ready responses or TTS metadata. |
| `models.list` | Optional | Report models available inside the runtime; not a primary app target. |

## Capability Broker Flow

```text
Agent runtime request
        |
CloudToLocalLLM capability broker
        |
Device permission check
        |
User approval when required
        |
Local device execution
        |
Audit log and result back to runtime
```

The runtime can ask. The local app decides. The connector can route or sync. It cannot approve or execute device actions.

## Setup Wizard Requirements

The wizard must ask for the agent runtime first.

Agent runtime setup choices:

1. Hermes on this device.
2. Hermes on another private or Tailscale device.
3. OpenClaw on this device.
4. OpenClaw on another private or Tailscale device.
5. Compatible custom agent gateway.
6. Optional CloudToLocalLLM-hosted agent runtime.
7. No agent runtime yet; guide the user to install or configure Hermes/OpenClaw/a compatible agent gateway.

Optional support model setup choices:

1. None.
2. Ollama.
3. LM Studio.
4. Custom local model endpoint.

The wizard must not list Ollama or LM Studio as primary agent runtime options.

## Code Migration Targets

| Old shape | Target shape |
| --- | --- |
| Provider discovery mixes agent runtimes and local model providers | Split into `AgentRuntimeDiscoveryService` and `LocalModelProviderDiscoveryService`. |
| `ConnectionManagerService` chooses LLM/provider paths | Agent-runtime-oriented connection and session manager. |
| Ollama/LM Studio appear as main runtime choices | Support-model provider settings only. |
| Tunnel/streaming proxy is primary remote path | Tailscale mesh and per-user cloud connector. |
| User container means streaming proxy | User container means cloud connector or hosted agent runtime depending on product tier. |
| Agent runtime can imply desktop control | Agent runtime requests go through the device capability broker. |

## Verification Gates

- Hermes local agent runtime connects as the first test path.
- Hermes over Tailscale connects through the agent channel.
- OpenClaw remains available as an agent runtime.
- Raw Ollama/LM Studio endpoints never satisfy agent runtime setup.
- Ollama/LM Studio can be configured as support model providers.
- Desktop actions require local device permission and audit.
- Cloud connector cannot perform desktop actions by itself.
