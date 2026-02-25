#!/bin/bash

# CloudToLocalLLM Full Release Script (WSL Orchestration)
# Builds Windows and Linux assets and creates GitHub release

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_OWNER="imrightguy"
REPO_NAME="CloudToLocalLLM"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get version from pubspec.yaml
get_version() {
    if [[ -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1
    else
        print_error "pubspec.yaml not found"
        exit 1
    fi
}

# Build Windows packages using PowerShell script
build_windows_packages() {
    local version="$1"
    print_status "Building Windows packages..."
    # Convert project root to a Windows path for PowerShell
    local windows_project_root=$(wslpath -w "$PROJECT_ROOT")
    # Call PowerShell script from WSL using the Windows path
    powershell.exe -ExecutionPolicy Bypass -File "$windows_project_root\scripts\powershell\Build-GitHubReleaseAssets.ps1" -InstallInnoSetup
    if [[ $? -ne 0 ]]; then
        print_error "Failed to build Windows packages."
        exit 1
    fi
    print_success "Windows packages built successfully."
}

check_and_install_git() {
    print_status "Checking for Git installation..."
    if ! pacman -Q git &>/dev/null; then
        print_error "Git not found in your Arch Linux WSL environment."
        print_error "Please install Git manually by running: sudo pacman -S git"
        exit 1
    else
        print_success "Git is already installed."
    fi
}

check_and_install_which() {
    print_status "Checking for 'which' command..."
    if ! command -v which &>/dev/null; then
        print_warning "'which' command not found. Installing coreutils..."
        sudo pacman -S --noconfirm coreutils
        if [[ $? -ne 0 ]]; then
            print_error "Failed to install coreutils. Please install it manually: sudo pacman -S coreutils"
            exit 1
        fi
        print_success "'which' command installed successfully."
    else
        print_success "'which' command is already installed."
    fi
}

# Build Linux packages using build_all_packages.sh
build_linux_packages() {
    local version="$1"
    print_status "Building Linux packages..."
    check_and_install_git # Ensure Git is installed before proceeding
    check_and_install_which # Ensure 'which' is installed before proceeding
    "$PROJECT_ROOT/scripts/packaging/build_all_packages.sh" --skip-increment
    if [[ $? -ne 0 ]]; then
        print_error "Failed to build Linux packages."
        exit 1
    fi
    print_success "Linux packages built successfully."
}

# Create GitHub release
create_github_release() {
    local version="$1"
    print_status "Creating GitHub release..."
    "$PROJECT_ROOT/scripts/release/create_github_release.sh"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create GitHub release."
        exit 1
    fi
    print_success "GitHub release created successfully."
}

# Main function
main() {
    print_status "CloudToLocalLLM Full Release Orchestration (WSL)"
    print_status "================================================="

    # Change to project root
    cd "$PROJECT_ROOT"

    # Get version
    local version=$(get_version)
    print_status "Current version: $version"

    # Build Windows packages
    build_windows_packages "$version"

    # Build Linux packages
    build_linux_packages "$version"

    # Create GitHub release
    create_github_release "$version"

    print_success "Full release process completed successfully!"
}

# Execute main function
main "$@"