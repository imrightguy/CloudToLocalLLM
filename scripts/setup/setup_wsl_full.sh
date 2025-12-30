#!/bin/bash
# Consolidated setup script for WSL Ubuntu
set -e

echo "Updating system..."
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip build-essential ca-certificates libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

# 1. Install NVM and Node.js 24
if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
echo "Installing Node.js 24..."
nvm install 24
nvm use 24

# 2. Install Flutter
if [ ! -d "$HOME/flutter" ]; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
if ! grep -q "flutter/bin" ~/.bashrc; then
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
fi
flutter config --enable-linux-desktop

# 3. Install Ollama
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# 4. Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Verification
echo "--- Verification ---"
echo "Node: $(node -v)"
echo "NPM: $(npm -v)"
flutter --version
ollama --version
kubectl version --client

# 5. Project Dependencies
echo "Installing Project Dependencies..."
cd /mnt/d/dev/CloudToLocalLLM

echo "Running flutter pub get..."
flutter pub get

if [ -f "package.json" ]; then
    echo "Running npm install in root..."
    npm install
fi

if [ -d "services/api-backend" ]; then
    echo "Running npm install in services/api-backend..."
    cd services/api-backend && npm install
fi

echo "Setup Complete!"
