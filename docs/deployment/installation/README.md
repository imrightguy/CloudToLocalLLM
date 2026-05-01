# CloudToLocalLLM Installation Guide

This directory contains platform-specific installation guides for CloudToLocalLLM.

CloudToLocalLLM does not require one default runtime. During first launch, the setup wizard connects the app to an agent runtime such as Hermes, OpenClaw, or a compatible custom agent gateway. Hermes is the first agent runtime path for current testing.

Ollama, LM Studio, and similar model servers are optional support model providers for memory and background app features. They are not primary app runtimes.

---

## Platform Guides

- [Linux Installation](LINUX.md) - Ubuntu, Debian, Arch, AppImage, and source builds
- [Windows Installation](WINDOWS.md) - Windows 10/11 desktop app
- [macOS Installation](MACOS.md) - Planned and development notes

---

## Prerequisites

### Agent Runtime

Install or prepare at least one agent runtime before completing setup:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | Configured in wizard | First agent runtime path for current testing |
| OpenClaw Gateway | `http://localhost:18789` | Supported original integration |
| Custom agent gateway | User supplied | Private server, VPS, or compatible agent runtime API |
| Hosted agent runtime | CloudToLocalLLM managed | Optional paid compute |

Most users should run the agent runtime locally or on another machine they control. Running an agent runtime in CloudToLocalLLM-hosted infrastructure is optional paid compute and should use an isolated per-user container.

### Optional Support Model Provider

Configure a support model provider only if app-owned features need local model help:

| Provider | Typical Endpoint | Use |
| --- | --- | --- |
| LM Studio | `http://localhost:1234` | Local model support for app features |
| Ollama | `http://localhost:11434` | Local model support for memory/background features |
| Custom model endpoint | User supplied | Local support model provider |

### Secure Device Mesh

Tailscale is recommended for remote agent runtimes and multi-device sync.

1. Install Tailscale on each device.
2. Sign in to the same tailnet.
3. Confirm device reachability:

```bash
tailscale status
tailscale ping <runtime-device-name>
```

The cloud connector, when enabled, should join the user's tailnet as an isolated per-user container.

### System Requirements

- RAM: minimum 4 GB, recommended 8 GB+
- Storage: 2 GB for the app plus storage for local agent runtimes/models
- Network: internet for downloads, account sync, and optional cloud features
- OS: see the platform-specific guide for detailed requirements

---

## Installation Overview

### 1. Prepare An Agent Runtime

Start Hermes, OpenClaw, or another compatible agent gateway on this device or a reachable tailnet device.

### 2. Optionally Prepare A Support Model Provider

Start Ollama, LM Studio, or a custom local model endpoint only if you want memory or background features to use it.

### 3. Install CloudToLocalLLM

Choose the platform-specific installation method:

- Package manager or `.deb` package on Linux
- AppImage on Linux
- Windows installer or portable build on Windows
- Source build for development

### 4. Complete First-Time Setup

The setup wizard will:

- Select the agent runtime
- Test connectivity
- Detect sessions, tools, and capabilities where supported
- Configure optional local model support
- Configure desktop permissions on this device
- Offer optional Tailscale-based device sync

### 5. Open The Main Channel

The main window opens as the secure channel to the selected agent runtime. Agent/runtime management stays available in setup, settings, and management views.

### 6. Optional Companion And Mesh

- Open the avatar/voice companion as a sidecar window.
- Enable account sync for conversations and presence.
- Add the cloud connector to the user's tailnet when web/mobile access is needed.

---

## Installation Methods Comparison

| Method | Pros | Cons | Best For |
| --- | --- | --- | --- |
| Package manager | Easy updates, system integration | Platform-specific | Regular desktop users |
| Installer | Guided setup | Larger download | First-time users |
| Portable | No install, easy to move | Manual updates | Testing and temporary use |
| Source build | Latest changes, customizable | Requires development tools | Developers |

---

## Need Help?

- [Setup Guide](../../user-guide/SETUP_GUIDE.md)
- [User Guide](../../user-guide/USER_GUIDE.md)
- [Troubleshooting](../../user-guide/TROUBLESHOOTING.md)
- [Agent Runtime Contract](../../architecture/AGENT_RUNTIME_CONTRACT.md)
- [Secure Device Mesh](../../architecture/SECURE_DEVICE_MESH.md)
- [GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
- [GitHub Discussions](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/discussions)

---

## Updating CloudToLocalLLM

### Automatic Updates

- Package manager installations receive updates through the platform package flow.
- Application update checks should preserve settings and local data.

### Manual Updates

Download the latest release and install it over the existing app. Settings, local data, and configured agent runtime/support model endpoints should be preserved.

---

## Uninstalling

### Linux Package

```bash
sudo apt remove cloudtolocalllm
```

### Windows

Use "Add or Remove Programs" in Windows Settings, or run the uninstaller from the Start Menu.

### Portable Builds

Delete the application folder. Optionally remove configuration and data directories if you no longer need local settings or logs.
