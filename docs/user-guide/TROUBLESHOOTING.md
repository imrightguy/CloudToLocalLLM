# CloudToLocalLLM Troubleshooting Guide

This guide helps diagnose setup, runtime, mesh, desktop-control, voice, and sync problems.

CloudToLocalLLM does not require one default runtime. Confirm which runtime the setup wizard selected before troubleshooting.

---

## Runtime Connection Problems

### Runtime Not Detected

**Symptoms**: Empty model list, timeout errors, disconnected status, or disabled chat input.

**Checks**:

1. Confirm the selected runtime is running.
2. Confirm the endpoint in setup or settings.
3. Test the endpoint directly when possible.

```bash
# OpenClaw Gateway
curl http://localhost:18789/health

# LM Studio
curl http://localhost:1234/v1/models

# Ollama
curl http://localhost:11434/api/tags
```

For Hermes and custom endpoints, use the health or model route exposed by that runtime and the setup wizard connection test.

### Wrong Runtime Selected

1. Open runtime settings.
2. Review the active runtime and endpoint.
3. Re-run the setup wizard connection test.
4. Switch to Hermes, OpenClaw, LM Studio, Ollama, or a custom endpoint as needed.

### Remote Runtime Not Connecting

Prefer Tailscale for remote runtime paths.

```bash
tailscale status
tailscale ping <runtime-device-name>
```

Confirm:

- Both devices are in the expected tailnet.
- The runtime is listening on the expected interface.
- The runtime device firewall allows access from the tailnet.
- The endpoint uses the tailnet hostname or IP, not an unreachable LAN-only address.

---

## Secure Device Mesh

### Device Does Not Appear

- Confirm CloudToLocalLLM is installed and signed in where sync is expected.
- Confirm Tailscale is running on the device.
- Check account sync settings.
- Re-open the app after network changes.

### Cloud Connector Not Working

- Confirm the connector was approved in setup.
- Confirm it joined the user's tailnet.
- Check that the connector belongs to the expected user container.
- Verify that it is coordinating sync and reachability only; it should not grant desktop permissions by itself.

### Sync Works But Desktop Control Does Not

That is expected unless the target device granted desktop permissions. Conversation and presence sync are global account features; desktop, vision, clipboard, file, and command permissions are device-scoped.

---

## Desktop App Issues

### Application Will Not Start

Linux:

```bash
ldd /opt/CloudToLocalLLM/CloudToLocalLLM
./cloudtolocalllm --verbose
```

Windows:

```powershell
eventvwr.msc
```

Also check antivirus, controlled folder access, and missing desktop dependencies.

### System Tray Not Visible On Linux

```bash
sudo apt install libayatana-appindicator3-1
```

For GNOME, install the "AppIndicator and KStatusNotifierItem Support" extension, then restart the desktop session.

---

## Desktop Control Issues

### Automation Not Working

Check:

- The current device granted the required permission.
- The requested action type is enabled.
- The action is approved if approval is required.
- The platform supports the action.
- Linux Wayland restrictions are not blocking capture or input injection.

### Screenshot Or Region Capture Failed

- Confirm screen-capture permission.
- On Linux, try an X11 session if Wayland blocks the feature.
- Check temp directory and app data permissions.
- Confirm no privacy overlay or OS security setting is blocking capture.

### Command Execution Disabled

Command execution should be explicit and device-scoped. Enable it only for devices where shell access is intended.

---

## Vision Issues

### Vision Analysis Fails

- Confirm the active runtime exposes a vision-capable model or tool.
- Confirm screenshot capture works first.
- Use PNG screenshots when manually testing.
- Install OCR dependencies if local OCR is enabled:

```bash
sudo apt install tesseract-ocr
```

### Camera Input Fails

- Confirm camera permission on the device.
- Check whether another app is using the camera.
- Confirm the platform implementation supports camera capture.

---

## Voice Companion Issues

### Companion Window Will Not Open

- Open it from the tray or companion settings.
- Restart the app if the pop-out state is stuck.
- Check logs for window manager or popout service errors.

### Speech Output Not Working

- Confirm the selected runtime or fallback service supports text-to-speech.
- Check audio output device settings.
- Test with a short message.

### Microphone Input Not Working

- Confirm microphone permission.
- Check OS input device settings.
- Confirm voice input is enabled in companion settings.
- Check whether the current build includes the planned microphone/VAD path.

---

## Authentication And Cloud Features

Cloud features are optional. Local runtime use should remain possible without authentication where the selected features do not need sync.

### Login Loops Or Failures

- Check system time and timezone.
- Clear browser cookies for the app domain on web.
- Confirm OS credential storage is available on desktop.
- Check Auth0 status if account-backed features are down.

---

## Performance

### Slow Responses

- Check runtime health and latency.
- Use a smaller or faster model.
- Reduce conversation context length.
- Move the runtime to a stronger local device or optional hosted runtime.
- Confirm Tailscale latency for remote runtimes.

### High CPU Or RAM

- Reduce model size.
- Disable continuous vision monitoring.
- Avoid heavy OCR loops.
- Check GPU driver status for local model acceleration:

```bash
nvidia-smi
```

---

## Data And Storage

### Conversation Storage

- Linux: `~/.local/share/cloudtolocalllm/local_brain.db`
- Windows: `%LOCALAPPDATA%\cloudtolocalllm\local_brain.db`

### Logs

- Linux: `~/.local/share/cloudtolocalllm/logs/app.log`
- Windows: `%LOCALAPPDATA%\cloudtolocalllm\logs\app.log`

### Reset Configuration

This removes local app configuration and local app data.

Linux:

```bash
rm -rf ~/.config/CloudToLocalLLM/ ~/.local/share/cloudtolocalllm/
```

Windows:

```cmd
rmdir /s "%APPDATA%\CloudToLocalLLM"
rmdir /s "%LOCALAPPDATA%\CloudToLocalLLM"
```

---

## More Help

- [User Guide](USER_GUIDE.md)
- [Setup Guide](SETUP_GUIDE.md)
- [Features Guide](FEATURES_GUIDE.md)
- [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Secure Device Mesh](../architecture/SECURE_DEVICE_MESH.md)
- [GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
