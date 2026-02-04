#!/bin/bash

# Zoidbot AUR Package Local Test Script
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

# 2. Package into tarball (standard format)
log_info "Packaging Linux bundle..."
mkdir -p "$DIST_DIR"
STAGING_DIR=$(mktemp -d)
mkdir -p "$STAGING_DIR/zoidbot"
cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/"* "$STAGING_DIR/zoidbot/"
tar -czf "$DIST_DIR/Zoidbot-Linux-x64.tar.gz" -C "$STAGING_DIR" zoidbot
rm -rf "$STAGING_DIR"
cd "$PROJECT_ROOT"

# 3. Prepare AUR test directory
log_info "Preparing AUR test directory..."
rm -rf "$AUR_TEST_DIR"
mkdir -p "$AUR_TEST_DIR"
cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$AUR_TEST_DIR/"

# 4. Modify PKGBUILD for local testing
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
CHECKSUM=$(sha256sum "$DIST_DIR/Zoidbot-Linux-x64.tar.gz" | cut -d' ' -f1)

log_info "Updating PKGBUILD with local version ($VERSION) and checksum..."
sed -i "s/pkgver=VERSION/pkgver=$VERSION/" "$AUR_TEST_DIR/PKGBUILD"
sed -i "s|source=(.*)|source=(\"local://Zoidbot-Linux-x64.tar.gz\")|" "$AUR_TEST_DIR/PKGBUILD"
sed -i "s/sha256sums=(.*)/sha256sums=('$CHECKSUM')/" "$AUR_TEST_DIR/PKGBUILD"

# Link the local tarball so makepkg can find it
ln -sf "$DIST_DIR/Zoidbot-Linux-x64.tar.gz" "$AUR_TEST_DIR/Zoidbot-Linux-x64.tar.gz"

# 5. Build and install the package
log_info "Running makepkg -si..."
cd "$AUR_TEST_DIR"

# Note: We use --noconfirm for automation.
# We also use a custom PROTOCOL handler or just tell makepkg it's local
# Actually, if the filename is in the source array and present in the dir, it works.
# But we need to remove the protocol to avoid it trying to download.
sed -i "s|source=(\"local://|source=(\"|" "$AUR_TEST_DIR/PKGBUILD"

makepkg -si --noconfirm

log_success "AUR package installed successfully!"
log_info "You can now run the app using: zoidbot"
