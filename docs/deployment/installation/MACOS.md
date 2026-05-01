# macOS Installation Guide

macOS support is planned but not the primary packaged desktop target yet. This guide covers the current development build path and the intended setup direction.

Runtime selection belongs to the setup wizard. CloudToLocalLLM can connect to Hermes, OpenClaw, LM Studio, Ollama, or a compatible custom endpoint. Hermes is the first runtime path for current testing.

---

## Current Status

The macOS app is expected to support:

- Native app bundle packaging
- Menu bar integration
- Notifications
- Keychain storage for secrets
- Tailscale-backed remote runtime access
- Desktop, screen, and accessibility permissions where macOS allows them

Packaged macOS distribution details are still pending. Avoid documenting dated release windows until the release process is active.

---

## Development Build

### Prerequisites

- macOS 12 or later recommended
- Xcode from the App Store
- Xcode Command Line Tools
- Flutter SDK
- CocoaPods
- Git

Install common prerequisites:

```bash
xcode-select --install
sudo gem install cocoapods
flutter config --enable-macos-desktop
```

### Build From Source

```bash
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM
flutter pub get
flutter build macos --release
```

The built app is under:

```text
build/macos/Build/Products/Release/
```

---

## Runtime Prerequisites

Prepare one runtime before or during first launch:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | Configured in wizard | First runtime path for current testing |
| OpenClaw Gateway | `http://localhost:18789` | Supported original integration |
| LM Studio | `http://localhost:1234` | OpenAI-compatible local runtime |
| Ollama | `http://localhost:11434` | Optional local model runtime |
| Custom endpoint | User supplied | Private server, VPS, or compatible API |

For a runtime on another machine, install Tailscale on both devices and confirm they can reach each other:

```bash
tailscale status
tailscale ping <runtime-device-name>
```

---

## First Launch

1. Start your selected runtime or confirm the remote runtime is reachable.
2. Launch the macOS development build.
3. Complete the setup wizard.
4. Select the runtime and endpoint.
5. Grant macOS permissions only for features you need.
6. Enable Tailscale-backed sync if using remote devices.

### macOS Permissions

Desktop-control features may require:

- Accessibility
- Screen Recording
- Microphone for voice input
- Camera for vision input
- Files and folders access for explicit file operations

These permissions are granted on the local Mac only. Syncing an account does not automatically grant control over other devices.

---

## Planned Installation Methods

### App Bundle

1. Download a signed `.dmg` or `.zip` release when available.
2. Move CloudToLocalLLM to Applications.
3. Launch from Applications or Spotlight.
4. Complete the setup wizard.

### Homebrew

Homebrew distribution is planned after packaging is stable.

```bash
brew tap CloudToLocalLLM-online/CloudToLocalLLM
brew install cloudtolocalllm
```

---

## Web And Cloud Access

Web and mobile access should use the Tailscale-first cloud connector design. The connector is an isolated per-user container joined to the user's tailnet after approval. It coordinates reachability and sync, but it does not automatically grant desktop-control permissions.

---

## Troubleshooting

### Runtime Not Found

- Confirm the selected runtime is running.
- Check the endpoint configured in the wizard.
- Test the runtime health endpoint if it has one.
- For remote runtimes, confirm Tailscale connectivity.

### Desktop Control Not Working

- Open System Settings.
- Review Privacy & Security permissions.
- Confirm Accessibility and Screen Recording are granted to CloudToLocalLLM.
- Restart the app after permission changes.

### Build Fails

```bash
flutter doctor
pod repo update
flutter clean
flutter pub get
```

Then rebuild.

---

## Related Documentation

- [Installation Overview](README.md)
- [Linux Installation](LINUX.md)
- [Windows Installation](WINDOWS.md)
- [Setup Guide](../../user-guide/SETUP_GUIDE.md)
- [User Guide](../../user-guide/USER_GUIDE.md)
- [Secure Device Mesh](../../architecture/SECURE_DEVICE_MESH.md)
