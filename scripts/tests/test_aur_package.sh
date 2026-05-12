#!/bin/bash

# CloudToLocalLLM AUR Package Local Test Script
# This script simulates the AUR installation process using local build artifacts.

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist/linux"
AUR_TEST_DIR="$PROJECT_ROOT/dist/aur_test"

log_info "Starting local AUR package test..."

# 1. Build the Flutter Linux application
log_info "Building Flutter Linux release..."
flutter build linux --release

# 2. Package AppImage for AUR
log_info "Building AppImage package..."
"$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
cd "$PROJECT_ROOT"

# 3. Prepare AUR test directory
log_info "Preparing AUR test directory..."
rm -rf "$AUR_TEST_DIR"
mkdir -p "$AUR_TEST_DIR"
cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$AUR_TEST_DIR/"

# 4. Modify PKGBUILD for local testing
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
APPIMAGE_PATH="$DIST_DIR/cloudtolocalllm-${VERSION}-x86_64.AppImage"
CHECKSUM=$(sha256sum "$APPIMAGE_PATH" | cut -d' ' -f1)

log_info "Updating PKGBUILD with local version ($VERSION) and checksum..."
sed -i "s/pkgver=VERSION/pkgver=$VERSION/" "$AUR_TEST_DIR/PKGBUILD"
sed -i "s|source=(.*)|source=(\"cloudtolocalllm-${VERSION}-x86_64.AppImage\")|" "$AUR_TEST_DIR/PKGBUILD"
sed -i "s/sha256sums=(.*)/sha256sums=('$CHECKSUM')/" "$AUR_TEST_DIR/PKGBUILD"

# Link the local AppImage so makepkg can find it
ln -sf "$APPIMAGE_PATH" "$AUR_TEST_DIR/cloudtolocalllm-${VERSION}-x86_64.AppImage"

# 5. Build and install the package
log_info "Running makepkg -si..."
cd "$AUR_TEST_DIR"

# Note: We use --noconfirm for automation.
makepkg -si --noconfirm

log_success "AUR package installed successfully!"
log_info "You can now run the app using: CloudToLocalLLM"
