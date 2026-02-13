# CloudToLocalLLM 🦞
 
<div align="center">
 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.5%2B-blue.svg)](https://flutter.dev)
[![Node.js Version](https://img.shields.io/badge/Node.js-24%2B-green.svg)](https://nodejs.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Web-lightgrey.svg)]()
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange.svg)]()
 
**Your private AI companion. Chat locally with your personal agent, watch your avatar evolve, and own your data. Cloud features expand your reach to mobile and beyond.**
 
*Brought to you by Zoidbot — privacy-first local AI with claws.* 🦞
 
[Key Features](#key-features) • [Download & Install](#-download--install) • [Documentation](#-documentation) • [Development](#-development)
 
</div>
 
---
 
## 🚀 Overview
 
**CloudToLocalLLM** is your private gateway to a personal AI companion. Designed for privacy-conscious users, it enables secure, local conversations with your AI agent while giving you complete ownership of your data. Your agent grows and evolves through an avatar system, creating a truly personal AI experience. Optional cloud connectivity extends your reach to mobile devices without compromising privacy.
 
> **Note:** The project is currently in **Heavy Development/Early Access**.

## ✨ Key Features

*   **🔒 Privacy-First:** All conversations processed locally by **OpenClaw**. Your data never leaves your device unless you choose.
*   **🦞 Personal AI Agent:** Your own evolving AI companion with memory, personality, and capabilities.
*   **🎨 Growing Avatar:** Watch your agent's avatar evolve and grow as you interact.
*   **💻 Cross-Platform:** Native support for **Windows** and **Linux**, with responsive **Web** and **Mobile** interfaces.
*   **☁️ Optional Cloud:** Extend your reach to mobile devices with secure, encrypted cloud relay.
*   **🎮 GUI Automation:** Control desktop applications using Vision-Language Models (powered by OpenClaw).
*   **🏠 You Own Everything:** Data, models, agent state — all stored locally.

## 📋 Prerequisites

To use CloudToLocalLLM locally:

*   **[OpenClaw Gateway](https://github.com/openclaw/openclaw):** The primary engine for all LLM and Vision tasks.
*   **[NVIDIA Drivers](https://www.nvidia.com/drivers):** Required for GPU acceleration (RTX 30/40 series recommended).

## 📥 Download & Install

### Windows & Linux
1.  Go to the **[Latest Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)** page.
2.  Download the installer or executable (`.exe` for Windows, `.AppImage` for Linux).
3.  Launch the application.

### Web Version
Latest web deployment: **[cloudtolocalllm.online](https://cloudtolocalllm.online)**

## 📖 Documentation

*   **[User Guide](docs/user-guide/USER_GUIDE.md):** Features and detailed usage.
*   **[Setup Guide](docs/user-guide/SETUP_GUIDE.md):** Step-by-step installation.
*   **[Troubleshooting](docs/user-guide/TROUBLESHOOTING.md):** Common issues and fixes.
*   **[Self-Hosting Guide](docs/operations/SELF_HOSTING.md):** Run your own relay server.
*   **[System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md):** Technical deep dive.

## 🖼️ Screenshots

<div align="center">
  <img src="assets/screenshots/app_home.png" width="800" alt="Home Screen">
  <p><em>Home Screen - Unified Chat Interface</em></p>
</div>

## 🛠️ Development

### Tech Stack
*   **Frontend:** Flutter (Linux, Windows, Web)
*   **Backend:** Node.js (Express.js)
*   **Authentication:** Auth0
*   **Deployment:** Azure (Cloud) or Docker Compose (Self-Hosted)

### Build from Source

1.  **Clone:** `git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git`
2.  **Deps:** `flutter pub get` && `(cd services/api-backend && npm install)`
3.  **Run:** `flutter run -d linux` (Desktop) or `flutter run -d chrome` (Web)

## 📄 License

This project is licensed under the **MIT License**.
# Trigger deployment
