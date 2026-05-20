# CloudToLocalLLM Setup Guide

CloudToLocalLLM is a privacy-first companion shell for an agent runtime you choose during setup. It can connect to Hermes, OpenClaw, or another compatible agent gateway running on this device, another device in your tailnet, or an optional hosted agent runtime.

There is no universal default runtime. Hermes is the first agent runtime path used for current testing. OpenClaw remains supported as the original agent integration target.

Ollama, LM Studio, and similar local model servers are optional support model providers for app-owned memory and background features. They are not the main agent endpoint.

---

## Prerequisites

| Requirement | Minimum | Recommended |
| --- | --- | --- |
| OS | Windows 10+, Ubuntu 20.04+ | Windows 11, Ubuntu 22.04+ |
| RAM | 8 GB | 16 GB+ |
| GPU | None | GPU for local agent runtime or support model acceleration |
| Storage | 500 MB app space | 2 GB+ plus model/agent runtime storage |
| Agent runtime | Hermes, OpenClaw, or compatible agent gateway | Hermes for current test path |
| Support model provider | Optional | Ollama or LM Studio for memory/background features |
| Secure mesh | Optional | Tailscale for multi-device and remote agent runtime paths |

Cloud features are optional. Local agent runtime use should work without a CloudToLocalLLM-hosted agent runtime.

---

## Step 1: Choose An Agent Runtime

Choose where your agent runtime will run before or during the setup wizard.

### Hermes

Use Hermes first when validating the current CloudToLocalLLM direction. Install and start Hermes according to the Hermes project instructions, then provide its endpoint in the setup wizard.

### OpenClaw Gateway

OpenClaw was the original agent runtime integration and remains supported.

Typical local endpoint:

```bash
http://localhost:18789
```

Health check:

```bash
curl http://localhost:18789/health
```

### Custom Agent Gateway

Use a custom endpoint for a private server, local gateway, or compatible agent runtime API. For remote runtimes, prefer putting the runtime device inside your Tailscale tailnet.

Do not use raw Ollama or LM Studio endpoints here. They are support model providers unless wrapped by an agent runtime.

---

## Step 2: Optional Local Model Support

Configure a local model provider only if you want CloudToLocalLLM app features to use it for memory or background intelligence.

### LM Studio

Typical local endpoint:

```bash
http://localhost:1234
```

Model check:

```bash
curl http://localhost:1234/v1/models
```

### Ollama

Typical local endpoint:

```bash
http://localhost:11434
```

Model check:

```bash
curl http://localhost:11434/api/tags
```

Allowed uses:

- memory embeddings
- conversation summaries
- semantic search
- local classification
- OCR cleanup
- speech helpers where supported

Not allowed:

- main agent channel target
- desktop-control authority
- substitute for Hermes/OpenClaw/custom agent gateway setup

---

## Step 3: Install CloudToLocalLLM

### Download

Get the latest release for your platform:

- [CloudToLocalLLM releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases)

### Windows

1. Download the Windows installer.
2. Run the installer.
3. Launch CloudToLocalLLM from the Start Menu.

If you only need a temporary or portable setup, download the Windows ZIP bundle instead and run `CloudToLocalLLM.exe` directly.

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

## Step 4: Complete The Setup Wizard

The setup wizard is the authority for the first working configuration.

### Agent Runtime Selection

Select the agent runtime this device should use:

- Hermes
- OpenClaw Gateway
- Custom compatible agent gateway
- Optional hosted agent runtime

### Runtime Location

Choose where that runtime lives:

- This computer
- Another device in your Tailscale tailnet
- A private server or VPS in your tailnet
- Optional CloudToLocalLLM-hosted agent runtime container

### Connection Test

The wizard checks:

- Runtime health
- Agent session support
- Tool/capability support
- Streaming support
- Voice and vision capabilities when exposed
- Network reachability through localhost, LAN, Tailscale, or custom URL

### Optional Support Model Provider

Choose whether app-owned background features may use:

- None
- Ollama
- LM Studio
- Custom local model endpoint

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
- Agent runtime presence and device availability
- Shared avatar preferences
- Web or mobile access through a connector

---

## Step 5: Configure Tailscale For Remote Devices

Tailscale is the preferred secure transport for remote agent runtime and multi-device usage.

1. Install Tailscale on each device that should participate.
2. Sign in to the same tailnet.
3. Confirm devices can reach each other:

```bash
tailscale status
tailscale ping <runtime-device-name>
```

4. In CloudToLocalLLM, choose the agent runtime device or enter its tailnet endpoint.

### Cloud Connector

For web/mobile access or cloud coordination, CloudToLocalLLM should add an isolated per-user connector container to the user's tailnet. That connector coordinates sync and reachability. It does not grant desktop permissions by itself.

### Hosted Agent Runtime

Running the agent runtime in CloudToLocalLLM-hosted infrastructure is an optional paid compute path. It should use a per-user isolated container and join the user's tailnet only after setup approval.

---

## Step 6: Verify The Setup

1. Open CloudToLocalLLM.
2. Confirm the main channel shows a connected agent runtime.
3. Send a short test message.
4. Open the avatar/voice companion sidecar.
5. If using desktop control, run a low-risk permission test such as screenshot or notification.
6. If using Tailscale, test from a second device.
7. If using a local model provider, run a memory/support-model health check from settings.

---

## Troubleshooting

### Agent Runtime Not Found

- Confirm the agent runtime is running.
- Check the endpoint and port.
- Use the wizard connection test.
- For remote runtimes, confirm Tailscale connectivity.
- Confirm you did not enter an Ollama/LM Studio endpoint as the agent runtime.

### Hermes Path Not Working

- Verify the Hermes service is running.
- Confirm the endpoint configured in the wizard.
- Check whether Hermes exposes the capabilities required by the selected feature.

### Local Model Provider Not Working

- Confirm the local model server is running.
- Check the support model provider settings.
- Test the model endpoint directly.
- Confirm the feature you are using is allowed to use local model support.

### Remote Device Not Reachable

```bash
tailscale status
tailscale ping <device-name-or-ip>
```

Confirm both devices are in the same tailnet and that the agent runtime is listening on the expected interface.

### Desktop Control Not Working

- Grant permissions on the device being controlled.
- Check that the action type is enabled.
- Review pending approvals.
- Confirm platform support for the requested action.
