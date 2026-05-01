# Secure Device Mesh

CloudToLocalLLM uses a Tailscale-first secure device mesh to connect the user's devices, selected agent runtime, and optional cloud connector.

## Goal

Give Hermes, OpenClaw, and other compatible agent runtimes secure, permissioned hands and eyes on the user's authorized desktops without exposing desktop-control APIs to the public internet.

## Core Model

The agent runtime location is chosen by setup. It can be:

- on this device
- on another private device
- on a Tailscale device
- behind a manual/private URL
- in an optional paid CloudToLocalLLM-hosted agent runtime

Ollama, LM Studio, and similar local model providers are not agent runtime nodes. They can live on the same tailnet, but they support app-owned local intelligence features rather than the main secure agent channel.

CloudToLocalLLM can be installed on multiple user devices. The secure agent channel can sync across those devices, while desktop control and vision remain targeted to a specific device.

## Preferred Transport

Tailscale is the preferred private network transport.

```text
Client UI / web / phone
        |
Optional per-user CloudToLocalLLM cloud connector
        |
User's Tailscale tailnet
        |
CloudToLocalLLM desktop apps and user-selected agent runtimes
```

## Per-User Cloud Connector

The intended cloud connector shape is one isolated container per user.

Responsibilities:

- join only that user's tailnet
- coordinate secure channel sync
- track device presence and runtime availability
- support web/mobile access to the secure channel
- relay requests to device APIs only when permitted by local app policy
- store only that user's session/sync metadata

Constraints:

- no shared multi-user connector with broad network reach
- no desktop action without target-device selection and local permission checks
- no broad tailnet scanning beyond the CloudToLocalLLM device/runtime discovery scope
- no cloud connector bypass around local desktop-control prompts

## Device Nodes

Each desktop app install can become a device node.

Responsibilities:

- expose a local CloudToLocalLLM device API only on approved interfaces
- report presence and capability state
- enforce local permissions for desktop control, vision, files, clipboard, and commands
- execute only device-scoped actions
- keep audit history for sensitive operations

## Agent Runtime Nodes

The selected agent runtime can be local or remote inside the user's private network.

Examples:

- Hermes on the same workstation
- Hermes on another workstation/server
- OpenClaw Gateway on a lab machine
- compatible custom agent gateway
- CloudToLocalLLM-hosted agent runtime as paid compute

The app should present runtime location as setup state, not product destiny.

## Support Model Provider Nodes

Optional support model providers can also live on the device mesh.

Examples:

- Ollama on a local model box
- LM Studio on a workstation
- custom OpenAI-compatible model endpoint

These nodes can support memory, embeddings, summarization, classification, OCR cleanup, and speech helpers. They do not receive desktop-control authority and do not satisfy primary agent runtime setup.

## Sync Rules

Global/syncable:

- secure channel history
- selected active agent runtime metadata
- device presence
- avatar memory and companion state where user-approved
- non-sensitive preferences

Device-scoped:

- screen capture
- camera capture
- clipboard
- shell commands
- file operations
- window/app control
- local secrets

## Security Rules

- Use Tailscale ACLs/tags to narrow cloud connector access.
- Treat the cloud connector as a service device, not a user desktop.
- Use local app permissions as the final authorization layer for desktop actions.
- Keep cloud-hosted agent runtime separate from cloud connector where practical.
- Prefer explicit device targeting for every action that changes local state.
- Make active vision/desktop-control state visible to the user.

## Relationship To Legacy Tunnels

The custom SSH/WebSocket tunnel system should be treated as legacy or fallback infrastructure unless a specific task requires it. New multi-device and cloud connector design should prefer Tailscale.

Reasons:

- lower custom networking complexity
- mature NAT traversal and WireGuard transport
- tailnet identity and ACLs
- simpler per-user isolation model
- less proxy/container coordination code

## Related Docs

- [System Architecture](SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](AGENT_RUNTIME_CONTRACT.md)
- [Tunnel System](TUNNEL_SYSTEM.md)
- [Desktop Control](DESKTOP_CONTROL.md)
- [Vision System](VISION_SYSTEM.md)
- [Avatar System](AVATAR_SYSTEM.md)
- [Product Specification](../../SPEC.md)
