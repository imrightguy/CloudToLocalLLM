#!/bin/bash

# CloudToLocalLLM ArchLinux Flutter/Dart Setup Script
# Simple installation script for Flutter and Dart SDK

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLUTTER_VERSION="3.32.8"
FLUTTER_INSTALL_DIR="/opt/flutter"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install required system packages
install_system_packages() {
    log_info "Installing required system packages..."

    sudo pacman -Sy --noconfirm
    sudo pacman -S --noconfirm git curl wget unzip which base-devel cmake ninja clang gtk3 libepoxy xz

    log_success "System packages installed"
}

# Remove existing Flutter installation
remove_existing_flutter() {
    if [[ -d "$FLUTTER_INSTALL_DIR" ]]; then
        log_info "Removing existing Flutter installation..."
        sudo rm -rf "$FLUTTER_INSTALL_DIR"
    fi
}

# Download and install Flutter
install_flutter() {
    log_info "Installing Flutter $FLUTTER_VERSION..."

    # Download Flutter
    local flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    local temp_file="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

    log_info "Downloading Flutter..."
    wget -O "$temp_file" "$flutter_url"

    # Extract Flutter
    log_info "Extracting Flutter..."
    sudo tar -xf "$temp_file" -C "$(dirname "$FLUTTER_INSTALL_DIR")"

    # Set proper ownership
    sudo chown -R "$USER:users" "$FLUTTER_INSTALL_DIR"

    # Clean up
    rm -f "$temp_file"

    log_success "Flutter installed successfully"
}

# Fix Git ownership issues
fix_git_ownership() {
    log_info "Fixing Git ownership issues..."

    git config --global --add safe.directory "$FLUTTER_INSTALL_DIR"
    sudo chown -R "$USER:users" "$FLUTTER_INSTALL_DIR"

    log_success "Git ownership issues fixed"
}

# Configure environment variables
configure_environment() {
    log_info "Configuring environment..."

    # Add Flutter to PATH
    echo 'export PATH="/opt/flutter/bin:$PATH"' >> ~/.bashrc
    export PATH="/opt/flutter/bin:$PATH"

    log_success "Environment configured"
}

# Run Flutter doctor
run_flutter_doctor() {
    log_info "Running Flutter doctor..."

    flutter doctor --android-licenses || true
    flutter doctor -v

    log_success "Flutter doctor completed"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    flutter --version
    dart --version

    log_success "Installation verified"
}

# Main function
main() {
    log_info "CloudToLocalLLM ArchLinux Flutter/Dart Setup"
    log_info "============================================="

    install_system_packages
    remove_existing_flutter
    install_flutter
    fix_git_ownership
    configure_environment
    run_flutter_doctor
    verify_installation

    log_success "Flutter and Dart setup completed!"
    log_info "Run 'source ~/.bashrc' to update your PATH"
}

# Execute main function
main "$@"
