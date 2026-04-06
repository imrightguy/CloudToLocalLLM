# CloudToLocalLLM 🦞 — OpenClaw Agent Manager

<div align="center">
  
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.5%2B-blue.svg)](https://flutter.dev)
[![Node.js Version](https://img.shields.io/badge/Node.js-22%2B-green.svg)](https://nodejs.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Web-lightgrey.svg)]()
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange.svg)]()

**Your private AI companion. Manage OpenClaw, watch your avatar evolve, control your desktop with vision. Privacy-first, locally-powered agent.**

_OpenClaw Agent Manager — privacy-first local AI with claws._ 🦞</div>

---

## 🤖 Hermes Agent compatibility

This repository includes `AGENTS.md`, `SOUL.md`, `USER.md`, and `SESSION_REENTRY.md` so Hermes Agent can load workspace instructions, project identity, human context, and a quick reentry path automatically.

---

## 🚀 Overview

**CloudToLocalLLM** is an **OpenClaw Agent Manager** — a privacy-first desktop AI companion with unified chat, evolving avatar, desktop control, and vision capabilities. It manages the OpenClaw Gateway, provides an evolving visual avatar with growing personality, and offers full desktop control through GUI automation and vision-language models.

> **Note:** The project is currently in **Heavy Development/Early Access**.

## ✨ Core Pillars

| Pillar                  | Description                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| **💬 Chat**             | Unified chat interface with streaming responses, conversation history, and multi-model support   |
| **🔌 OpenClaw Manager** | Start, stop, monitor OpenClaw Gateway (localhost:18789) with health monitoring and configuration |
| **🎨 Evolving Avatar**  | Visual 2D/3D character that grows with you — appearance and personality evolve over time         |
| **💻 Desktop Control**  | GUI automation (launch apps, control windows) + system integration (files, commands, clipboard)  |
| **👁️ Vision**           | Screen capture/analysis + camera input, powered by OpenClaw for screen understanding and OCR     |

## 📋 Prerequisites

- **[OpenClaw Gateway](https://github.com/openclaw/openclaw):** The primary engine for all LLM, Vision, and Agent tasks. Runs on `localhost:18789`.
- **[NVIDIA Drivers](https://www.nvidia.com/drivers):** Required for GPU acceleration (RTX 30/40 series recommended).

## 🚀 Quick Install

**Linux:**
```bash
curl -fsSL https://cloudtolocalllm.online/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://cloudtolocalllm.online/install.ps1 | iex
```

See **[Linux Installation](#linux-installation)** below for advanced installation options, auto-updates, and manual setup instructions.

**Manual Download:** Visit the **[Latest Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)** page to download installers for Windows (.exe), Linux (.AppImage), or source code.

### Linux Installation

#### Quick Install

Install CloudToLocalLLM on Linux with a single command:

```bash
curl -fsSL https://cloudtolocalllm.online/install.sh | bash
```

This automatically:
- Downloads the latest AppImage for your system
- Installs to `~/.local/share/cloudtolocalllm` (or `/opt/cloudtolocalllm` with `--system`)
- Creates desktop entries and menu shortcuts
- Sets up the **background update daemon** for automatic updates
- Configures the systemd timer for update checks

> **New:** The installer now includes an intelligent update daemon that automatically keeps CloudToLocalLLM up-to-date. Patch updates are installed silently, while minor/major updates prompt for your approval.

#### Installation Options

The installer supports several options for customizing your installation:

```bash
# System-wide installation (requires sudo)
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --system

# Beta channel (receive pre-release updates)
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --channel beta

# Custom installation directory
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --dir /opt/cloudtolocalllm

# Skip update daemon installation
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --no-daemon

# Silent installation (suppress output except errors)
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --silent
```

**Installation Types:**
- **User-local** (default): Installs to `~/.local/share/cloudtolocalllm` - no sudo required
- **System-wide** (`--system`): Installs to `/opt/cloudtolocalllm` - requires sudo, available to all users

**Update Channels:**
- **stable** (default): Production-ready releases only
- **beta**: Pre-release versions with latest features
- **edge**: Development builds (may be unstable)

#### Manual Installation

If you prefer manual installation or the installer doesn't work for your distribution:

1. **Download the AppImage:**

```bash
# Download latest release
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-x86_64.AppImage

# Or use curl
curl -L -o CloudToLocalLLM-x86_64.AppImage https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-x86_64.AppImage
```

2. **Make it executable:**

```bash
chmod +x CloudToLocalLLM-x86_64.AppImage
```

3. **Run the application:**

```bash
./CloudToLocalLLM-x86_64.AppImage
```

4. **Optional: Create desktop entry** (for app launcher integration):

```bash
# Install to local applications
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/cloudtolocalllm.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CloudToLocalLLM
GenericName=AI Model Bridge
Comment=Manage and run powerful Large Language Models locally
Exec=$(pwd)/CloudToLocalLLM-x86_64.AppImage %u
Terminal=false
Categories=Development;Utility;Network;
Keywords=AI;LLM;Machine Learning;Ollama;Local;
StartupNotify=true
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications
```

#### Auto-Updates

> **✨ Fully Implemented:** CloudToLocalLLM now includes an intelligent background update daemon that keeps your installation current with minimal disruption.

The update daemon is **automatically installed** with the one-line installer and runs as a systemd user service.

**Update Schedule:**
- Checks for updates every **6 hours** (configurable)
- Runs in the background as a systemd user service
- Minimal resource usage - wakes only to check for updates

**Smart Update Behavior:**

| Update Type | Example | Action |
|-------------|---------|--------|
| **Patch** | `10.1.200 → 10.1.201` | Auto-installed silently |
| **Minor** | `10.1.200 → 10.2.0` | Desktop notification prompt |
| **Major** | `10.1.200 → 11.0.0` | Desktop notification prompt |

**How It Works:**
1. The update daemon (`cloudtolocalllm-updated`) queries GitHub Releases API
2. Compares current version with latest release using semantic versioning
3. **Patch updates**: Downloads and installs automatically in the background
4. **Minor/Major updates**: Sends desktop notification (via `notify-send`) for approval
5. Updates are applied on next app restart (no interruption to active sessions)

**Manual Update Checks:**
Check for updates anytime from within the app:
1. Open **Config** screen (gear icon in sidebar)
2. Go to **System** tab
3. Click **Check Now** in Software Updates section
4. Available updates show download/install options

**Manage Update Daemon:**

```bash
# Check status
systemctl --user status cloudtolocalllm-updated.timer

# View logs
journalctl --user -u cloudtolocalllm-updated.service -f

# Disable auto-updates
systemctl --user stop cloudtolocalllm-updated.timer
systemctl --user disable cloudtolocalllm-updated.timer

# Re-enable auto-updates
systemctl --user start cloudtolocalllm-updated.timer
systemctl --user enable cloudtolocalllm-updated.timer
```

**Update State Location:**
```bash
~/.config/cloudtolocalllm/update-state.json
```

### Docker Deployment

For production deployments or self-hosted setups, CloudToLocalLLM includes a complete Docker Compose stack with:

- **API Backend** (Express.js) - REST API with Auth0 JWT
- **Streaming Proxy** - WebSocket proxy for real-time LLM streaming
- **Redis** - Rate limiting cache
- **Traefik** - Reverse proxy with automatic SSL (Let's Encrypt)
- **Prometheus** - Metrics collection
- **Grafana** - Monitoring dashboards

**Quick Start:**

```bash
# Clone and configure
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM
cp docker-compose.env.example .env
# Edit .env with your configuration

# Deploy to Docker Swarm
docker stack deploy -c docker-compose.prod.yml cloudtolocalllm
```

See **[DEPLOYMENT.md](DEPLOYMENT.md)** for complete deployment guide, including LXC container setup and production configuration.

### Web Version

Latest web deployment: **[cloudtolocalllm.online](https://cloudtolocalllm.online)**

## 📖 Documentation

- **[SPEC.md](SPEC.md):** Master specification — project vision, architecture, and feature definitions.
- **[User Guide](docs/user-guide/USER_GUIDE.md):** Features and detailed usage.
- **[Setup Guide](docs/user-guide/SETUP_GUIDE.md):** Step-by-step installation.
- **[Troubleshooting](docs/user-guide/TROUBLESHOOTING.md):** Common issues and fixes.
- **[System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md):** Technical deep dive.
- **[Avatar System](docs/architecture/AVATAR_SYSTEM.md):** Evolving avatar architecture.
- **[Desktop Control](docs/architecture/DESKTOP_CONTROL.md):** GUI automation and system integration.
- **[Vision System](docs/architecture/VISION_SYSTEM.md):** Screen and camera capabilities.

## 🖼️ Screenshots

<div align="center">
  <img src="assets/screenshots/app_home.png" width="800" alt="Home Screen">
  <p><em>Home Screen - Unified Chat Interface</em></p>
</div>

## 🛠️ Development

### Tech Stack

- **Frontend:** Flutter 3.5+ (Linux, Windows, Web)
- **Agent Engine:** [OpenClaw Gateway](https://github.com/openclaw/openclaw) (localhost:18789)
- **Backend:** Node.js 22.x (Express.js)
- **Local Database:** SQLite via Drift (LocalBrain)
- **Authentication:** Auth0

### Build from Source

1.  **Clone:** `git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git`
2.  **Start OpenClaw:** Ensure OpenClaw Gateway is running on `localhost:18789`
3.  **Deps:** `flutter pub get` && `(cd services/api-backend && npm install)`
4.  **Run:** `flutter run -d linux` (Desktop) or `flutter run -d chrome` (Web)

## 📄 License

This project is licensed under the **MIT License**.

# Trigger deployment
