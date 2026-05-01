# Linux Installation Guide

This guide covers installing CloudToLocalLLM on Linux. Agent runtime selection happens in the setup wizard after installation. CloudToLocalLLM can connect to Hermes, OpenClaw, or a compatible custom agent gateway. Hermes is the first agent runtime path for current testing.

Ollama and LM Studio are optional support model providers for memory/background features, not primary app runtimes.

---

## Prerequisites

### System Requirements

- Ubuntu 20.04+, Debian 11+, Arch, Fedora, or another modern Linux desktop
- 4 GB RAM minimum, 8 GB+ recommended
- 2 GB app storage plus storage for local agent runtimes/models
- Internet access for downloads, account sync, and optional cloud features

### Agent Runtime

Prepare one agent runtime before or during first launch:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | Configured in wizard | First agent runtime path for current testing |
| OpenClaw Gateway | `http://localhost:18789` | Supported original integration |
| Custom agent gateway | User supplied | Private server, VPS, or compatible agent runtime API |
| Hosted agent runtime | CloudToLocalLLM managed | Optional paid compute |

For a runtime on another machine, install Tailscale on both devices and confirm they can reach each other.

### Optional Support Model Provider

| Provider | Typical Endpoint | Use |
| --- | --- | --- |
| LM Studio | `http://localhost:1234` | Local model support for app features |
| Ollama | `http://localhost:11434` | Local model support for memory/background features |

### System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y curl wget git
sudo apt-get install -y libgtk-3-0 libglib2.0-0 libnss3 libatk-bridge2.0-0
```

For source builds:

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

---

## Installation Methods

| Method | Best For | Notes |
| --- | --- | --- |
| DEB package | Ubuntu and Debian users | Best desktop integration |
| AppImage | Most distributions | Portable and self-contained |
| Source build | Developers | Requires Flutter and native build tooling |

---

## DEB Package

```bash
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm_amd64.deb
sudo dpkg -i cloudtolocalllm_amd64.deb
sudo apt-get install -f
```

Launch:

```bash
cloudtolocalllm
```

Update:

```bash
sudo apt-get update
sudo apt-get upgrade cloudtolocalllm
```

Uninstall:

```bash
sudo apt-get remove cloudtolocalllm
```

---

## AppImage

```bash
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-x86_64.AppImage
chmod +x CloudToLocalLLM-x86_64.AppImage
./CloudToLocalLLM-x86_64.AppImage
```

Optional desktop integration:

```bash
mkdir -p ~/.local/bin ~/.local/share/applications
mv CloudToLocalLLM-x86_64.AppImage ~/.local/bin/CloudToLocalLLM.AppImage
```

Create `~/.local/share/applications/CloudToLocalLLM.desktop`:

```ini
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Secure agent companion
Exec=/home/YOUR_USER/.local/bin/CloudToLocalLLM.AppImage
Terminal=false
Type=Application
Categories=Development;Network;
```

---

## Source Build

```bash
sudo snap install flutter --classic
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM
flutter pub get
flutter config --enable-linux-desktop
flutter build linux --release
```

Run the built app:

```bash
build/linux/x64/release/bundle/CloudToLocalLLM
```

---

## First Launch

1. Start your selected agent runtime or confirm the remote runtime is reachable.
2. Launch CloudToLocalLLM.
3. Complete the setup wizard.
4. Select the agent runtime and endpoint.
5. Optionally configure a support model provider for memory/background features.
6. Grant desktop permissions for this Linux device only where needed.
7. Enable Tailscale-backed sync if using remote devices.

### Tailscale Check

```bash
tailscale status
tailscale ping <runtime-device-name>
```

---

## Web And Cloud Access

Web and mobile access should use the Tailscale-first cloud connector design. The connector is an isolated per-user container joined to the user's tailnet after approval. It coordinates reachability and sync, but it does not automatically grant desktop-control permissions.

---

## Troubleshooting

### Application Will Not Start

```bash
ldd /opt/CloudToLocalLLM/CloudToLocalLLM
sudo apt-get install -y libgtk-3-0 libglib2.0-0
chmod +x /opt/CloudToLocalLLM/CloudToLocalLLM
```

### Agent Runtime Not Found

- Confirm the selected agent runtime is running.
- Check the endpoint configured in the wizard.
- Test the runtime health endpoint if it has one.
- For remote runtimes, confirm Tailscale connectivity.
- Confirm you did not enter an Ollama/LM Studio endpoint as the agent runtime.

### Support Model Provider Not Found

- Confirm Ollama, LM Studio, or the custom local model endpoint is running.
- Check support model provider settings.
- Test the model endpoint directly.

### Tailscale Remote Runtime Not Reachable

```bash
tailscale status
tailscale ping <runtime-device-name>
```

Confirm the agent runtime listens on the expected interface and that the device firewall allows tailnet access.

### System Tray Not Visible

```bash
sudo apt-get install -y gnome-shell-extension-appindicator
```

Log out and back in if your desktop environment needs to reload tray support.

### Logs

```bash
tail -f ~/.local/share/cloudtolocalllm/logs/app.log
journalctl --user -u cloudtolocalllm -f
```

---

## Related Documentation

- [Installation Overview](README.md)
- [Windows Installation](WINDOWS.md)
- [Setup Guide](../../user-guide/SETUP_GUIDE.md)
- [User Guide](../../user-guide/USER_GUIDE.md)
- [Troubleshooting](../../user-guide/TROUBLESHOOTING.md)
- [Agent Runtime Contract](../../architecture/AGENT_RUNTIME_CONTRACT.md)
- [Secure Device Mesh](../../architecture/SECURE_DEVICE_MESH.md)
