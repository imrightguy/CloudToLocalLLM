# CloudToLocalLLM Features Guide

## 📋 Overview

CloudToLocalLLM is an **OpenClaw Agent Manager** that provides a comprehensive suite of features for local AI agent management. This guide covers all core features and capabilities.

---

## 🎯 Core Features

### 1. Chat Interface

| Feature           | Description                            |
| ----------------- | -------------------------------------- |
| **Unified Chat**  | Main interaction point with the agent  |
| **Streaming**     | Real-time token-by-token responses     |
| **Conversations** | Create, save, organize multiple chats  |
| **History**       | Persistent message history with search |
| **Multi-Model**   | Switch between available LLM models    |

### 2. OpenClaw Gateway Management

| Feature               | Description                                        |
| --------------------- | -------------------------------------------------- |
| **Service Control**   | Start, stop, restart OpenClaw Gateway from the app |
| **Health Monitoring** | Real-time status, latency, and error tracking      |
| **Configuration**     | Manage gateway settings, models, and capabilities  |
| **Auto-discovery**    | Automatically detect OpenClaw on localhost:18789   |

### 3. Evolving Avatar

| Feature | Description |
|----------|-------------|
| **Visual Character** | Avatar with emoji-based reactions to system state |
| **State Reactions** | Idle, thinking, working, error, happy states |
| **Planned: Growth System** | XP and levels tied to interactions |
| **Planned: Personality** | Memory, traits, and learned preferences |
| **Planned: Achievements** | Unlockable milestones and rewards |

### 4. Desktop Control

| Feature | Status |
|----------|--------|
| **GUI Automation** | ✅ Screenshot capture and vision analysis |
| **System Commands** | ✅ Execute shell commands |
| **Notifications** | ✅ System notifications |
| **Planned: Window Management** | Move, resize, focus windows |
| **Planned: Clipboard** | Read and write clipboard content |
| **Planned: File Operations** | File browser and operations |
| **Planned: Macros** | Record and replay action sequences |

### 5. Vision Capabilities

| Feature | Status |
|----------|--------|
| **Screen Capture** | ✅ Full-screen screenshots |
| **Screen Analysis** | ✅ Vision analysis via OpenClaw |
| **Planned: Region Capture** | Select and capture specific regions |
| **Planned: OCR** | Text extraction from images |
| **Planned: Camera Input** | Webcam capture for real-time vision |
| **Planned: Continuous Monitor** | Watch screen regions for changes |

---

## 🔐 Authentication

- **Auth0 Integration**: Enterprise-grade authentication
- **Desktop**: Native Auth0 flow with encrypted token storage
- **Web**: Session-based authentication via auth0-bridge

---

## 🔌 Integrations

### OpenClaw Gateway

1. **Install**: [OpenClaw GitHub](https://github.com/openclaw/openclaw)
2. **Start**: Ensure OpenClaw runs on `localhost:18789`
3. **Verify**: `curl http://localhost:18789/health`

### LM Studio (Optional)

CloudToLocalLLM also supports LM Studio as an alternative local provider:

- **Port**: localhost:1234
- **Auto-discovery**: Automatic model detection

---

## 📁 Data & Storage

| Location                          | Description              |
| --------------------------------- | ------------------------ |
| `~/.config/cloudtolocalllm/`      | Configuration files      |
| `~/.local/share/cloudtolocalllm/` | Logs and data            |
| LocalBrain (SQLite)               | Encrypted local database |

---

## 🐛 Troubleshooting

### OpenClaw Connection Issues

```bash
# Test gateway health
curl http://localhost:18789/health

# Check if port is in use
netstat -tlnp | grep 18789
```

### Logs

- **Linux**: `~/.local/share/cloudtolocalllm/logs/`
- **Windows**: `%LOCALAPPDATA%\cloudtolocalllm\logs\`

---

## 📚 Documentation

- [SPEC.md](../../SPEC.md) - Master specification
- [Setup Guide](SETUP_GUIDE.md) - Installation instructions
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
- [Architecture](../architecture/SYSTEM_ARCHITECTURE.md) - Technical details
