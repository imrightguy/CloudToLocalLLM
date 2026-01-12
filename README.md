# CloudToLocalLLM
 
<div align="center">
 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.5%2B-blue.svg)](https://flutter.dev)
[![Node.js Version](https://img.shields.io/badge/Node.js-24%2B-green.svg)](https://nodejs.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Web-lightgrey.svg)]()
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange.svg)]()
 
**A privacy-first platform to manage and run powerful Large Language Models (LLMs) locally, with an optional cloud relay for seamless remote access.**
 
[Key Features](#key-features) • [Download & Install](#-download--install) • [Documentation](#-documentation) • [Development](#-development)
 
</div>
 
---
 
## 🚀 Overview
 
**CloudToLocalLLM** bridges the gap between secure local AI execution and the convenience of cloud-based management. Designed for privacy-conscious users and businesses, it allows you to run models like Llama 3 and Mistral entirely on your own hardware while offering an optional, secure pathway for remote interaction.
 
> **Note:** The project is currently in **Heavy Development/Early Access**.
 
## ✨ Key Features
 
*   **🔒 Privacy-First:** Run models locally using [Ollama](https://ollama.com). Your data stays on your device by default.
*   **💻 Cross-Platform:** Native support for **Windows** and **Linux**, with a responsive **Web** interface.
*   **⚡ Hybrid Architecture:** Seamlessly switch between local models when needed.
*   **🔌 Extensible:** Integrated with LangChain for advanced AI workflows.
*   **☁️ Cloud Infrastructure:** Deployed on **AWS EKS** for scalable management.
*   **🏠 Self-Hosted:** Easily deploy your own instance on any Linux VPS using Docker Compose.
 
## 📋 Prerequisites
 
To use CloudToLocalLLM locally:
 
*   **[Ollama](https://ollama.com/download):** The engine that runs the AI models.
    *   Pull a model: `ollama pull llama3.2`
 
## 📥 Download & Install
 
### Windows & Linux
1.  Go to the **[Latest Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)** page.
2.  Download the installer or executable (`.exe` for Windows, `.AppImage` for Linux).
3.  Launch the application.
 
### Web Version
Latest web deployment: **[cloudtolocalllm.online](https://cloudtolocalllm.online)**
 
## 📖 Documentation
 
*   **[User Guide](docs/user-guide/USER_GUIDE.md):** Configuration and usage.
*   **[Self-Hosting Guide](docs/operations/SELF_HOSTING.md):** Run your own relay server.
*   **[System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md):** Technical deep dive.
*   **[AWS Operations](docs/operations/aws/README.md):** EKS deployment details.
 
## 🛠️ Development
 
### Tech Stack
*   **Frontend:** Flutter (Linux, Windows, Web)
*   **Backend:** Node.js (Express.js)
*   **Authentication:** Auth0
*   **Deployment:** AWS EKS (Cloud) or Docker Compose (Self-Hosted)
 
### Build from Source
 
1.  **Clone:** `git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git`
2.  **Deps:** `flutter pub get` && `(cd services/api-backend && npm install)`
3.  **Run:** `flutter run -d linux` (Desktop) or `flutter run -d chrome` (Web)
 
## 📄 License
 
This project is licensed under the **MIT License**.
