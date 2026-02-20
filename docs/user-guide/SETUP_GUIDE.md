# CloudToLocalLLM Setup Guide

Welcome to CloudToLocalLLM — your privacy-first desktop AI companion.

---

## Overview

CloudToLocalLLM requires **OpenClaw Gateway** to run AI models locally on your computer. This guide walks you through setting up both the Gateway and the CloudToLocalLLM application.

**Privacy First**: All AI processing happens locally. Cloud features are optional.

---

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|----------|-------------|
| **OS** | Windows 10+, Ubuntu 20.04+ | Windows 11, Ubuntu 22.04+ |
| **RAM** | 8 GB | 16 GB+ |
| **GPU** | None (CPU mode) | NVIDIA RTX 30/40 series |
| **Storage** | 500 MB free space | 2 GB+ for models |
| **Internet** | For download only | For cloud features (optional) |

---

## Step 1: Install OpenClaw Gateway

OpenClaw Gateway is the local AI engine that powers CloudToLocalLLM.

### Download

Get OpenClaw Gateway from:
- **GitHub**: [https://github.com/openclaw/openclaw/releases](https://github.com/openclaw/openclaw/releases)

### Install

**Linux**:
```bash
# Download
wget https://github.com/openclaw/openclaw/releases/latest/download/openclaw-linux-amd64

# Make executable
chmod +x openclaw-linux-amd64

# Move to PATH
sudo mv openclaw-linux-amd64 /usr/local/bin/openclaw
```

**Windows**:
1. Download `openclaw-windows.exe`
2. Place in a folder (e.g., `C:\OpenClaw\`)
3. Add to PATH if desired

### Verify Installation

```bash
# Run help
openclaw --help

# Check version
openclaw --version
```

---

## Step 2: Start OpenClaw Gateway

### Start the Gateway

**Linux**:
```bash
openclaw serve --port 18789
```

**Windows**:
```cmd
openclaw-windows.exe serve --port 18789
```

### Verify It's Running

Open a new terminal and test:
```bash
curl http://localhost:18789/health
```

Expected response:
```json
{"status": "ok", "version": "1.0.0"}
```

### GPU Setup (Optional but Recommended)

If you have an NVIDIA GPU:

1. **Install NVIDIA Drivers**:
   ```bash
   # Ubuntu
   sudo apt install nvidia-driver-535
   ```

2. **Install CUDA** (if not already installed)

3. **Verify GPU**:
   ```bash
   nvidia-smi
   ```

4. **Start OpenClaw with GPU**:
   ```bash
   openclaw serve --port 18789 --gpu
   ```

---

## Step 3: Install CloudToLocalLLM

### Download

Get the latest release for your platform:
- **GitHub**: [https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases)

### Install

**Windows**:
1. Download `CloudToLocalLLM-setup.exe`
2. Run the installer
3. Launch from Start Menu

**Linux (AppImage)**:
```bash
# Download
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-linux.AppImage

# Make executable
chmod +x CloudToLocalLLM-linux.AppImage

# Run
./CloudToLocalLLM-linux.AppImage
```

**Linux (Deb Package)**:
```bash
# Download
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm_amd64.deb

# Install
sudo dpkg -i cloudtolocalllm_amd64.deb

# Launch
cloudtolocalllm
```

---

## Step 4: First Run Setup Wizard

When you first launch CloudToLocalLLM, the **Setup Wizard** will guide you:

### Welcome Screen

Click "Get Started" to begin.

### Connection Method Selection

Choose how you connect to OpenClaw Gateway:

1. **Local on this computer** — OpenClaw running on localhost:18789
2. **Remote via Tailscale** — OpenClaw on your tailnet or VPS
3. **Custom remote URL** — SSH tunnel, VPN, or custom URL

### Provider Detection

The wizard will automatically scan for OpenClaw Gateway:
- **Local**: Scans localhost:18789
- **Tailscale**: Lists devices on your tailnet
- **Custom**: Enter your URL manually

### Connection Test

The wizard tests the connection to ensure everything works.

### Complete

Click "Proceed to Chat" to start using CloudToLocalLLM!

---

## Alternative Providers (Optional)

CloudToLocalLLM also supports other local LLM providers:

### LM Studio

1. Download from [lmstudio.ai](https://lmstudio.ai)
2. LM Studio runs on `localhost:1234`
3. CloudToLocalLLM will auto-detect it

### Ollama

1. Install from [ollama.com](https://ollama.com)
2. Ollama runs on `localhost:11434`
3. CloudToLocalLLM will auto-detect it

---

## Cloud Features (Optional)

Cloud features are **not required** for local use.

### Account (Optional)

- Create an account to sync conversations across devices
- **Not required** for local chat

### Remote Access (Optional)

- Access your AI from other devices via Tailscale or SSH
- Requires OpenClaw Gateway to be accessible remotely

---

## System Tray (Desktop)

Once installed, CloudToLocalLLM runs in your system tray:

- **Windows**: Look in the notification area (system tray)
- **Linux**: Look in the top panel

**Tray Menu**:
- Show/Hide window
- Connection status
- Settings
- Quit

---

## Auto-Start (Optional)

### Linux

Create a systemd service or add to startup applications.

### Windows

1. Win+R, type `shell:startup`
2. Create a shortcut to CloudToLocalLLM

---

## Verify Installation

Once everything is set up:

1. **Open CloudToLocalLLM**
2. **Check Connection Status**: Should show "Connected"
3. **Start a Chat**: Type "Hello!" to test

---

## Upgrading

### OpenClaw Gateway

```bash
# Download latest
wget https://github.com/openclaw/openclaw/releases/latest/download/openclaw-linux-amd64

# Replace
sudo mv openclaw-linux-amd64 /usr/local/bin/openclaw
```

### CloudToLocalLLM

Download the latest release and install over your existing version.

---

## Uninstalling

### OpenClaw Gateway

```bash
# Linux
sudo rm /usr/local/bin/openclaw

# Windows
del C:\OpenClaw\openclaw-windows.exe
```

### CloudToLocalLLM

**Windows**:
Use "Add or Remove Programs" in Windows Settings

**Linux**:
```bash
sudo apt remove cloudtolocalllm
# Or delete the AppImage
```

---

## Need Help?

- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Features**: [FEATURES_GUIDE.md](FEATURES_GUIDE.md)
- **User Guide**: [USER_GUIDE.md](USER_GUIDE.md)
- **Issues**: [GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
