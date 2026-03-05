# Linux Auto-Updating Installer Design

**Date:** 2026-03-05
**Status:** Approved
**Author:** Claude (Sonnet 4.6)

## Goal

Create a seamless installation experience for CloudToLocalLLM on Linux with automatic background updates, similar to [OpenClaw.ai](https://openclaw.ai), using an intelligent hybrid update approach.

## Overview

The installer provides a one-line installation command that downloads the AppImage from GitHub releases and sets up an auto-update daemon. The update service runs in the background, checking for updates periodically and handling them according to semantic version rules.

**Quick Install Command:**
```bash
curl -fsSL https://cloudtolocalllm.online/install.sh | bash
```

## Architecture

### Components

1. **Installer Script** (`install.sh`) - Downloads and sets up the application
2. **Update Daemon** (`cloudtolocalllm-updated`) - Background service for update checks
3. **Auto-Update Service** (`auto_update_service.dart`) - Flutter service for in-app updates
4. **CI/CD Integration** - Generates installer during deployment pipeline

### Installation Paths

| Scope | Location | Systemd | Requirements |
|-------|----------|---------|--------------|
| User-local (default) | `~/.local/share/cloudtolocalllm/` | `~/.config/systemd/user/` | No sudo |
| System-wide (`--system`) | `/opt/cloudtolocalllm/` | `/etc/systemd/system/` | sudo required |

## Installer Script (`install.sh`)

### Features

- Detects latest version from GitHub Releases API
- Downloads AppImage to appropriate location
- Creates desktop entry and installs icon
- Sets up systemd service (user or system)
- Enables and starts update daemon
- Adds to PATH via shell profile
- Launches application after install

### Usage

```bash
# Basic install (user-local)
curl -fsSL https://cloudtolocalllm.online/install.sh | bash

# System-wide install
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --system

# Specific channel
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --channel beta

# Silent install (no prompts)
curl -fsSL https://cloudtolocalllm.online/install.sh | bash -s -- --silent
```

### Options

| Flag | Description |
|------|-------------|
| `--system` | Install to `/opt` instead of `~/.local` |
| `--channel <stable|beta|edge>` | Update channel to subscribe to |
| `--no-daemon` | Skip update daemon installation |
| `--silent` | Suppress all output except errors |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `CLOUDTOLOCALLLM_DIR` | Override installation directory |
| `CLOUDTOLOCALLLM_CHANNEL` | Default update channel |

## Update Daemon (`cloudtolocalllm-updated`)

### Purpose

Lightweight background service that checks for updates and handles downloads independently of the main application.

### Implementation

**Language:** Shell script (for AppImage portability)
**Interface:** Systemd service + timer
**Check Interval:** Every 6 hours (configurable via `update_check_interval_hours` in state file)

### Update Logic (Hybrid Approach)

```bash
# Semantic version parsing
CURRENT="10.1.200"  # major.minor.patch
LATEST="10.2.0"

# Decision tree
if [ $LATEST_MAJOR -gt $CURRENT_MAJOR ]; then
    # MAJOR update - prompt user, show changelog
    prompt_user "Major update $LATEST available"
elif [ $LATEST_MINOR -gt $CURRENT_MINOR ]; then
    # MINOR update - prompt user (may have breaking changes)
    prompt_user "Minor update $LATEST available"
else
    # PATCH update - auto-install silently
    auto_install_update
fi
```

### State File

**Location:** `~/.config/cloudtolocalllm/update-state.json`

```json
{
  "current_version": "10.1.200",
  "last_check": "2026-03-05T12:00:00Z",
  "last_update": "2026-03-04T08:00:00Z",
  "update_channel": "stable",
  "auto_install_minor": false,
  "auto_install_patch": true,
  "update_check_interval_hours": 6,
  "pending_update": null
}
```

### Communication

- **Unix Socket:** `/tmp/cloudtolocalllm-updated.sock`
- **Signals:** `UpdateAvailable`, `UpdateDownloaded`, `UpdateInstalled`
- **Commands:** `check`, `download`, `install`, `status`

## In-App Update Integration

### Auto-Update Service (`lib/services/auto_update_service.dart`)

**Purpose:** Flutter service for manual updates and UI integration.

**Features:**
- "Check for Updates" button in Settings
- Desktop notifications when updates available
- Changelog display before major updates
- Download/install progress tracking
- "Restart to Update" prompt
- Manual update channel selection
- Update history view

**Communication with Daemon:**
- Unix socket IPC for bidirectional communication
- Stream-based updates for progress
- JSON protocol for messages

### UI Components

| Screen | Component | Purpose |
|--------|-----------|---------|
| Settings | Update status card | Show current version, last check |
| Settings | Check for Updates button | Manual update trigger |
| Dialog | Update available | Show changelog, prompt for major updates |
| Dialog | Download progress | Progress bar during download |
| Notification | Update downloaded | Notify user update ready to install |
| Notification | Update installed | Notify user to restart |

## CI/CD Integration

### Changes to `.github/workflows/deployment.yml`

**After AppImage build, add:**

```yaml
- name: Generate Installer Script
  run: |
    VERSION=${{ needs.ai_change_analysis.outputs.new_version }}

    # Generate install.sh with version baked in
    cat > dist/linux/install.sh << 'INSTALLER_EOF'
    #!/bin/bash
    INSTALL_VERSION="${VERSION}"
    INSTALL_BASE_URL="https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/download"

    # ... rest of installer script ...
    INSTALLER_EOF

    chmod +x dist/linux/install.sh

- name: Upload Installer Script to Release
  uses: ncipollo/release-action@v1
  with:
    artifacts: "dist/linux/*"
    body: |
      ## Quick Install
      ```bash
      curl -fsSL https://cloudtolocalllm.online/install.sh | bash
      ```
```

### Build Artifacts

Each release will include:
- `CloudToLocalLLM-x86_64.AppImage` - Main application
- `install.sh` - Installer script
- `CloudToLocalLLM-x86_64.tar.gz` - Portable bundle
- `cloudtolocalllm_${VERSION}_amd64.deb` - Debian package
- `cloudtolocalllm.sha256` - Checksums

## File Structure

```
cloudtolocalllm/
├── scripts/
│   └── packaging/
│       ├── installer-template.sh       # Template for install.sh
│       ├── build_installer.sh          # Generates install.sh
│       └── update-daemon/              # Update daemon files
│           ├── cloudtolocalllm-updated # Daemon script
│           └── cloudtolocalllm-updated.service # Systemd unit
├── lib/services/
│   └── auto_update_service.dart        # NEW: In-app update service
├── linux/
│   └── cloudtolocalllm-updated         # Daemon binary (bundled)
├── test/services/
│   └── auto_update_service_test.dart   # NEW: Tests
└── build/linux/x64/release/bundle/
    └── cloudtolocalllm-updated         # Daemon bundled with app
```

## User Experience Flows

### First-Time Install

```bash
$ curl -fsSL https://cloudtolocalllm.online/install.sh | bash

🦞 Installing CloudToLocalLLM v10.1.200...
✓ Downloaded AppImage to ~/.local/share/cloudtolocalllm/
✓ Created desktop entry
✓ Installed icon to ~/.local/share/icons/
✓ Set up update daemon
✓ Started background update service

🎉 CloudToLocalLLM installed successfully!
Run 'cloudtolocalllm' or find it in your application menu.

💡 The update daemon will check for updates every 6 hours.
```

### Update Flow: Patch Version (Auto-Install)

**Timeline:** Background check at 2am

```
1. Daemon wakes up (systemd timer)
2. Queries GitHub Releases API
3. Compares v10.1.200 → v10.1.201
4. Determines: PATCH version → AUTO-INSTALL
5. Downloads AppImage to ~/.cache/cloudtolocalllm/
6. Prepares replacement for next app quit
7. [User quits app]
8. Daemon replaces AppImage
9. Shows notification: "Updated to v10.1.201"
10. Next launch uses new version
```

### Update Flow: Major Version (Prompt User)

**Timeline:** Background check at 2am

```
1. Daemon wakes up
2. Queries GitHub Releases API
3. Compares v10.1.200 → v11.0.0
4. Determines: MAJOR version → PROMPT USER
5. Shows persistent notification: "CloudToLocalLLM 11.0.0 available!"
6. Downloads changelog in background
7. [User clicks notification OR opens app]
8. App shows dialog:
   ┌─────────────────────────────────────┐
   │  Update Available: v11.0.0          │
   │                                     │
   │  Major release with new features:   │
   │  • New avatar evolution system      │
   │  • Improved vision capabilities     │
   │  • Performance improvements         │
   │                                     │
   │  [View Full Changelog]              │
   │                                     │
   │  [Remind Me Later] [Update Now]     │
   └─────────────────────────────────────┘
9. User clicks "Update Now"
10. Download progress shown
11. App restarts with new version
```

## Security Considerations

1. **Signature Verification:**
   - AppImage should be signed (future enhancement)
   - Verify checksum before install
   - Checksums published on GitHub releases

2. **Update Source:**
   - Only download from official GitHub releases
   - HTTPS-only connections
   - Verify repository URL

3. **Daemon Privileges:**
   - User service runs as user (no root)
   - System service requires explicit `--system` flag
   - No privilege escalation

4. **Update State:**
   - State file permissions: `0600` (user-only)
   - Socket permissions: `0600`
   - Validate state file format

## Dependencies

### Runtime Dependencies

- `curl` - For downloading installer and updates
- `jq` - For JSON parsing in daemon script
- `systemd` - For service management (Linux standard)
- `libnotify` - For desktop notifications

### Build Dependencies

- None for installer script generation
- Existing Flutter build pipeline

## Testing Strategy

1. **Installer Script Tests:**
   - Test user-local installation
   - Test system-wide installation
   - Test with different flags
   - Test on Ubuntu, Debian, Fedora, Arch

2. **Update Daemon Tests:**
   - Mock GitHub API responses
   - Test version comparison logic
   - Test download failure handling
   - Test state file corruption recovery

3. **Integration Tests:**
   - Full install → update → restart cycle
   - Test daemon ↔ app communication
   - Test concurrent updates

## Future Enhancements

1. **Delta Updates:** Download only changed files for faster updates
2. **Rollback:** Keep previous version for easy rollback
3. **Multiple Channels:** Stable, Beta, Edge channels
4. **Stats Tracking:** Anonymous update success/failure metrics
5. **Signature Verification:** GPG signatures for AppImages

## References

- [OpenClaw Installation](https://openclaw.ai)
- [AppImage Specification](https://github.com/AppImage/AppImageSpec)
- [Systemd Service Management](https://www.freedesktop.org/software/systemd/man/)
- [GitHub Releases API](https://docs.github.com/en/rest/releases)
