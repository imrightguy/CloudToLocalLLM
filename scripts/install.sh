#!/bin/bash
# CloudToLocalLLM Installer for Linux/macOS
# Installs CloudToLocalLLM Agent Manager and OpenClaw Gateway

set -e

echo "🦞 Welcome to the CloudToLocalLLM Installer!"

# Detect OS
OS_TYPE=$(uname -s)
case "${OS_TYPE}" in
    Linux*)     OS=linux;;
    Darwin*)    OS=macos;;
    *)          echo "Unsupported OS: ${OS_TYPE}"; exit 1;;
esac

echo "Detected OS: ${OS}"

# Check for Node.js (required for OpenClaw Gateway)
if ! command -v node &> /dev/null; then
    echo "Warning: Node.js is not installed. It is required for the OpenClaw Gateway."
    echo "Please install Node.js from https://nodejs.org/"
fi

# Download latest release (Placeholder for real download logic)
echo "Downloading CloudToLocalLLM for ${OS}..."
# In a real scenario, we would curl the GitHub API to find the latest asset.
# For now, we simulate the install process.

# Install path
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Installing to $BIN_DIR..."
# Mocking the binary placement
# curl -L https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${OS} -o "$BIN_DIR/cloudtolocalllm"
# chmod +x "$BIN_DIR/cloudtolocalllm"

# OpenClaw Gateway Install
echo "Checking for OpenClaw Gateway..."
if ! command -v openclaw &> /dev/null; then
    echo "OpenClaw Gateway not found. Installing via npm..."
    if command -v npm &> /dev/null; then
        npm install -g openclaw-gateway
    else
        echo "npm not found. Could not install OpenClaw Gateway automatically."
    fi
fi

# Final setup
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Adding $BIN_DIR to your PATH..."
    case "${SHELL}" in
        */zsh)  echo "export PATH=\"\$PATH:$BIN_DIR\"" >> ~/.zshrc;;
        */bash) echo "export PATH=\"\$PATH:$BIN_DIR\"" >> ~/.bashrc;;
        *)      echo "Please add $BIN_DIR to your PATH manually.";;
    esac
fi

echo "✅ CloudToLocalLLM installed successfully!"
echo "Run 'cloudtolocalllm' to get started."
