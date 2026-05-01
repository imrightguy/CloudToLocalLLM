# CloudToLocalLLM Installation Guide

This directory contains platform-specific installation guides for CloudToLocalLLM.

CloudToLocalLLM does not require one default runtime. During first launch, the setup wizard connects the app to Hermes, OpenClaw, LM Studio, Ollama, or another compatible runtime. Hermes is the first runtime path for current testing.

---

## Platform Guides

- [Linux Installation](LINUX.md) - Ubuntu, Debian, Arch, AppImage, and source builds
- [Windows Installation](WINDOWS.md) - Windows 10/11 desktop app
- [macOS Installation](MACOS.md) - Planned and development notes

---

## Prerequisites

### Runtime

Install or prepare at least one runtime before completing setup:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | Configured in wizard | First runtime path for current testing |
| OpenClaw Gateway | `http://localhost:18789` | Supported original integration |
| LM Studio | `http://localhost:1234` | OpenAI-compatible local runtime |
| Ollama | `http://localhost:11434` | Local model runtime |
| Custom endpoint | User supplied | Private server, VPS, or compatible API |

Most users should run the runtime locally or on another machine they control. Running a runtime in CloudToLocalLLM-hosted infrastructure is optional paid compute and should use an isolated per-user container.

### Secure Device Mesh

Tailscale is recommended for remote runtimes and multi-device sync.

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
- Storage: 2 GB for the app plus model storage for local runtimes
- Network: internet for downloads, account sync, and optional cloud features
- OS: see the platform-specific guide for detailed requirements

---

## Installation Overview

### 1. Prepare A Runtime

Start Hermes, OpenClaw, LM Studio, Ollama, or another compatible endpoint on this device or a reachable tailnet device.

### 2. Install CloudToLocalLLM

Choose the platform-specific installation method:

- Package manager or `.deb` package on Linux
- AppImage on Linux
- Windows installer or portable build on Windows
- Source build for development

### 3. Complete First-Time Setup

The setup wizard will:

- Select the runtime
- Test connectivity
- Detect available models and capabilities
- Configure desktop permissions on this device
- Offer optional Tailscale-based device sync

### 4. Open The Main Channel

The main window opens as the secure channel to the selected runtime. Runtime and agent management stays available in setup, settings, and management views.

### 5. Optional Companion And Mesh

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
- [Secure Device Mesh](../../architecture/SECURE_DEVICE_MESH.md)
- [GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
- [GitHub Discussions](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/discussions)

---

## Updating CloudToLocalLLM

### Automatic Updates

- Package manager installations receive updates through the platform package flow.
- Application update checks should preserve settings and local data.

### Manual Updates

Download the latest release and install it over the existing app. Settings, local data, and configured runtime endpoints should be preserved.

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
