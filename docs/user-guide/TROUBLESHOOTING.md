# CloudToLocalLLM Troubleshooting Guide

This guide helps you resolve common issues with CloudToLocalLLM.

---

## Connection Problems

### OpenClaw Gateway Not Detected

**Symptoms**: "No OpenClaw connection" message, empty model list, or timeout errors.

**Solutions**:

1. **Check if OpenClaw is running**:
   - **Linux**: `ps aux | grep openclaw` or check `localhost:18789`
   - **Windows**: Check for OpenClaw in Task Manager or system tray
   - **Command**: `curl http://localhost:18789/health` should return status

2. **Verify Port**: OpenClaw defaults to port `18789`. Ensure no other service is using this port:
   ```bash
   # Linux
   lsof -i :18789

   # Windows
   netstat -ano | findstr :18789
   ```

3. **Manual Configuration**: If OpenClaw runs on a different port/IP:
   - Go to **Settings > LLM Provider Settings**
   - Enter your custom URL (e.g., `http://192.168.1.100:18789`)

4. **Restart Gateway**: Stop and restart OpenClaw Gateway

### Remote Gateway (Tailscale/VPS) Not Connecting

**Symptoms**: Cannot connect to remote OpenClaw Gateway.

**Solutions**:

1. **Tailscale Connection**:
   - Verify Tailscale is running: `tailscale status`
   - Check you're on the same tailnet
   - Ping the remote machine: `ping <tailscale-ip>`

2. **SSH Tunnel**:
   - Verify SSH key is configured
   - Check tunnel is established
   - Test connection: `curl http://localhost:18789/health`

3. **Firewall**: Ensure port 18789 is open on the remote machine

---

## Desktop App Issues

### Application Won't Start

**Solutions**:

1. **Dependencies**:
   - **Linux**: Check for missing libraries with `ldd`
   - Run with verbose flag: `./cloudtolocalllm --verbose`

2. **Corrupted Config**: Clear local config:
   ```bash
   # Linux
   rm -rf ~/.config/CloudToLocalLLM/

   # Windows
   rmdir /s "%APPDATA%\CloudToLocalLLM"
   ```

### System Tray Not Visible (Linux)

**Solutions**:

1. **Install Support Packages**:
   ```bash
   sudo apt install libayatana-appindicator3-1
   ```

2. **GNOME Extension**: Install "AppIndicator and KStatusNotifierItem Support"

3. **Restart App**: Quit and relaunch to see error logs

---

## Authentication Issues (Cloud Features)

### Login Loops or Failures

**Cloud features are optional** — local mode works without authentication.

**If using cloud features**:

1. **Check Auth0 Status**: [status.auth0.com](https://status.auth0.com)

2. **System Time**: Ensure your clock is accurate (JWT tokens fail with time skew)

3. **Clear Browser Data** (web version only): Clear cookies for the app domain

4. **Keyring/Keychain**: Ensure OS credential storage is unlocked

---

## Performance & Resources

### High CPU/RAM Usage

**Solutions**:

1. **Model Size**: Use smaller models (Qwen 7B instead of 70B)

2. **GPU Acceleration**: Ensure NVIDIA drivers are installed and working:
   ```bash
   nvidia-smi
   ```

3. **Context Length**: Reduce conversation context length for faster responses

4. **Vision Features**: OCR and continuous monitoring are CPU-intensive

### Slow Responses

**Solutions**:

1. **Check Gateway Health**: High latency = slow responses

2. **Model Performance**: Some models are faster than others

3. **System Resources**: Check CPU/RAM usage

---

## Desktop Control Issues

### Automation Not Working

**Solutions**:

1. **Permissions**: Ensure the app has necessary permissions

2. **Platform**: Desktop control works on Linux and Windows only (not web)

3. **Wayland (Linux)**: Some features may require X11

4. **Screenshot Failed**: Check temp directory permissions

### Vision Analysis Fails

**Solutions**:

1. **OpenClaw Vision Model**: Verify vision model is loaded in Gateway

2. **Image Format**: Ensure screenshots are in PNG format

3. **OCR Failed**: Install Tesseract:
   ```bash
   sudo apt install tesseract-ocr
   ```

---

## Setup Wizard Issues

### Wizard Won't Proceed

**Symptoms**: Stuck on a step, can't continue.

**Solutions**:

1. **Skip for Returning Users**: If you've configured before, click "Skip Setup"

2. **Force Re-run**: Clear first-run flag in config

3. **Manual Config**: Go to Settings > LLM Provider Settings to configure manually

---

## Platform-Specific Issues

### Linux

**Wayland**: Some features (screenshots, automation) work better on X11

**Dependencies**: Install missing packages:
```bash
sudo apt install libayatana-appindicator3-1 tesseract-ocr
```

### Windows

**Defender**: Add exception for CloudToLocalLLM if needed

**Firewall**: Allow CloudToLocalLLM through Windows Firewall

### Web

**Limitations**: Desktop control and automation not available

**Browser**: Use Chrome or Edge for best experience

---

## Data & Storage

### Lost Conversations

**Local Storage**: Conversations stored in:
- **Linux**: `~/.local/share/cloudtolocalllm/local_brain.db`
- **Windows**: `%LOCALAPPDATA%\cloudtolocalllm\local_brain.db`

**Backup**: Copy this file regularly

### Reset to Defaults

**Warning**: This deletes all data!

```bash
# Linux
rm -rf ~/.config/CloudToLocalLLM/ ~/.local/share/cloudtolocalllm/

# Windows
rmdir /s "%APPDATA%\CloudToLocalLLM" %LOCALAPPDATA%\CloudToLocalLLM"
```

---

## Logs & Debugging

### Finding Logs

**Linux**: `~/.local/share/cloudtolocalllm/logs/app.log`

**Windows**: `%LOCALAPPDATA%\cloudtolocalllm\logs\app.log`

### Enable Debug Mode

Run with verbose flag:
```bash
./cloudtolocalllm --verbose
```

---

## Getting More Help

If your issue isn't listed here:

1. **Documentation**:
   - [USER_GUIDE.md](USER_GUIDE.md)
   - [SETUP_GUIDE.md](SETUP_GUIDE.md)
   - [FEATURES_GUIDE.md](FEATURES_GUIDE.md)

2. **Architecture**: [SYSTEM_ARCHITECTURE.md](../architecture/SYSTEM_ARCHITECTURE.md)

3. **GitHub Issues**: [Report a bug](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)

4. **Check Existing Issues**: Search before creating new issues
