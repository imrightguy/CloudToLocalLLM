# Windows Installation Guide

This guide covers installing CloudToLocalLLM on Windows 10 and Windows 11. Agent runtime selection happens in the setup wizard after installation. CloudToLocalLLM can connect to Hermes, OpenClaw, or a compatible custom agent gateway. Hermes is the first agent runtime path for current testing.

Ollama and LM Studio are optional support model providers for memory/background features, not primary app runtimes.

---

## Prerequisites

### System Requirements

- Windows 10 version 1903 or later, or Windows 11
- 4 GB RAM minimum, 8 GB+ recommended
- 2 GB app storage plus storage for local agent runtimes/models
- Internet access for downloads, account sync, and optional cloud features
- Visual C++ runtime, usually included by the installer

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

---

## Installation Methods

| Method | Best For | Notes |
| --- | --- | --- |
| Windows installer | Most users | Best system integration |
| Portable build | Testing and temporary use | No install required |
| Source build | Developers | Requires Flutter and Visual Studio tooling |

---

## Windows Installer

1. Open the [latest release](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest).
2. Download the Windows installer.
3. Run the installer.
4. Follow the installation wizard.
5. Launch CloudToLocalLLM from the Start Menu or desktop shortcut.

Typical installer options:

- Desktop shortcut
- Start Menu shortcut
- URL callback registration for desktop auth flows

### Updates

- Use the app update flow when available.
- Or install a newer release over the existing version.

### Uninstall

Use "Add or Remove Programs" in Windows Settings, or run the uninstaller from the Start Menu.

---

## Portable Build

1. Download the portable zip from the [latest release](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest).
2. Extract it to a folder such as `C:\Tools\CloudToLocalLLM`.
3. Run `CloudToLocalLLM.exe`.

Portable builds store app data beside the executable when packaged that way. Move the data folder with the app if you relocate it.

---

## Source Build

Install:

- Flutter SDK
- Visual Studio 2022 with C++ desktop development tools
- Git

Build:

```powershell
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM
flutter pub get
flutter config --enable-windows-desktop
flutter build windows --release
```

The built app is under:

```text
build\windows\runner\Release\
```

---

## First Launch

1. Start your selected agent runtime or confirm the remote runtime is reachable.
2. Launch CloudToLocalLLM.
3. Complete the setup wizard.
4. Select the agent runtime and endpoint.
5. Optionally configure a support model provider for memory/background features.
6. Grant desktop permissions for this Windows device only where needed.
7. Enable Tailscale-backed sync if using remote devices.

### Tailscale Check

```powershell
tailscale status
tailscale ping <runtime-device-name>
```

---

## Windows Integration

- System tray menu for quick actions and status.
- Native Windows notifications.
- Optional auto-start with Windows.
- Windows Defender firewall prompts for local services where needed.

Firewall rule example:

```powershell
New-NetFirewallRule -DisplayName "CloudToLocalLLM" -Direction Inbound -Program "C:\Program Files\CloudToLocalLLM\CloudToLocalLLM.exe" -Action Allow
```

Only allow inbound access when a feature actually needs it. Prefer Tailscale for remote access instead of opening broad network exposure.

---

## Web And Cloud Access

Web and mobile access should use the Tailscale-first cloud connector design. The connector is an isolated per-user container joined to the user's tailnet after approval. It coordinates reachability and sync, but it does not automatically grant desktop-control permissions.

---

## Troubleshooting

### Application Will Not Start

```powershell
eventvwr.msc
```

Check Windows Event Viewer for application errors. Confirm antivirus or controlled folder access is not blocking the executable.

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

```powershell
tailscale status
tailscale ping <runtime-device-name>
```

Confirm both devices are in the same tailnet and that Windows Defender Firewall allows the agent runtime process on the runtime device.

### System Tray Icon Missing

1. Open the hidden tray icons menu.
2. Check Windows taskbar notification settings.
3. Restart CloudToLocalLLM.

### Logs

```powershell
Get-Content "$env:LOCALAPPDATA\CloudToLocalLLM\logs\app.log" -Tail 50
Get-WinEvent -LogName Application | Where-Object {$_.ProviderName -eq "CloudToLocalLLM"}
```

---

## Related Documentation

- [Installation Overview](README.md)
- [Linux Installation](LINUX.md)
- [Setup Guide](../../user-guide/SETUP_GUIDE.md)
- [User Guide](../../user-guide/USER_GUIDE.md)
- [Troubleshooting](../../user-guide/TROUBLESHOOTING.md)
- [Agent Runtime Contract](../../architecture/AGENT_RUNTIME_CONTRACT.md)
- [Secure Device Mesh](../../architecture/SECURE_DEVICE_MESH.md)
