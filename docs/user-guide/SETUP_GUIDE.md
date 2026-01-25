# CloudToLocalLLM Setup Guide

Welcome to CloudToLocalLLM! This guide will walk you through the initial setup process for Windows, Linux, and Web.

## 📋 Prerequisites

Before starting, ensure you have:

*   **[Ollama](https://ollama.com/download)**: The engine that runs the AI models locally.
    *   Pull a model to get started: `ollama pull llama3.2`
*   **Auth0 Account**: Used for secure authentication and cloud relay features.
*   **Internet Connection**: Required for the initial setup, model downloads, and optional cloud relay.

---

## 🚀 Setup Process

The CloudToLocalLLM setup consists of three main phases:

### 1. Local Engine Setup (Ollama)

CloudToLocalLLM relies on Ollama to run models on your hardware.

1.  **Install Ollama**: Follow instructions at [ollama.com](https://ollama.com).
2.  **Start the Service**:
    *   **Linux**: `systemctl --user enable --now ollama`
    *   **Windows/macOS**: Launch the Ollama application.
3.  **Verify**: Run `curl http://localhost:11434/api/version` in your terminal. You should see a version number.

### 2. Desktop Application Installation

1.  **Download**: Visit the **[Latest Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest)**.
2.  **Install**:
    *   **Windows**: Run the `.exe` installer.
    *   **Linux**: Make the `.AppImage` executable (`chmod +x ...`) and run it, or install the `.deb` package.
3.  **Launch**: Open the application. You should see it in your system tray.

### 3. Account & Cloud Relay Configuration

When you first launch the app, or visit the [Web Version](https://cloudtolocalllm.online), the Setup Wizard will guide you:

1.  **Login**: Use your Auth0 credentials to sign in.
2.  **Container Creation**: (Cloud/Web only) The system will provision an isolated streaming proxy for your secure remote access.
3.  **Tunnel Configuration**: 
    *   The Desktop app will automatically attempt to detect your local Ollama instance at `http://localhost:11434`.
    *   To enable remote access, ensure "Remote Access" is toggled ON in Settings.
4.  **Validation**: The wizard will test the connection between the web interface, the cloud relay, and your local machine.

---

## 💬 Your First Chat

1.  **Open the Window**: Click the tray icon or "Show CloudToLocalLLM".
2.  **Select a Model**: Use the dropdown at the top to select a model you've pulled (e.g., `llama3.2`).
3.  **Start Chatting**: Your data stays local by default!

---

## ⚙️ Key Settings

*   **Theme**: Toggle between Light, Dark, or System themes in Appearance settings.
*   **Startup**: Enable "Start with system" to keep the relay active in the background.
*   **Connection**: If you use a custom port for Ollama, update it in the Connection Settings tab.

---

## ❓ Need Help?

If you encounter issues during setup, please refer to the [Troubleshooting Guide](TROUBLESHOOTING.md).
