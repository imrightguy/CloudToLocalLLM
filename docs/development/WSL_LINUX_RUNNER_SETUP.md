# WSL Linux Self-Hosted Runner Setup Guide

This guide explains how to set up a GitHub Actions Linux runner in WSL (Windows Subsystem for Linux) for building Linux desktop apps.

## 📋 Overview

Using WSL for the Linux runner allows you to:

- Build Linux apps on your Windows machine
- Use native Linux build tools
- Test Linux builds locally
- Avoid needing a separate Linux server

## 🎯 Prerequisites

- **Windows 10/11** with WSL2 installed
- **WSL distribution** (Ubuntu, Fedora, etc.)
- **GitHub account** with access to the repository
- **Administrator privileges** (may be needed for some installations)

## 🚀 Quick Setup

### Option 1: Automated Setup (Recommended)

From PowerShell:

```powershell
.\scripts\powershell\Setup-WSLLinuxRunner.ps1
```

This will guide you through the setup process.

### Option 2: Manual Setup

1. **Open your WSL distribution:**

   ```powershell
   wsl -d FedoraLinux-43
   # Or your distribution name
   ```

2. **Navigate to the project:**

   ```bash
   cd /mnt/d/dev/CloudToLocalLLM
   ```

3. **Run the setup script:**

   ```bash
   bash scripts/setup-wsl-linux-runner.sh
   ```

4. **Follow the prompts:**
   - Enter your GitHub runner registration token
   - Wait for dependencies to install
   - Flutter will be installed automatically

## 📝 Detailed Setup Instructions

### Step 1: Get Runner Registration Token

1. Go to: `https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/settings/actions/runners`
2. Click **New runner**
3. Select **Linux** and **x64**
4. Copy the registration token

### Step 2: Install Dependencies

The setup script automatically installs:

- Build tools (clang, cmake, ninja-build, pkg-config)
- GTK development libraries (libgtk-3-dev)
- Flutter SDK
- GitHub Actions Runner

### Step 3: Configure Runner

The script will:

- Download the GitHub Actions runner
- Configure it with your token
- Set up labels: `linux`, `self-hosted`, `wsl`
- Install as a service (if systemd is available)

### Step 4: Start Runner

**If systemd is available:**

```bash
cd ~/actions-runner
sudo ./svc.sh install
sudo ./svc.sh start
```

**If systemd is not available (most WSL setups):**

```bash
cd ~/actions-runner
./run.sh
```

Or add to `~/.bashrc`:

```bash
(cd ~/actions-runner && ./run.sh) &
```

## 🔧 Manual Installation Steps

If you prefer to set up manually:

### 1. Install Build Dependencies

**Ubuntu/Debian:**

```bash
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa \
    clang cmake ninja-build pkg-config libgtk-3-dev \
    liblzma-dev libstdc++-12-dev build-essential
```

**Fedora:**

```bash
sudo dnf install -y curl git unzip xz zip mesa-libGLU \
    clang cmake ninja-build pkgconfig gtk3-devel \
    xz-devel gcc-c++ glibc-devel libstdc++-devel
```

### 2. Install Flutter

```bash
# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable ~/flutter

# Add to PATH
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Enable Linux desktop
flutter config --enable-linux-desktop

# Verify
flutter doctor
```

### 3. Set Up GitHub Actions Runner

```bash
# Create runner directory
mkdir -p ~/actions-runner
cd ~/actions-runner

# Download runner
RUNNER_VERSION="2.317.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Configure
./config.sh --url https://github.com/CloudToLocalLLM-online/CloudToLocalLLM \
    --token YOUR_TOKEN \
    --labels linux,self-hosted,wsl \
    --name WSL-Linux-$(hostname) \
    --unattended
```

### 4. Start Runner

```bash
./run.sh
```

## 🔍 Verification

### Check Runner Status

1. **In GitHub:**
   - Visit: `https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/settings/actions/runners`
   - Your runner should appear with green "Idle" status
   - Labels: `linux`, `self-hosted`, `wsl`

2. **In WSL:**

   ```bash
   cd ~/actions-runner
   cat .runner
   ```

### Test Build

Push a version tag to trigger a build:

```bash
git tag v4.1.2
git push origin v4.1.2
```

The workflow will use your WSL runner for Linux builds.

## 🔄 Managing the Runner

### Start Runner Manually

```bash
cd ~/actions-runner
./run.sh
```

### Stop Runner

Press `Ctrl+C` or:

```bash
pkill -f Runner.Listener
```

### Update Runner

```bash
cd ~/actions-runner

# Stop runner
./svc.sh stop  # If using service
# Or kill process if running manually

# Download new version
RUNNER_VERSION="2.317.0"  # Update to latest
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Restart
./run.sh  # Or ./svc.sh start
```

### Remove Runner

```bash
cd ~/actions-runner

# Remove from GitHub (get token from GitHub UI)
./config.sh remove --token YOUR_TOKEN

# Remove directory
cd ~
rm -rf ~/actions-runner
```

## 🐛 Troubleshooting

### Flutter Not Found

```bash
# Add Flutter to PATH
export PATH="$HOME/flutter/bin:$PATH"

# Add to ~/.bashrc for persistence
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Missing Build Dependencies

```bash
# Run Flutter doctor
flutter doctor

# Install missing dependencies based on errors
```

### Runner Not Connecting

1. **Check network:**

   ```bash
   curl -I https://github.com
   ```

2. **Check runner logs:**

   ```bash
   cd ~/actions-runner/_diag
   tail -50 Runner_*.log
   ```

3. **Reconfigure runner:**

   ```bash
   cd ~/actions-runner
   ./config.sh remove --token YOUR_TOKEN
   ./config.sh --url https://github.com/CloudToLocalLLM-online/CloudToLocalLLM \
       --token YOUR_TOKEN \
       --labels linux,self-hosted,wsl \
       --name WSL-Linux-$(hostname)
   ```

### Build Failures

Check the workflow logs in GitHub Actions for specific error messages. Common issues:

- Missing dependencies (install via package manager)
- Flutter version mismatch (update Flutter)
- Permissions issues (check file permissions)

### WSL Systemd Issues

If systemd is not available in WSL:

1. **Use manual start:**

   ```bash
   cd ~/actions-runner
   ./run.sh
   ```

2. **Auto-start on WSL launch:**
   Add to `~/.bashrc`:

   ```bash
   if ! pgrep -f "Runner.Listener" > /dev/null; then
       (cd ~/actions-runner && ./run.sh) &
   fi
   ```

## 📊 Workflow Configuration

The workflow automatically uses runners with labels `linux` and `self-hosted`. No changes needed if you configured the runner with those labels.

## 🔒 Security Considerations

- **Runner tokens:** Keep your registration token secret
- **Repository access:** Self-hosted runners have access to repository code
- **Network security:** Ensure your firewall allows GitHub connections
- **WSL isolation:** Runner runs in WSL, providing some isolation from Windows

## 📚 Additional Resources

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Flutter Linux Setup](https://docs.flutter.dev/get-started/install/linux)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)

## ✅ Checklist

After setup, verify:

- [ ] WSL distribution is running
- [ ] Build dependencies installed
- [ ] Flutter SDK installed and configured
- [ ] GitHub Actions Runner configured
- [ ] Runner appears in GitHub with green status
- [ ] Test build succeeds

---

**Note:** The runner needs to stay running (via `run.sh` or service) to accept jobs. Consider setting up auto-start on WSL launch.
