# CloudToLocalLLM Troubleshooting Guide

This guide helps you resolve common issues with CloudToLocalLLM.

## 🚨 Connection Problems

### Ollama Not Detected
**Symptoms**: "No local Ollama connection" message, empty model list, or timeout errors.

**Solutions**:
1.  **Check if Ollama is running**:
    *   **Linux**: `systemctl --user status ollama`
    *   **Windows**: Check for the Ollama icon in the system tray.
2.  **Verify Port**: Ollama defaults to port `11434`. Ensure no other service is using this port.
3.  **Manual Configuration**: If you run Ollama on a custom IP or port, go to **Settings > Connection Settings** in CloudToLocalLLM and update the URL.
4.  **CORS Issues**: Ensure Ollama allows connections from the application. (Usually handled automatically by the native app).

### Cloud Relay / Tunnel Connection Failed
**Symptoms**: "Cloud proxy unavailable" or "Disconnected" status when trying to access your local LLM via the web.

**Solutions**:
1.  **Check Internet**: Ensure you have a stable outbound connection to `*.cloudtolocalllm.online`.
2.  **Auth Status**: Ensure you are logged in. Tokens expire periodically; try logging out and back in.
3.  **Firewall**: Ensure your firewall allows outbound HTTPS (443) and WebSocket connections.
4.  **System Time**: Ensure your system clock is accurate. Out-of-sync clocks can cause authentication (JWT) failures.

---

## 🖥️ Desktop App Issues

### System Tray Not Visible (Linux)
**Solutions**:
1.  **Install Support Packages**:
    *   **Ubuntu/Debian**: `sudo apt install libayatana-appindicator3-1`
    *   **GNOME Users**: Install the `AppIndicator and KStatusNotifierItem Support` extension.
2.  **Restart App**: Quit the app completely and relaunch it from the terminal to see any error logs.

### Application Won't Start
**Solutions**:
1.  **Dependencies**: (Linux) Run `ldd` on the executable to check for missing shared libraries.
2.  **Corrupted Config**: If the app hangs, try clearing the local config directory:
    *   **Linux**: `~/.config/cloudtolocalllm/`
    *   **Windows**: `%APPDATA%\cloudtolocalllm\`

---

## 🔐 Authentication Issues

### Login Loops or Failures
**Solutions**:
1.  **Clear Browser Data**: If using the web version, clear cookies and localStorage for `cloudtolocalllm.online`.
2.  **Check Auth0 Status**: Occasionally the identity provider may have outages. Check [status.auth0.com](https://status.auth0.com).
3.  **Secure Storage (Desktop)**: If the desktop app fails to remember your session, ensure your OS keyring/keychain is unlocked.

---

## 🔧 Performance & Resources

### High CPU/RAM Usage
**Solutions**:
1.  **Model Size**: Large models (e.g., 70B parameters) require significant RAM and GPU VRAM. Use smaller models like `llama3.2:3b` if you experience lag.
2.  **Hardware Acceleration**: Ensure Ollama is utilizing your GPU. Check `nvidia-smi` or your system monitor during generation.
3.  **Background Activity**: The Cloud Relay uses minimal resources when idle, but active streaming will consume some CPU for encryption.

---

## 🆘 Getting More Help

If your issue isn't listed here:
1.  **Check Logs**:
    *   **Linux**: `~/.local/share/cloudtolocalllm/logs/app.log`
    *   **Windows**: `%LOCALAPPDATA%\cloudtolocalllm\logs\app.log`
2.  **GitHub Issues**: [Report a bug](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
3.  **Community**: Join our Discord or GitHub Discussions.
