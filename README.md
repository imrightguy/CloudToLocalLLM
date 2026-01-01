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

> **Note:** The project is currently in **Heavy Development/Early Access**. Premium cloud relay features are planned but not yet live.

## ✨ Key Features

*   **🔒 Privacy-First:** Run models locally using [Ollama](https://ollama.com). Your data stays on your device by default.
*   **💻 Cross-Platform:** Native support for **Windows** and **Linux**, with a responsive **Web** interface. macOS support is in progress.
*   **⚡ Hybrid Architecture:** Seamlessly switch between local models when needed.
*   **🔌 Extensible:** Integrated with LangChain for advanced AI workflows and vector store support.
*   **📊 Monitoring:** Optional Sentry integration for error tracking and performance monitoring.
*   **☁️ Cloud Infrastructure:** Deployed on Azure AKS with provider-agnostic design for future flexibility.

## 📋 Prerequisites

To use CloudToLocalLLM locally, you only need one thing:

*   **[Ollama](https://ollama.com/download):** This is the engine that runs the AI models.
    *   After installing, pull a model to get started: `ollama pull llama3.2`

### Installed Versions (Verified on Linux)
- Flutter: 3.38.5
- Node.js: 24.12.0
- npm: 11.6.2
- Ollama: 0.13.5
- Git: 2.51.0
- Docker: 28.2.2
- kubectl: v1.35.0

Status: All CLI tools installed and verified. Run `flutter doctor`, `node --version`, `ollama --version`, `docker --version`, `kubectl version --client` to confirm.

## 📥 Download & Install

### Windows & Linux
1.  Go to the **[Latest Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)** page.
2.  Download the installer or executable for your operating system (`.exe` for Windows, `.AppImage` or `.deb` for Linux).
3.  Run the installer and launch the application.

### Web Version
You can access the latest web deployment directly at: **[cloudtolocalllm.online](https://cloudtolocalllm.online)**

## 📖 Documentation

Comprehensive documentation is available in the [`docs/`](docs/README.md) directory:

*   **[User Guide](docs/user-guide/ADMIN_CENTER_USER_GUIDE.md):** Detailed configuration and usage instructions.
*   **[Developer Onboarding Guide](docs/development/DEVELOPER_ONBOARDING.md):** Deep dive into the codebase.
*   **[Troubleshooting](docs/TROUBLESHOOTING_ARGOCD_CONNECTIVITY.md):** Solutions for common issues.

## 🛠️ Development

If you are a developer looking to contribute or build from source, follow these steps.

### Tech Stack
*   **Frontend:** Flutter (Linux, Windows, Web) - Developed natively in WSL2
*   **Backend:** Node.js (Express.js) - Native Linux runtime
*   **AI Runtime:** Ollama (Windows Host interop via `localhost`)
*   **CI/CD:** AI-powered orchestration with Kilocode CLI & xAI Grok-Code-Fast-1
*   **Development:** WSL Ubuntu 24.04 (Primary Terminal) & Kiro IDE

### Build from Source (WSL Ubuntu 24.04)

**Prerequisites:** [Flutter Linux SDK](https://docs.flutter.dev/get-started/install/linux) (3.5+), [Node.js](https://nodejs.org/) (24 LTS), and Git.

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
    cd CloudToLocalLLM
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    (cd services/api-backend && npm install)
    ```

3.  **Run the App:**
    ```bash
    flutter run -d linux   # Native Desktop
    # or
    flutter run -d chrome  # Web Interface
    ```

For full developer details, see the **[Developer Onboarding Guide](docs/development/DEVELOPER_ONBOARDING.md)**.

### AI-Powered CI/CD

CloudToLocalLLM features an innovative **unified AI-powered CI/CD system** that automatically:
*   Analyzes code changes using Kilocode CLI with xAI Grok-Code-Fast-1
*   Determines semantic version bumps (patch/minor/major)
*   Calculates which platforms need updates (cloud/desktop/mobile)
*   Deploys to multiple platforms in a single workflow execution

**Key Features:**
*   **Unified Workflow:** Single workflow handles analysis, building, and deployment
*   **Intelligent Platform Detection:** AI determines if changes affect web, desktop, or mobile platforms
*   **Authentication Priority:** Auth0 and login changes automatically trigger cloud deployments
*   **Direct Deployment:** No intermediate orchestration or platform branches required
*   **Comprehensive Status:** All deployment status visible in single workflow run
*   **Manual Overrides:** Force deployment or override platform detection when needed

See **[AI-Powered CI/CD Documentation](docs/development/AI_POWERED_CICD.md)** for detailed information.

## 🤝 Contributing

We welcome contributions! Please read our **[Contributing Guidelines](docs/DEVELOPMENT/CONTRIBUTING.md)** and check the [Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues) tab.

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

**[Website](https://cloudtolocalllm.online)** • **[GitHub](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)**

</div>

