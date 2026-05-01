# CloudToLocalLLM Troubleshooting Guide

This guide helps diagnose setup, agent runtime, support model, mesh, desktop-control, voice, and sync problems.

CloudToLocalLLM does not require one default runtime. Confirm which agent runtime the setup wizard selected before troubleshooting. Ollama and LM Studio are support model providers, not primary agent runtime targets.

---

## Agent Runtime Connection Problems

### Agent Runtime Not Detected

**Symptoms**: Empty session list, timeout errors, disconnected status, disabled chat input, or unavailable desktop/vision tools.

**Checks**:

1. Confirm the selected agent runtime is running.
2. Confirm the endpoint in setup or settings.
3. Test the endpoint directly when possible.

```bash
# OpenClaw Gateway
curl http://localhost:18789/health
```

For Hermes and custom agent gateways, use the health route exposed by that runtime and the setup wizard connection test.

Do not enter raw Ollama or LM Studio endpoints as the agent runtime. They do not manage agents, tools, sessions, or desktop action requests by themselves.

### Wrong Runtime Selected

1. Open agent runtime settings.
2. Review the active agent runtime and endpoint.
3. Re-run the setup wizard connection test.
4. Switch to Hermes, OpenClaw, or a compatible custom agent gateway as needed.

### Remote Agent Runtime Not Connecting

Prefer Tailscale for remote agent runtime paths.

```bash
tailscale status
tailscale ping <runtime-device-name>
```

Confirm:

- Both devices are in the expected tailnet.
- The agent runtime is listening on the expected interface.
- The runtime device firewall allows access from the tailnet.
- The endpoint uses the tailnet hostname or IP, not an unreachable LAN-only address.

---

## Support Model Provider Problems

### Local Model Provider Not Detected

Support model providers are optional. They can help memory and background features, but they do not affect whether the main agent channel can connect.

```bash
# LM Studio
curl http://localhost:1234/v1/models

# Ollama
curl http://localhost:11434/api/tags
```

If the support model provider works but chat is disconnected, troubleshoot the agent runtime instead.

### Memory Or Summaries Not Using Local Model

- Confirm the provider is configured under local model/support settings.
- Confirm the feature is allowed to use local model support.
- Confirm the model needed for embeddings or summaries is available.
- Check app logs for feature-level errors.

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
- The request came through the selected agent runtime and capability broker, not a raw local model provider.

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

- Confirm the active agent runtime exposes a vision-capable tool or accepts vision context.
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

- Confirm the selected agent runtime or fallback service supports text-to-speech.
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

- Check agent runtime health and latency.
- Use a smaller or faster model inside the agent runtime if it exposes model choice.
- Reduce conversation context length.
- Move the agent runtime to a stronger local device or optional hosted agent runtime.
- Confirm Tailscale latency for remote runtimes.
- If only memory/summaries are slow, check the configured local model provider.

### High CPU Or RAM

- Reduce model size in the agent runtime or support model provider.
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
- [Agent Runtime Contract](../architecture/AGENT_RUNTIME_CONTRACT.md)
- [Secure Device Mesh](../architecture/SECURE_DEVICE_MESH.md)
- [GitHub Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
