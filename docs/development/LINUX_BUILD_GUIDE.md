# Linux Build Guide

This guide explains the Linux build system for CloudToLocalLLM, which creates both Flatpak and .deb packages.

## Overview

Linux builds are **ENABLED** and fully integrated into the CI/CD pipeline. The build system uses:

- **GitHub-hosted runners** (ubuntu-latest) - FREE for public repositories
- **Dual packaging**: Flatpak (universal) and .deb (Debian/Ubuntu)
- **Automated dependency installation** for reproducible builds
- **Parallel execution** with Windows and Android builds

## Build Artifacts

Linux builds produce two package formats:

1. **Flatpak** (`CloudToLocalLLM-{version}.flatpak`)
   - Universal package for all Linux distributions
   - Sandboxed environment with controlled permissions
   - Works on Ubuntu, Fedora, Arch, Debian, openSUSE, etc.

2. **.deb Package** (`cloudtolocalllm_{version}_amd64.deb`)
   - Native package for Debian/Ubuntu-based systems
   - Integrates with system package manager
   - Appears in application menu automatically

## Build Configuration

The Linux build is configured in `.github/workflows/build-release.yml` with the following matrix entry:

```yaml
- platform: linux
  os: ubuntu-latest
  build-command: flutter build linux --release
  artifact-name: linux-packages
```

### Build Steps

The Linux build process includes the following automated steps:

1. **Install Dependencies** - Installs Flutter SDK, Flatpak tools, .deb packaging tools
2. **Configure Flutter** - Enables Linux desktop support
3. **Build Application** - Compiles Flutter app for Linux
4. **Create Flatpak** - Builds universal Flatpak package using manifest
5. **Create .deb Package** - Builds Debian/Ubuntu package with proper structure
6. **Generate Checksums** - Creates SHA256 checksums for both packages
7. **Upload Artifacts** - Uploads packages to GitHub release

All steps are fully automated and require no manual intervention.

## Testing Linux Builds Locally

Before enabling in CI/CD, test the build locally:

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev \
  flatpak flatpak-builder

# Fedora
sudo dnf install -y \
  clang cmake ninja-build pkg-config \
  gtk3-devel xz-devel \
  flatpak flatpak-builder

# Arch Linux
sudo pacman -S \
  clang cmake ninja pkg-config \
  gtk3 xz \
  flatpak flatpak-builder
```

### 2. Configure Flutter

```bash
flutter config --enable-linux-desktop
flutter config --no-enable-web
```

### 3. Build Linux Application

```bash
flutter build linux --release
```

### 4. Test the Build

```bash
./build/linux/x64/release/bundle/CloudToLocalLLM
```

### 5. Build Flatpak (Optional)

```bash
# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Freedesktop SDK
flatpak install -y flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08

# Build Flatpak
flatpak-builder --force-clean --repo=repo build-dir com.CloudToLocalLLM.CloudToLocalLLM.yml

# Create bundle
flatpak build-bundle repo CloudToLocalLLM.flatpak com.CloudToLocalLLM.CloudToLocalLLM

# Test installation
flatpak install --user CloudToLocalLLM.flatpak

# Run the app
flatpak run com.CloudToLocalLLM.CloudToLocalLLM
```

## Flatpak Manifest Configuration

The Flatpak manifest (`com.CloudToLocalLLM.CloudToLocalLLM.yml`) defines:

### Runtime and SDK

- **Runtime**: `org.freedesktop.Platform` version 23.08
- **SDK**: `org.freedesktop.Sdk` version 23.08

These provide the base system libraries and development tools.

### Permissions (finish-args)

- `--share=ipc` - Inter-process communication
- `--socket=x11` - X11 display server access
- `--socket=wayland` - Wayland display server access
- `--device=dri` - GPU acceleration
- `--share=network` - Network access for API calls
- `--filesystem=home` - Home directory access for configuration
- `--socket=session-bus` - D-Bus session bus for desktop integration
- `--socket=pulseaudio` - Audio access (for notifications)

### Build Commands

The manifest copies the Flutter build output and installs:

1. Main executable
2. Required libraries and data files
3. Desktop file for application menu
4. Application icon
5. AppStream metadata for software centers

## Distribution Options

### Option 1: GitHub Releases (Current)

- Users download `.flatpak` file from GitHub releases
- Manual installation: `flatpak install CloudToLocalLLM-*.flatpak`
- Simple but requires manual updates

### Option 2: Flathub (Recommended for Future)

- Submit to Flathub for centralized distribution
- Users can install via: `flatpak install flathub com.CloudToLocalLLM.CloudToLocalLLM`
- Automatic updates through Flatpak
- Better discoverability in software centers

To publish to Flathub:

1. Fork https://github.com/flathub/flathub
2. Add your manifest to the repository
3. Submit a pull request
4. Follow Flathub review process

## Supported Linux Distributions

Flatpak works on all major Linux distributions:

- ✅ Ubuntu / Debian / Linux Mint
- ✅ Fedora / RHEL / CentOS
- ✅ Arch Linux / Manjaro
- ✅ openSUSE
- ✅ Pop!_OS
- ✅ Elementary OS
- ✅ And many more...

## Troubleshooting

### Build Fails with GTK Errors

```bash
# Install GTK development libraries
sudo apt-get install libgtk-3-dev
```

### Flatpak Build Fails

```bash
# Ensure Freedesktop runtime is installed
flatpak install flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08

# Clear build cache and retry
rm -rf build-dir repo
flatpak-builder --force-clean --repo=repo build-dir com.CloudToLocalLLM.CloudToLocalLLM.yml
```

### Application Won't Start

```bash
# Check Flatpak logs
flatpak run --command=sh com.CloudToLocalLLM.CloudToLocalLLM
journalctl --user -xe | grep CloudToLocalLLM
```

### Missing Dependencies

```bash
# Verify all build dependencies
flutter doctor -v
```

## Performance Considerations

### Build Time

- First build: ~10-15 minutes (includes SDK download)
- Subsequent builds: ~5-8 minutes (with cache)
- Flatpak packaging: ~2-3 minutes

### Artifact Size

- Flutter Linux build: ~50-80 MB
- Flatpak package: ~80-120 MB (includes runtime dependencies)

### Caching Strategy

The workflow caches:

- Flutter SDK and pub dependencies
- Flatpak SDK and runtime
- Build artifacts

Expected cache hit rate: >80% for subsequent builds

## Cost Analysis

**GitHub-hosted runners (ubuntu-latest):**

- Public repositories: **FREE unlimited minutes**
- Private repositories: 2,000 free minutes/month

**CloudToLocalLLM Status**: Public repository
**Monthly Cost**: **$0** (completely free)

## Next Steps

After enabling Linux builds:

1. **Test the workflow** - Trigger a manual build to verify everything works
2. **Update documentation** - Add Linux installation instructions to README
3. **Create test plan** - Test on multiple Linux distributions
4. **Consider Flathub** - Submit to Flathub for wider distribution
5. **Monitor feedback** - Gather user feedback on Linux builds

## References

- [Flatpak Documentation](https://docs.flatpak.org/)
- [Flutter Linux Deployment](https://docs.flutter.dev/deployment/linux)
- [Flathub Submission Guide](https://github.com/flathub/flathub/wiki/App-Submission)
- [Freedesktop SDK](https://gitlab.com/freedesktop-sdk/freedesktop-sdk)
- [AppStream Metadata](https://www.freedesktop.org/software/appstream/docs/)
