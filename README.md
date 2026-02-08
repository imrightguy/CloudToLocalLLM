# CloudToLocalLLM
 
<div align="center">
 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.5%2B-blue.svg)](https://flutter.dev)
[![Node.js Version](https://img.shields.io/badge/Node.js-24%2B-green.svg)](https://nodejs.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Web-lightgrey.svg)]()
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange.svg)]()
 
**CloudToLocalLLM: A privacy-first local AI assistant with voice, desktop awareness, and intelligent automation.**
 
[Key Features](#key-features) • [Download & Install](#-download--install) • [Documentation](#-documentation) • [Development](#-development)
 
</div>
 
---
 
## 🚀 Overview
 
**CloudToLocalLLM** is your private, local AI assistant that lives on your desktop. Powered by local LLMs (Ollama) and optional cloud relay, it combines the privacy of local AI with intelligent voice interaction and desktop automation.
 
> **The Vision:** A local alternative to cloud AI assistants - one that listens, sees, and helps without your data ever leaving your machine.
 
## ✨ Key Features
 
*   **🔒 Privacy-First:** Everything runs locally. Your conversations and desktop activity never leave your device.
*   **🎙️ Voice Assistant:** Natural voice conversations using local STT (Whisper) and TTS - talk to your AI like a real assistant.
*   **👁️ Desktop Awareness:** See your screen, understand context, and help with what you're working on.
*   **🖱️ Desktop Automation:** Execute tasks through voice commands - open apps, manage windows, automate workflows.
*   **💻 Cross-Platform:** Native support for **Windows** and **Linux**, with a responsive **Web** interface.
*   **⚡ Hybrid Architecture:** Seamlessly switch between local models (Ollama) and cloud fallbacks.
*   **☁️ Optional Cloud Relay:** Secure remote access when you need it, without compromising local privacy.
 
## 📋 Prerequisites
 
To use CloudToLocalLLM locally:
 
*   **[Ollama](https://ollama.com/download):** The engine that runs the AI models.
    *   Pull a model: `ollama pull llama3.2`
 
## 📥 Download & Install
 
### Windows & Linux
1.  Go to the **[Latest Releases](https://github.com/CloudToLocalLLM/CloudToLocalLLM/releases/latest)** page.
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
*   **[Voice & Desktop Control](docs/development/features/):** Voice interface and desktop automation documentation.

 
## 🛠️ Development
 
### Tech Stack
*   **Frontend:** Flutter (Linux, Windows, Web)
*   **Backend:** Node.js (Express.js)
*   **Authentication:** Auth0
*   **Local AI:** Ollama (Llama, Mistral, etc.)
*   **Voice:** Whisper (STT), local TTS integration
*   **Desktop Automation:** PyAutoGUI, UI-TARS, or similar
*   **Deployment:** Azure (Cloud) or Docker Compose (Self-Hosted)
 
### Voice & Desktop Control (Coming Soon)
CloudToLocalLLM is evolving to support:
- **Voice Input:** Local Whisper STT for privacy-first speech recognition
- **Voice Output:** TTS integration for natural voice responses
- **Screen Awareness:** Desktop context for smarter assistance
- **Desktop Control:** Voice-guided automation of common tasks

### Build from Source
 
1.  **Clone:** `git clone https://github.com/CloudToLocalLLM/CloudToLocalLLM.git`
2.  **Deps:** `flutter pub get` && `(cd services/api-backend && npm install)`
3.  **Run:** `flutter run -d linux` (Desktop) or `flutter run -d chrome` (Web)
 
## 📄 License
 
This project is licensed under the **MIT License**.
