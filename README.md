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

### One-Line Installer (Recommended)

Quickly install CloudToLocalLLM and OpenClaw Gateway with a single command:

**Linux / macOS:**
```bash
curl -fsSL https://cloudtolocalllm.online/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://cloudtolocalllm.online/install.ps1 | iex
```

### Manual Installation

#### Windows & Linux

1.  Go to the **[Latest Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)** page.
2.  Download the installer or executable (`.exe` for Windows, `.AppImage` for Linux).
3.  Launch the application.

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
