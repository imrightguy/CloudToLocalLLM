# Detailed Plan to Install Required CLI Tools for CloudToLocalLLM Repository

## Overview
This plan outlines the step-by-step installation of required CLI tools for the CloudToLocalLLM repository on Linux (Ubuntu-based system). The tools include Git, Flutter SDK (3.5+), Node.js (version 24 as specified), and Ollama. The plan ensures OS compatibility, handles dependencies, includes verification commands, and provides troubleshooting steps. After installation, the README.md will be updated with installed versions and status notes.

## Prerequisites
- Operating System: Linux (kernel 6.17, assumed Ubuntu-based)
- Internet connection for downloading packages and SDKs
- Sudo privileges for system package installations
- Terminal access

## Required Tools and Versions
Based on repository README.md, file structure (k8s/, docker-compose.production.yml, Dockerfile/), and user specifications:
- Git: Latest stable (2.x)
- Flutter SDK: 3.5+ (target 3.24.0 or latest stable)
- Node.js: 24.x (updated from README's 22+)
- Ollama: Latest stable
- Docker: Latest stable (for containerization, as evidenced by Dockerfiles and docker-compose)
- kubectl: Latest stable (for Kubernetes management, as evidenced by k8s/ directory and deployment scripts)

## Step-by-Step Installation Guide

### Step 1: Check Current Installations
**Purpose:** Determine which tools are already installed to avoid redundant installations.

**Actions:**
- Open terminal in workspace directory `/media/rightguy/OTHERDATA/dev/CloudToLocalLLM`
- Run version checks:
  - `git --version`
  - `flutter --version`
  - `node --version` && `npm --version`
  - `ollama --version`
  - `docker --version`
  - `kubectl version --client`

**Expected Output:**
- Git: `git version 2.x.x`
- Flutter: `Flutter 3.x.x • channel stable`
- Node.js: `v24.x.x` and `10.x.x` for npm
- Ollama: `ollama version x.x.x`
- Docker: `Docker version 24.x.x, build xxxxxxx`
- kubectl: `Client Version: v1.x.x`

**If command fails:** Tool is not installed, proceed to installation step.

### Step 2: Install Git (if not present)
**Prerequisites:** None (system tool)

**Actions:**
1. Update package list: `sudo apt update`
2. Install Git: `sudo apt install git -y`

**Verification:**
- `git --version`

**Troubleshooting:**
- If `sudo apt update` fails: Check internet connection or run `sudo apt --fix-broken install`
- If installation fails: `sudo apt install git-all` or use snap: `sudo snap install git`

### Step 3: Install Flutter SDK (3.5+)
**Prerequisites:** Git (for flutter doctor), unzip/tar for extraction

**Actions:**
1. Check latest stable version at https://docs.flutter.dev/get-started/install/linux
2. Download SDK: `wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz` (replace with actual latest if different)
3. Extract: `tar xf flutter_linux_3.24.0-stable.tar.xz`
4. Move to home directory: `mv flutter ~/flutter`
5. Add to PATH: `echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc`
6. Source bashrc: `source ~/.bashrc`

**Verification:**
- `flutter --version` (should show Flutter 3.24.0 or similar)
- `flutter doctor` (comprehensive check; may show warnings for Android SDK, but core Flutter should be ready)

**Troubleshooting:**
- If PATH not recognized: Restart terminal or run `export PATH="$PATH:$HOME/flutter/bin"` manually
- If download fails: Check URL or use `git clone https://github.com/flutter/flutter.git -b stable ~/flutter`
- If flutter doctor shows issues: Install missing dependencies as prompted (e.g., `sudo apt install curl unzip`)

### Step 4: Install Node.js 24
**Prerequisites:** curl

**Actions:**
1. Add NodeSource repository: `curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -`
2. Install Node.js: `sudo apt-get install -y nodejs`

**Verification:**
- `node --version` (should be v24.x.x)
- `npm --version` (should be 10.x.x or compatible)

**Troubleshooting:**
- If curl fails: Check internet or use wget: `wget -qO- https://deb.nodesource.com/setup_24.x | sudo -E bash -`
- If install fails: `sudo apt update` then retry
- If version mismatch: `sudo npm install -g n` then `sudo n 24`

### Step 5: Install Ollama
**Prerequisites:** None (standalone installer)

**Actions:**
1. Run install script: `curl -fsSL https://ollama.com/install.sh | sh`

**Verification:**
- `ollama --version` (should show version, e.g., 0.3.x)
- Optional: `ollama list` (should show no models initially)

**Troubleshooting:**
- If curl fails: Check internet or download manually from https://ollama.com/download
- If permission denied: Run with sudo if needed, but script handles it
- If fails on Linux: Ensure systemd is available; for WSL, may need additional setup

### Step 6: Install Docker
**Prerequisites:** None (system package)

**Actions:**
1. Update package list: `sudo apt update`
2. Install Docker: `sudo apt install docker.io -y`
3. Start and enable Docker service: `sudo systemctl start docker && sudo systemctl enable docker`
4. Add user to docker group (optional, for non-sudo usage): `sudo usermod -aG docker $USER` (requires logout/login to take effect)

**Verification:**
- `docker --version` (should show Docker version 24.x.x)
- `sudo docker run hello-world` (test basic functionality)

**Troubleshooting:**
- If systemctl fails: Use `sudo service docker start`
- If permission issues: Run Docker commands with sudo, or complete the group addition
- If apt fails: Use snap: `sudo snap install docker`

### Step 7: Install kubectl
**Prerequisites:** curl

**Actions:**
1. Download kubectl: `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"`
2. Make executable: `chmod +x kubectl`
3. Move to PATH: `sudo mv kubectl /usr/local/bin/`

**Verification:**
- `kubectl version --client` (should show Client Version: v1.x.x)

**Troubleshooting:**
- If curl fails: Check internet or download manually from https://kubernetes.io/docs/tasks/tools/
- If permission denied: Ensure /usr/local/bin is writable or use ~/bin and add to PATH
- For specific versions: Replace stable.txt with desired version

### Step 9: Install Project Dependencies
**Purpose:** Install Flutter and Node.js dependencies for the repository.

**Actions:**
1. Install Flutter dependencies: `flutter pub get`
2. Install backend dependencies: `cd services/api-backend && npm install`

**Verification:**
- Flutter: No errors in output; pubspec.lock created/updated
- Node.js: No errors; node_modules created in services/api-backend

**Troubleshooting:**
- If flutter pub get fails: `flutter clean` then retry
- If npm install fails: `rm -rf node_modules package-lock.json` then `npm install`
- Ensure correct directory: Run from workspace root

### Step 10: Run Provided Tests/Checks
**Actions:**
- Flutter check: `flutter doctor`
- Ollama verification: `ollama pull llama3.2` (as per README prerequisite)
- Node.js check: `cd services/api-backend && npm test` (if test script exists in package.json)
- Docker check: `docker --version && sudo docker run hello-world`
- kubectl check: `kubectl version --client`

**Verification:**
- flutter doctor: No critical errors
- ollama pull: Model downloaded successfully
- npm test: Tests pass (if available)
- Docker: Version shown and hello-world runs
- kubectl: Client version shown

### Step 11: Update README.md
**Actions:**
1. Read current README.md
2. Update Node.js requirement from "Node.js 22+" to "Node.js 24+"
3. Add a new section under Prerequisites or Development:

```
### Installed Versions (Verified on Linux)
- Flutter: 3.24.0
- Node.js: 24.x.x
- npm: 10.x.x
- Ollama: 0.3.x
- Git: 2.x.x
- Docker: 24.x.x
- kubectl: v1.x.x

Status: All CLI tools installed and verified. Run `flutter doctor`, `node --version`, `ollama --version`, `docker --version`, `kubectl version --client` to confirm.
```

4. Save changes

**Verification:**
- README.md updated with accurate versions and notes

## Fallback Troubleshooting
- **Package manager issues:** `sudo apt autoremove && sudo apt autoclean && sudo apt update`
- **Permission issues:** Use `sudo` where appropriate, or check user groups
- **Network issues:** Use proxy if needed, or download manually
- **Version conflicts:** Uninstall old versions before installing new ones
- **WSL-specific:** If running in WSL, ensure Windows interop is enabled for Ollama

## Post-Installation Notes
- Restart terminal to ensure PATH changes take effect
- For Flutter development, consider installing Android Studio or VS Code extensions
- Ollama models are downloaded on-demand; the CLI tool itself is installed
- Docker requires sudo for most commands unless user is added to docker group (logout/login required)
- kubectl is configured for client-side only; for cluster access, additional kubeconfig setup needed
- All installations are system-wide where applicable

This plan ensures a complete, verified setup of all required CLI tools for the CloudToLocalLLM repository.