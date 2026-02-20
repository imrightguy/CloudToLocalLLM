# CloudToLocalLLM User Guide

**OpenClaw Agent Manager** — A privacy-first desktop AI companion.

---

## Overview

CloudToLocalLLM is organized around **Five Core Pillars**:

1. **Chat** — Unified chat interface with streaming responses
2. **OpenClaw Gateway Management** — Start, stop, monitor your local AI
3. **Evolving Avatar** — Visual character that grows with you
4. **Desktop Control** — GUI automation and system control
5. **Vision** — Screen understanding and camera input

---

## Getting Started

### First Run

When you first launch CloudToLocalLLM, you'll be guided through the **Setup Wizard**:

1. **Connection Method** — Choose how to connect to OpenClaw Gateway:
   - **Local**: OpenClaw running on this computer (localhost:18789)
   - **Tailscale**: OpenClaw on your tailnet/VPS
   - **Custom**: SSH tunnel, VPN, or custom URL

2. **Provider Detection** — The wizard automatically detects your OpenClaw Gateway

3. **Connection Test** — Verify your connection is working

4. **Complete** — Start chatting!

### Installing OpenClaw Gateway

If the wizard doesn't find OpenClaw Gateway:

- **Download**: Get OpenClaw Gateway from [GitHub](https://github.com/your-repo/openclaw)
- **Run**: `./openclaw-gateway` (Linux) or `openclaw-gateway.exe` (Windows)
- **Default Port**: 18789

---

## Pillar 1: Chat

### Starting a Conversation

1. Click the "+" button or select "New Conversation" from the drawer
2. Type your message in the input field
3. Press Enter or click Send

### Chat Features

- **Streaming Responses**: See responses generate token-by-token
- **Conversation History**: Automatically saved locally
- **Model Selection**: Switch between available models
- **Search**: Find messages across all conversations
- **Export/Import**: Backup or transfer your conversations

### Multi-Model Support

CloudToLocalLLM supports multiple local LLM providers:

| Provider | Default Port | Status |
|----------|--------------|--------|
| OpenClaw Gateway | 18789 | Primary |
| LM Studio | 1234 | Alternative |
| Ollama | 11434 | Alternative |

---

## Pillar 2: OpenClaw Gateway Management

### What is OpenClaw Gateway?

OpenClaw Gateway is your local AI engine that runs entirely on your computer. It provides:

- **LLM Models**: Text generation and chat
- **Vision Models**: Screen and image understanding
- **Agent System**: Tools, skills, and memory

### Monitoring Your Gateway

Access the **Dashboard** to view:

- **Connection Status**: Online/offline state
- **Health**: Response times and error rates
- **Active Agents**: Currently running agent sessions
- **Resource Usage**: CPU and memory consumption

### Gateway Controls

- **Start**: Launch OpenClaw Gateway
- **Stop**: Gracefully shutdown
- **Restart**: Quick restart the service
- **Auto-Restart**: Automatically restart on crash (settings)

---

## Pillar 3: Evolving Avatar

### Your AI Companion

The avatar is a visual representation of your AI that evolves over time:

- **States**: Reacts to what's happening (idle, thinking, working, happy, error)
- **Personality**: Develops traits based on your interactions
- **Leveling**: Earn XP through conversations and achievements
- **Memory**: Remembers important details from your chats

### Avatar States

| State | Appearance | Meaning |
|-------|-------------|---------|
| 🦞 Idle | Lobster resting | Ready for your input |
| 🤔 Thinking | Question mark | Processing your request |
| ⚡ Working | Lightning | Executing a task |
| 💢 Error | Angry face | Something went wrong |
| ✨ Happy | Sparkles | Success/celebration |

### Evolution System

- **XP**: Earn experience through conversations and feature usage
- **Levels**: Unlock new visual elements and features
- **Achievements**: Unlock special milestones (First Words, Social Butterfly, etc.)

---

## Pillar 4: Desktop Control

### GUI Automation

The AI can see and interact with your desktop:

- **Screenshot**: Capture what's on your screen
- **Vision Analysis**: Understand UI elements and content
- **Actions**: Click, type text, press keys
- **Automation**: Execute complex action sequences

### Using Desktop Control

1. Navigate to **Desktop Control** from the menu
2. Click **"Take Screenshot"** to capture your screen
3. The AI analyzes the screenshot
4. Request actions like "Click the Firefox icon" or "Type 'hello world'"

### System Commands

Execute system commands directly:
- Open applications
- List files
- Get system stats (CPU, RAM)
- Show notifications

### Privacy & Security

- All automation runs **locally only**
- Visual indicator when automation is active
- Full action history for review
- Explicit opt-in required for automation

---

## Pillar 5: Vision

### Screen Capture

- **Full Screen**: Capture your entire desktop
- **Region Selection**: Select a specific area to analyze
- **Continuous Monitoring**: Watch a screen region for changes

### OCR (Text Extraction)

Extract text from:
- Screenshots
- Application windows
- Images
- Camera input

### Camera Input

Use your webcam for:
- Real-time vision analysis
- Document scanning
- Object recognition

### Privacy Indicators

When vision features are active:
- Screen border highlight
- System notification
- Clear visual indicator

---

## Settings

### Provider Settings

Configure your LLM providers:
- Add/remove providers
- Set connection URLs
- Test connections
- Enable/disable auto-discovery

### Appearance

- **Theme**: Light, Dark, or System
- **Avatar Display**: Show/hide avatar
- **Font Size**: Adjust text size

### Local Mode

- **Offline Mode**: Work without any internet connection
- **Local Storage**: All data stored on your computer
- **No Cloud**: Privacy-first, everything stays local

### Cloud Features (Optional)

Cloud features are **opt-in only**:

- **Account**: Create an account for cloud sync
- **Cloud Sync**: Back up conversations to the cloud
- **Remote Access**: Access your AI from other devices (via Tailscale/SSH)

---

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Common Issues

**OpenClaw Gateway Not Found**
- Verify Gateway is running on port 18789
- Check firewall settings
- Try "Custom URL" if using alternative port

**Connection Lost**
- Check if Gateway is still running
- Verify network settings for remote connections
- Check Tailscale connection for remote gateways

**Desktop Control Not Working**
- Ensure automation permissions are granted
- Check platform compatibility (Linux/Windows supported)
- Verify system control service is running

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl + N` | New conversation |
| `Ctrl + /` | Focus search |
| `Ctrl + S` | Open settings |
| `Escape` | Close modal/drawer |

---

## Getting Help

- **Documentation**: See [README.md](../../README.md)
- **Architecture**: See [SYSTEM_ARCHITECTURE.md](../architecture/SYSTEM_ARCHITECTURE.md)
- **Implementation**: See [IMPLEMENTATION_PLAN.md](../development/IMPLEMENTATION_PLAN.md)
- **Issues**: [GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
