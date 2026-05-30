# CloudToLocalLLM

**A local-first companion and desktop capability layer for agent runtimes.**

CloudToLocalLLM is a Flutter desktop/web application with optional Node.js backend services. It provides a secure agent channel, avatar/voice companion, desktop control, vision system, agent runtime management, and multi-device sync through a Tailscale-first secure device mesh.

## What It Does

- **Secure Agent Channel** — Connects to your chosen agent runtime (Hermes, OpenClaw, or a compatible custom gateway). The setup wizard selects the runtime — no universal default.
- **Avatar & Voice Companion** — Persistent personality, evolution state, long-term memory, visual presence, and voice conversation in a sidecar window.
- **Desktop Control** — Explicit, device-scoped, permissioned, and auditable desktop inspection and operation.
- **Vision System** — Screenshots, region capture, camera input, and OCR for visual context.
- **Secure Device Mesh** — Tailscale-first private connectivity across devices, with optional cloud connector containers joined to your tailnet.
- **Multi-Runtime** — Agent runtime management for Hermes, OpenClaw, and compatible custom gateways.

## Architecture At a Glance

| Layer | Technology |
|-------|------------|
| Flutter app | Dart `>=3.5.0`, package `cloudtolocalllm` |
| Local database | Drift / SQLite |
| Embedded router | Shelf server, port `1337` |
| API backend | Express 5 ESM, Node `>=22 <25`, port `8080` |
| Streaming proxy | ESM service, Node `>=22 <25`, port `3001` |
| Tailscale relay | Express 4 ESM, port `3002` |
| Auth backend | Express 5 CommonJS, port `3000` |
| SDK | `@CloudToLocalLLM/sdk` v2, ESM |

## Quick Links

- [Getting Started](user-guide/SETUP_GUIDE.md)
- [Features Guide](user-guide/FEATURES_GUIDE.md)
- [System Architecture](architecture/SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](architecture/AGENT_RUNTIME_CONTRACT.md)
- [Docker Deployment](operations/backend/DEPLOYMENT.md)

---

**Open source** — [GitHub repo](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)
