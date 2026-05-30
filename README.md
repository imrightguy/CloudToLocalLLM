# CloudToLocalLLM 🦞

**Your private AI companion. Runs locally, works across your devices, keeps your data yours.**

CloudToLocalLLM is a desktop app that wraps Hermes, OpenClaw, or any compatible agent runtime with a secure channel, voice/avatar companion, vision, and permissioned desktop control — all running on your own hardware.

```
┌─────────────────────────────────────────┐
│  A local-first companion and desktop    │
│  capability layer for your AI agent.    │
│                                         │
│  Private. Secure. Yours.                │
└─────────────────────────────────────────┘
```

## Quick Start

```bash
# Linux — one command
curl -fsSL https://cloudtolocalllm.online/install.sh | bash

# Or grab the latest release:
# https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest
```

**You need an agent runtime.** Hermes is the current primary test path. OpenClaw and compatible agent gateways also work. [Get started →](docs/user-guide/SETUP_GUIDE.md)

---

## What It Does

| Feature | What you get |
|---------|-------------|
| **💬 Secure Agent Channel** | Direct channel to your agent, synced across devices |
| **🦞 Voice & Avatar** | Sidecar companion with personality, memory, natural conversation |
| **💻 Desktop Control** | Permissioned access to apps, windows, keyboard, clipboard, files |
| **👁️ Vision** | Screen awareness, OCR, camera — explicit user permission per action |
| **🔐 Device Mesh** | Tailscale-first private network across all your devices |
| **🧠 Runtime Manager** | Manage agents, skills, sessions, tools, and diagnostics |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  CloudToLocalLLM App                 │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  Chat/   │  │  Avatar  │  │  Desktop Control  │  │
│  │  Agent   │  │  Voice   │  │  Vision           │  │
│  │  Channel │  │  Memory  │  │  Permissions      │  │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘  │
│       └──────────────┼─────────────────┘             │
│                      ▼                               │
│           ┌──────────────────┐                       │
│           │  Agent Adapter   │                       │
│           │  (Hermes/OpenClaw)│                      │
│           └────────┬─────────┘                       │
└────────────────────┼─────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼────┐           ┌──────▼──────┐
    │ Local   │           │ Support     │
    │ Agent   │           │ Models      │
    │ Runtime │           │ (Ollama,    │
    │         │           │  LM Studio) │
    └─────────┘           └─────────────┘
```

Technical architecture → [docs/architecture/SYSTEM_ARCHITECTURE.md](docs/architecture/SYSTEM_ARCHITECTURE.md)

## Platforms

| Platform | Status |
|----------|--------|
| 🐧 Linux | ✅ AppImage + auto-update daemon |
| 🪟 Windows | ✅ Installer (in development) |
| 🌐 Web | [cloudtolocalllm.online](https://cloudtolocalllm.online) |
| 📱 Android | ✅ APK builds |
| 🍎 macOS | Planned |

## Development

```bash
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM
flutter pub get
flutter run -d linux   # Desktop
flutter run -d chrome  # Web
```

Detailed developer guide → [docs/development/BUILD_SCRIPTS.md](docs/development/BUILD_SCRIPTS.md)

### Quick Build

```bash
# Linux desktop
flutter build linux --release

# Android APK
flutter build apk --release --split-per-abi

# Web
flutter build web --release
```

### Backend Services

```bash
# API backend
cd services/api-backend && npm install && npm run dev

# Streaming proxy
cd services/streaming-proxy && npm install && npm run dev
```

---

## Full Documentation

📖 [Documentation site](https://cloudtolocalllm-online.github.io/CloudToLocalLLM/) (GitHub Pages)

- [User Guide](docs/user-guide/USER_GUIDE.md) — Features and usage
- [Setup Guide](docs/user-guide/SETUP_GUIDE.md) — Step-by-step installation
- [Troubleshooting](docs/user-guide/TROUBLESHOOTING.md) — Common issues
- [System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md) — Technical deep dive
- [Deployment Guide](docs/operations/backend/DEPLOYMENT.md) — Production setup
- [Security Guide](docs/operations/security/SECURITY.md)

## License

MIT — see [LICENSE](LICENSE).
