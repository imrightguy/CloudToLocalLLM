# Linux Installation Guide

This guide covers installing CloudToLocalLLM on Linux. Runtime selection happens in the setup wizard after installation. CloudToLocalLLM can connect to Hermes, OpenClaw, LM Studio, Ollama, or a compatible custom endpoint. Hermes is the first runtime path for current testing.

---

## Prerequisites

### System Requirements

- Ubuntu 20.04+, Debian 11+, Arch, Fedora, or another modern Linux desktop
- 4 GB RAM minimum, 8 GB+ recommended
- 2 GB app storage plus local model storage if running a runtime on this device
- Internet access for downloads, account sync, and optional cloud features

### Runtime

Prepare one runtime before or during first launch:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | Configured in wizard | First runtime path for current testing |
| OpenClaw Gateway | `http://localhost:18789` | Supported original integration |
| LM Studio | `http://localhost:1234` | OpenAI-compatible local runtime |
| Ollama | `http://localhost:11434` | Optional local model runtime |
| Custom endpoint | User supplied | Private server, VPS, or compatible API |

For a runtime on another machine, install Tailscale on both devices and confirm they can reach each other.

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

1. Start your selected runtime or confirm the remote runtime is reachable.
2. Launch CloudToLocalLLM.
3. Complete the setup wizard.
4. Select the runtime and endpoint.
5. Grant desktop permissions for this Linux device only where needed.
6. Enable Tailscale-backed sync if using remote devices.

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

### Runtime Not Found

- Confirm the selected runtime is running.
- Check the endpoint configured in the wizard.
- Test the runtime health endpoint if it has one.
- For remote runtimes, confirm Tailscale connectivity.

### Tailscale Remote Runtime Not Reachable

```bash
tailscale status
tailscale ping <runtime-device-name>
```

Confirm the runtime listens on the expected interface and that the device firewall allows tailnet access.

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
