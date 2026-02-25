# Windows Self-Hosted GitHub Actions Runner Setup Guide

This guide walks you through setting up a Windows machine as a self-hosted GitHub Actions runner to build the Windows app for CloudToLocalLLM.

## 📋 Overview

A self-hosted runner allows you to run GitHub Actions workflows on your own Windows machine, which is useful for:

- Building Windows applications locally
- Faster build times
- More control over the build environment
- Avoiding GitHub Actions usage limits

## 🎯 Prerequisites

- **Windows 10/11** (64-bit)
- **Administrator privileges** (recommended)
- **Internet connection** for downloading tools
- **At least 20GB free disk space** for tools and builds
- **GitHub account** with access to the repository

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)

Run the automated setup script:

```powershell
# Run PowerShell as Administrator (recommended)
.\scripts\powershell\Setup-WindowsSelfHostedRunner.ps1
```

The script will:

1. Install Chocolatey package manager
2. Install Git for Windows
3. Install Visual Studio Build Tools 2022 (C++ workload)
4. Install Flutter SDK (version 3.24.0)
5. Download and configure GitHub Actions Runner
6. Install runner as a Windows service
7. Verify the setup

### Option 2: Manual Setup

If you prefer to set up manually or the script fails, see the [Manual Setup](#manual-setup) section below.

## 📝 Detailed Setup Instructions

### Step 1: Get Runner Registration Token

1. Go to your GitHub repository: `https://github.com/CloudToLocalLLM-online/CloudToLocalLLM`
2. Navigate to: **Settings** → **Actions** → **Runners**
3. Click **New runner**
4. Select **Windows** and **x64**
5. Copy the registration token (you'll need this in Step 5)

### Step 2: Run the Setup Script

```powershell
# Navigate to your repository
cd D:\dev\CloudToLocalLLM

# Run as Administrator (recommended)
.\scripts\powershell\Setup-WindowsSelfHostedRunner.ps1
```

The script will prompt you for:

- GitHub runner registration token
- Runner name (defaults to computer name)

### Step 3: Verify Installation

After the script completes, verify everything is set up:

```powershell
# Check Flutter
flutter doctor

# Check runner service status
Get-Service actions.runner.*
```

### Step 4: Verify Runner in GitHub

1. Go to: `https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/settings/actions/runners`
2. You should see your runner listed with a green status
3. It should have labels: `windows`, `self-hosted`

## 🔧 Manual Setup

If you need to set up manually or troubleshoot:

### 1. Install Chocolatey

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### 2. Install Git

```powershell
choco install git -y
refreshenv
```

### 3. Install Visual Studio Build Tools 2022

Download and install from: https://visualstudio.microsoft.com/downloads/

Select:

- **C++ build tools** workload
- **Windows 10/11 SDK** (latest)
- **CMake tools for Windows**

Or use Chocolatey:

```powershell
choco install visualstudio2022buildtools -y
choco install visualstudio2022-workload-vctools -y
```

### 4. Install Flutter SDK

```powershell
# Install via Chocolatey
choco install flutter --version=3.24.0 -y
refreshenv

# Enable Windows desktop support
flutter config --enable-windows-desktop

# Verify installation
flutter doctor
```

### 5. Set Up GitHub Actions Runner

```powershell
# Create runner directory
New-Item -ItemType Directory -Path C:\actions-runner -Force
Set-Location C:\actions-runner

# Download runner (check for latest version at: https://github.com/actions/runner/releases)
$runnerVersion = "2.317.0"
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip" -OutFile "actions-runner.zip"

# Extract
Expand-Archive -Path "actions-runner.zip" -DestinationPath "." -Force
Remove-Item "actions-runner.zip" -Force

# Configure (replace YOUR_TOKEN with token from GitHub)
.\config.cmd --url https://github.com/CloudToLocalLLM-online/CloudToLocalLLM --token YOUR_TOKEN --labels windows,self-hosted --name YOUR_RUNNER_NAME --unattended

# Install as service
.\svc.exe install
.\svc.exe start
```

## 🔍 Verification and Testing

### Test the Runner

1. **Check runner status:**

   ```powershell
   Get-Service actions.runner.*
   ```

2. **View runner logs:**

   ```powershell
   Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50
   ```

3. **Test a build manually:**

   ```powershell
   cd D:\dev\CloudToLocalLLM
   flutter pub get
   flutter build windows --release
   ```

### Test via GitHub Actions

The workflow will automatically use your self-hosted runner when it has the label `windows` and `self-hosted`. You can trigger a test build by:

1. Creating a test tag: `git tag v4.1.1-test && git push origin v4.1.1-test`
2. Checking the Actions tab in GitHub to see if your runner picks up the job

## 🔄 Managing the Runner

### Start/Stop Runner Service

```powershell
# Stop runner
Stop-Service actions.runner.*

# Start runner
Start-Service actions.runner.*

# Restart runner
Restart-Service actions.runner.*
```

### Update Runner

```powershell
cd C:\actions-runner

# Stop service
.\svc.exe stop
.\svc.exe uninstall

# Download new version
$runnerVersion = "2.317.0"  # Update to latest version
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip" -OutFile "actions-runner.zip"
Expand-Archive -Path "actions-runner.zip" -DestinationPath "." -Force
Remove-Item "actions-runner.zip" -Force

# Reinstall service
.\svc.exe install
.\svc.exe start
```

### Remove Runner

```powershell
cd C:\actions-runner

# Stop and uninstall service
.\svc.exe stop
.\svc.exe uninstall

# Remove from GitHub (use the token from GitHub UI)
.\config.cmd remove --token YOUR_TOKEN

# Remove directory
cd ..
Remove-Item -Recurse -Force C:\actions-runner
```

## 🐛 Troubleshooting

### Runner Not Appearing in GitHub

1. **Check service status:**

   ```powershell
   Get-Service actions.runner.*
   ```

2. **Check logs:**

   ```powershell
   Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 100
   ```

3. **Verify configuration:**

   ```powershell
   cd C:\actions-runner
   Get-Content .runner
   ```

4. **Reconfigure if needed:**

   ```powershell
   cd C:\actions-runner
   .\config.cmd remove --token YOUR_TOKEN
   .\config.cmd --url https://github.com/CloudToLocalLLM-online/CloudToLocalLLM --token YOUR_TOKEN --labels windows,self-hosted
   ```

### Flutter Build Fails

1. **Check Flutter setup:**

   ```powershell
   flutter doctor -v
   ```

2. **Verify Visual Studio installation:**

   ```powershell
   # Check if Visual Studio is installed
   Test-Path "C:\Program Files\Microsoft Visual Studio\2022\BuildTools"
   ```

3. **Reinstall Visual Studio components if needed:**
   - Open Visual Studio Installer
   - Modify installation
   - Ensure "Desktop development with C++" workload is installed

### Runner Service Won't Start

1. **Check Windows Event Viewer:**

   ```powershell
   Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 10
   ```

2. **Try manual start:**

   ```powershell
   cd C:\actions-runner
   .\run.cmd
   ```

3. **Check permissions:**
   - Ensure the service account has necessary permissions
   - Try running as a different user account

### Build Timeouts

- Increase the timeout in the workflow file if builds take longer than expected
- Check available disk space
- Monitor system resources during builds

## 🔒 Security Considerations

- **Runner tokens:** Keep your runner registration token secret
- **Repository access:** Self-hosted runners have access to your repository code
- **Network security:** Ensure your firewall allows GitHub connections
- **Updates:** Keep the runner software updated regularly

## 📊 Monitoring

### View Runner Activity

1. GitHub UI: `https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/settings/actions/runners`
2. Runner logs: `C:\actions-runner\_diag\Runner_*.log`
3. Windows Event Viewer: Applications and Services Logs

### Resource Monitoring

Monitor CPU, memory, and disk usage during builds to ensure adequate resources.

## 📚 Additional Resources

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Flutter Windows Desktop Setup](https://docs.flutter.dev/get-started/install/windows)
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)

## ✅ Checklist

After setup, verify:

- [ ] Chocolatey installed and working
- [ ] Git installed and accessible
- [ ] Visual Studio Build Tools 2022 installed
- [ ] Flutter SDK 3.24.0 installed
- [ ] Flutter Windows desktop enabled
- [ ] GitHub Actions Runner configured
- [ ] Runner service running
- [ ] Runner appears in GitHub with green status
- [ ] Test build succeeds

## 🆘 Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review runner logs in `C:\actions-runner\_diag\`
3. Check GitHub Actions workflow runs for error messages
4. Verify all prerequisites are installed correctly
5. Try running `flutter doctor` and address any issues

---

**Note:** The runner will automatically start on Windows boot if installed as a service. Ensure your machine is powered on and connected to the internet for builds to run.
