# CloudToLocalLLM User Guide

CloudToLocalLLM is a privacy-first companion shell for Hermes, OpenClaw, and other local or private agent runtimes. It gives the selected runtime a secure channel to you, plus controlled access to desktop, vision, voice, avatar, and multi-device sync features.

The setup wizard decides which runtime and device path to use. There is no universal default runtime. Hermes is the first runtime path used for current testing, while OpenClaw remains a supported runtime and the original integration target.

---

## Overview

CloudToLocalLLM is organized around six core pillars:

1. **Secure Agent Channel** - The main window is a direct, low-friction channel to the selected runtime.
2. **Avatar And Voice Companion** - A sidecar companion window for avatar presence and voice interaction.
3. **Desktop Control** - Permissioned hands-on access to the current desktop.
4. **Vision** - Screen, region, OCR, and camera understanding.
5. **Runtime And Agent Management** - Runtime discovery, health, models, tools, and agent sessions.
6. **Secure Device Mesh** - Tailscale-first connectivity and optional cloud sync across your devices.

Agent management is still available, but it is not the first thing in the interface. The first screen should feel like a secure conversation path to the active runtime.

---

## Getting Started

### First Run

When you first launch CloudToLocalLLM, the setup wizard guides you through the decisions that matter:

1. **Choose a runtime**
   - Hermes on this machine or another device
   - OpenClaw Gateway
   - LM Studio
   - Ollama
   - Custom OpenAI-compatible endpoint

2. **Choose where the runtime lives**
   - This computer
   - Another device on your Tailscale tailnet
   - A private server or VPS in your tailnet
   - Optional CloudToLocalLLM-hosted runtime container

3. **Test the connection**
   - The wizard checks health, available models, and streaming support.
   - Hermes is the first runtime path to validate during current testing.

4. **Set desktop permissions**
   - Desktop control, clipboard, file actions, vision, and command execution are enabled per device.
   - Remote devices cannot receive desktop actions unless that device grants them.

5. **Enable optional sync**
   - Conversation state and presence can sync between installed devices.
   - Local desktop permissions and action approvals remain device-scoped.

### Runtime Discovery

The app can discover common local runtimes:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | Configured by wizard | First runtime path for current testing |
| OpenClaw Gateway | `localhost:18789` | Supported original integration |
| LM Studio | `localhost:1234` | OpenAI-compatible local provider |
| Ollama | `localhost:11434` | Local model runtime |
| Custom endpoint | User supplied | Private runtime, server, or compatible API |

---

## Secure Agent Channel

The main app window is the direct channel to the selected runtime.

### Chat Features

- Streaming responses
- Conversation history
- Model selection when the runtime exposes multiple models
- Search across conversations
- Import and export
- Runtime status and connection health

### Runtime Switching

Runtime and agent management lives behind settings, setup, and management views. Use it to:

- Add or remove runtime endpoints
- Test health and streaming
- Select models
- Inspect active agent sessions
- Review available tools and capabilities

---

## Avatar And Voice Companion

The avatar and voice companion are one feature surface. The companion can appear as a sidecar or pop-out window, so it can stay open beside the main app or another desktop workflow.

### Companion Features

- Avatar state: idle, listening, thinking, speaking, working, error
- Voice conversation mode
- Push-to-talk and planned wake/listening flows
- Text-to-speech through the selected runtime or CloudToLocalLLM fallback services
- Personality, memory, and evolution features as they mature

The companion should not replace the main secure channel. It provides presence, voice, and side conversation while the main window remains focused on the active runtime conversation.

---

## Desktop Control

Desktop control is a core feature. It gives the selected runtime controlled hands-on capability on the current device.

### Capabilities

- Screenshot capture
- Region capture
- Vision analysis
- Click, type, and keyboard actions
- Clipboard actions
- Window management
- System notifications
- Command execution when explicitly enabled

### Safety Model

- Desktop actions are local to the device granting permission.
- Visual indicators show when automation or capture is active.
- Sensitive actions should require explicit user approval.
- Action history should be reviewable.
- Cloud sync does not imply permission to control every synced device.

---

## Vision

Vision features let the runtime understand what is on the current device.

- Full-screen capture
- Region capture
- OCR and text extraction
- Camera input where supported
- Continuous watch modes for selected regions

Vision permissions are per device and should be visible while active.

---

## Secure Device Mesh

CloudToLocalLLM is designed to be installed on all your devices and kept in sync.

Tailscale is the preferred secure transport. Instead of maintaining a separate custom tunnel stack as the main path, CloudToLocalLLM should use the user's tailnet wherever possible.

### Typical Layouts

- Laptop app connects to Hermes running on the same laptop.
- Desktop app connects to Hermes or OpenClaw running on a workstation in the same tailnet.
- Phone or web session connects through a per-user cloud connector that has joined the user's tailnet.
- Optional paid cloud runtime runs in an isolated per-user container and joins the user's tailnet only after setup approval.

### What Syncs

- Conversation state
- Runtime presence
- Device availability
- Avatar state and preferences
- Non-sensitive settings selected for sync

### What Stays Device-Scoped

- Desktop control permissions
- Clipboard access
- File access
- Screen and camera capture
- Shell command permissions
- Runtime secrets and local tokens unless explicitly stored in an approved secure vault

---

## Settings

### Runtime Settings

- Add, remove, and test runtime endpoints
- Configure Hermes, OpenClaw, LM Studio, Ollama, or custom providers
- Set preferred runtime per device
- Review detected capabilities

### Companion Settings

- Show or hide avatar
- Open companion sidecar
- Configure voice mode
- Choose text-to-speech voice when available

### Mesh And Cloud Settings

- Enable Tailscale-based device connectivity
- Add the optional cloud connector to your tailnet
- Review connected devices
- Enable or disable conversation sync
- Configure optional hosted runtime compute

### Privacy

- Offline mode
- Local-only storage
- Per-device desktop permissions
- Data export and deletion

---

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Runtime Not Found

- Confirm the runtime is running.
- Check the endpoint and port in runtime settings.
- Use the setup wizard connection test.
- For remote devices, check that both devices are on the expected Tailscale tailnet.

### Connection Lost

- Check runtime health.
- Verify Tailscale status for remote runtime paths.
- Re-run the wizard connection test.
- Switch to another configured runtime if available.

### Desktop Control Not Working

- Confirm desktop permissions were granted on that specific device.
- Check platform support for the requested action.
- Verify that the desktop control service is running.
- Review action approvals and denied permissions.

### Voice Companion Not Working

- Confirm the companion window is open.
- Check microphone permission where voice input is enabled.
- Verify that the runtime or fallback TTS service supports speech output.

---

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl + N` | New conversation |
| `Ctrl + /` | Focus search |
| `Ctrl + S` | Open settings |
| `Escape` | Close modal or drawer |
