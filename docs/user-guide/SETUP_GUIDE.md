# CloudToLocalLLM Setup Guide

CloudToLocalLLM is a privacy-first companion shell for a runtime you choose during setup. It can connect to Hermes, OpenClaw, LM Studio, Ollama, or another compatible endpoint running on this device, another device in your tailnet, or an optional hosted runtime.

There is no universal default runtime. Hermes is the first runtime path used for current testing. OpenClaw remains supported as the original integration target.

---

## Prerequisites

| Requirement | Minimum | Recommended |
| --- | --- | --- |
| OS | Windows 10+, Ubuntu 20.04+ | Windows 11, Ubuntu 22.04+ |
| RAM | 8 GB | 16 GB+ |
| GPU | None | NVIDIA GPU for local model acceleration |
| Storage | 500 MB app space | 2 GB+ plus model storage |
| Runtime | Hermes, OpenClaw, LM Studio, Ollama, or compatible endpoint | Hermes for current test path |
| Secure mesh | Optional | Tailscale for multi-device and remote runtime paths |

Cloud features are optional. Local runtime use should work without a CloudToLocalLLM-hosted runtime.

---

## Step 1: Choose A Runtime

Choose where your agent runtime will run before or during the setup wizard.

### Hermes

Use Hermes first when validating the current CloudToLocalLLM direction. Install and start Hermes according to the Hermes project instructions, then provide its endpoint in the setup wizard.

### OpenClaw Gateway

OpenClaw was the original runtime integration and remains supported.

Typical local endpoint:

```bash
http://localhost:18789
```

Health check:

```bash
curl http://localhost:18789/health
```

### LM Studio

LM Studio provides an OpenAI-compatible local endpoint.

Typical local endpoint:

```bash
http://localhost:1234
```

Model check:

```bash
curl http://localhost:1234/v1/models
```

### Ollama

Ollama can be used as a local model runtime.

Typical local endpoint:

```bash
http://localhost:11434
```

Model check:

```bash
curl http://localhost:11434/api/tags
```

### Custom Runtime

Use a custom endpoint for a private server, local gateway, or compatible OpenAI-style API. For remote runtimes, prefer putting the runtime device inside your Tailscale tailnet.

---

## Step 2: Install CloudToLocalLLM

### Download

Get the latest release for your platform:

- [CloudToLocalLLM releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases)

### Windows

1. Download the Windows installer.
2. Run the installer.
3. Launch CloudToLocalLLM from the Start Menu.

### Linux AppImage

```bash
chmod +x CloudToLocalLLM-linux.AppImage
./CloudToLocalLLM-linux.AppImage
```

### Linux Deb Package

```bash
sudo dpkg -i cloudtolocalllm_amd64.deb
cloudtolocalllm
```

---

## Step 3: Complete The Setup Wizard

The setup wizard is the authority for the first working configuration.

### Runtime Selection

Select the runtime you want this device to use:

- Hermes
- OpenClaw Gateway
- LM Studio
- Ollama
- Custom endpoint

### Runtime Location

Choose where that runtime lives:

- This computer
- Another device in your Tailscale tailnet
- A private server or VPS in your tailnet
- Optional CloudToLocalLLM-hosted runtime container

### Connection Test

The wizard checks:

- Runtime health
- Available models
- Streaming support
- Voice and vision capabilities when exposed
- Network reachability through localhost, LAN, Tailscale, or custom URL

### Desktop Permissions

Grant only the permissions this device should expose:

- Screen capture
- Region capture
- Clipboard
- Window management
- Keyboard and mouse actions
- Shell commands
- File access

These permissions are device-scoped. Syncing your account does not automatically enable desktop control on every device.

### Optional Device Sync

Enable account-backed sync if you want:

- Conversation state across installed devices
- Runtime presence and device availability
- Shared avatar preferences
- Web or mobile access through a connector

---

## Step 4: Configure Tailscale For Remote Devices

Tailscale is the preferred secure transport for remote runtime and multi-device usage.

1. Install Tailscale on each device that should participate.
2. Sign in to the same tailnet.
3. Confirm devices can reach each other:

```bash
tailscale status
tailscale ping <runtime-device-name>
```

4. In CloudToLocalLLM, choose the runtime device or enter its tailnet endpoint.

### Cloud Connector

For web/mobile access or cloud coordination, CloudToLocalLLM should add an isolated per-user connector container to the user's tailnet. That connector coordinates sync and reachability. It does not grant desktop permissions by itself.

### Hosted Runtime

Running the agent runtime in CloudToLocalLLM-hosted infrastructure is an optional paid compute path. It should use a per-user isolated container and join the user's tailnet only after setup approval.

---

## Step 5: Verify The Setup

1. Open CloudToLocalLLM.
2. Confirm the main channel shows a connected runtime.
3. Send a short test message.
4. Open the avatar/voice companion sidecar.
5. If using desktop control, run a low-risk permission test such as screenshot or notification.
6. If using Tailscale, test from a second device.

---

## System Tray

On desktop platforms, CloudToLocalLLM can run from the system tray.

- Show or hide the main window.
- Open the avatar/voice companion.
- View connection status.
- Open settings.
- Quit the app.

---

## Troubleshooting

### Runtime Not Found

- Confirm the runtime is running.
- Check the endpoint and port.
- Use the wizard connection test.
- For remote runtimes, confirm Tailscale connectivity.

### Hermes Path Not Working

- Verify the Hermes service is running.
- Confirm the endpoint configured in the wizard.
- Check whether Hermes exposes the capabilities required by the selected feature.

### Remote Device Not Reachable

```bash
tailscale status
tailscale ping <device-name-or-ip>
```

Confirm both devices are in the same tailnet and that the runtime is listening on the expected interface.

### Desktop Control Not Working

- Grant permissions on the device being controlled.
- Check that the action type is enabled.
- Review pending approvals.
- Confirm platform support for the requested action.
