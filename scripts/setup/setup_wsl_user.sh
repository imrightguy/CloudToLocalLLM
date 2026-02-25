#!/bin/bash
# Consolidated setup script for WSL Ubuntu (User-level parts)
set -e

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

# 3. Project Dependencies
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

# Verification
echo "--- Verification ---"
echo "Node: $(node -v)"
echo "NPM: $(npm -v)"
flutter --version
ollama --version
kubectl version --client

echo "User-level Setup Complete!"
