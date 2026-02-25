#!/bin/bash
# Setup GitHub Actions Runner in WSL for Linux builds
# Run this script from within your WSL distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}GitHub Actions Linux Runner Setup (WSL)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Configuration
GITHUB_REPO="https://github.com/CloudToLocalLLM-online/CloudToLocalLLM"
RUNNER_LABELS="linux,self-hosted,wsl"
# Get hostname, fallback if command not available
if command -v hostname &> /dev/null; then
    RUNNER_NAME="WSL-Linux-$(hostname)"
else
    RUNNER_NAME="WSL-Linux-${HOSTNAME:-WSL}"
fi
FLUTTER_VERSION="3.24.0"
RUNNER_VERSION="2.317.0"

# Check if running in WSL
if [ ! -f /proc/version ] || ! grep -qi microsoft /proc/version; then
    echo -e "${YELLOW}WARNING: This doesn't appear to be running in WSL.${NC}"
    echo "Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    echo -e "${GREEN}Detected Linux distribution: $DISTRO${NC}"
else
    echo -e "${RED}ERROR: Cannot detect Linux distribution${NC}"
    exit 1
fi

# Install dependencies based on distribution
echo -e "${CYAN}Installing build dependencies...${NC}"

if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "debian" ]]; then
    sudo apt-get update
    sudo apt-get install -y \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        clang \
        cmake \
        ninja-build \
        pkg-config \
        libgtk-3-dev \
        liblzma-dev \
        libstdc++-12-dev \
        build-essential \
        ca-certificates
elif [[ "$DISTRO" == "fedora" ]]; then
    sudo dnf install -y \
        curl \
        git \
        unzip \
        xz \
        zip \
        mesa-libGLU \
        clang \
        cmake \
        ninja-build \
        pkgconfig \
        gtk3-devel \
        xz-devel \
        gcc-c++ \
        glibc-devel \
        libstdc++-devel \
        ca-certificates
else
    echo -e "${YELLOW}Unsupported distribution: $DISTRO${NC}"
    echo "Please install the following packages manually:"
    echo "  curl, git, unzip, xz-utils, zip, libglu1-mesa, clang, cmake, ninja-build, pkg-config, libgtk-3-dev"
    exit 1
fi

echo -e "${GREEN}âœ“ Dependencies installed${NC}"

# Install Flutter
echo -e "${CYAN}Checking Flutter installation...${NC}"
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}âœ“ Flutter is already installed${NC}"
    flutter --version
else
    echo -e "${CYAN}Installing Flutter SDK...${NC}"
    FLUTTER_HOME="$HOME/flutter"
    
    if [ ! -d "$FLUTTER_HOME" ]; then
        git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_HOME"
    else
        cd "$FLUTTER_HOME"
        git pull
        cd -
    fi
    
    export PATH="$FLUTTER_HOME/bin:$PATH"
    
    # Add to shell profile
    if [ -f ~/.bashrc ]; then
        if ! grep -q "flutter/bin" ~/.bashrc; then
            echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
        fi
    fi
    
    # Enable Linux desktop
    "$FLUTTER_HOME/bin/flutter" config --enable-linux-desktop
    
    echo -e "${GREEN}âœ“ Flutter installed${NC}"
fi

# Run flutter doctor to verify
echo -e "${CYAN}Running Flutter doctor...${NC}"
flutter doctor

# Setup GitHub Actions Runner
echo -e "${CYAN}Setting up GitHub Actions Runner...${NC}"

RUNNER_DIR="$HOME/actions-runner"

if [ -f "$RUNNER_DIR/.runner" ]; then
    echo -e "${YELLOW}Runner appears to be already configured.${NC}"
    echo "Reconfigure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Skipping runner setup."
        exit 0
    fi
    # Remove old configuration
    rm -rf "$RUNNER_DIR"
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Download runner
echo -e "${CYAN}Downloading GitHub Actions Runner v${RUNNER_VERSION}...${NC}"
curl -o "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# Extract
echo -e "${CYAN}Extracting runner...${NC}"
tar xzf "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
rm "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# Get runner token
echo -e "${CYAN}GitHub Runner Registration${NC}"
echo "Get your runner token from:"
echo "  ${GITHUB_REPO}/settings/actions/runners/new"
echo ""
echo -n "Enter your GitHub runner registration token: "
read -r RUNNER_TOKEN

if [ -z "$RUNNER_TOKEN" ]; then
    echo -e "${RED}ERROR: Runner token is required${NC}"
    exit 1
fi

# Configure runner
echo -e "${CYAN}Configuring runner...${NC}"
./config.sh \
    --url "$GITHUB_REPO" \
    --token "$RUNNER_TOKEN" \
    --labels "$RUNNER_LABELS" \
    --name "$RUNNER_NAME" \
    --unattended

if [ $? -eq 0 ]; then
    echo -e "${GREEN}âœ“ Runner configured successfully${NC}"
else
    echo -e "${RED}ERROR: Runner configuration failed${NC}"
    exit 1
fi

# Create systemd service (for WSL - requires systemd support or alternative)
echo -e "${CYAN}Setting up runner service...${NC}"

# Check if systemd is available
if systemctl --version &> /dev/null; then
    echo -e "${CYAN}Using systemd service...${NC}"
    sudo ./svc.sh install
    sudo ./svc.sh start
    echo -e "${GREEN}âœ“ Runner service installed and started${NC}"
else
    echo -e "${YELLOW}Systemd not available. Runner can be started manually with:${NC}"
    echo "  cd $RUNNER_DIR && ./run.sh"
    echo ""
    echo "Or add to ~/.bashrc:"
    echo "  (cd $RUNNER_DIR && ./run.sh) &"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "1. Verify runner in GitHub:"
echo "   ${GITHUB_REPO}/settings/actions/runners"
echo ""
echo "2. If systemd is not available, start runner manually:"
echo "   cd $RUNNER_DIR"
echo "   ./run.sh"
echo ""
echo "3. Test the runner by pushing a version tag"

