#!/bin/bash

# CloudToLocalLLM AUR PKGBUILD Update Script
# Updates PKGBUILD with current version and checksum for AppImage

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PKGBUILD_TEMPLATE="$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD"
AUR_OUTPUT_DIR="$PROJECT_ROOT/dist/aur"
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
GITHUB_REPO="chokesmaster/CloudToLocalLLM"

# Functions
print_status() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# Main
print_status "Updating PKGBUILD for version $VERSION..."
mkdir -p "$AUR_OUTPUT_DIR"

if [ ! -f "$PKGBUILD_TEMPLATE" ]; then
    print_error "PKGBUILD template not found at $PKGBUILD_TEMPLATE"
    exit 1
fi

cp "$PKGBUILD_TEMPLATE" "$AUR_OUTPUT_DIR/PKGBUILD"

# Update version
sed -i "s/pkgver=VERSION/pkgver=$VERSION/" "$AUR_OUTPUT_DIR/PKGBUILD"

# Calculate checksum if AppImage exists locally
APPIMAGE="$PROJECT_ROOT/dist/linux/cloudtolocalllm-${VERSION}-x86_64.AppImage"
if [ -f "$APPIMAGE" ]; then
    print_status "Calculating checksum for $APPIMAGE..."
    CHECKSUM=$(sha256sum "$APPIMAGE" | cut -d' ' -f1)
    sed -i "s/sha256sums=('SKIP')/sha256sums=('$CHECKSUM')/" "$AUR_OUTPUT_DIR/PKGBUILD"
    print_success "Updated PKGBUILD with local checksum: $CHECKSUM"
else
    print_status "AppImage not found locally ($APPIMAGE), PKGBUILD will use SKIP for checksums"
fi

# Generate .SRCINFO if makepkg is available
if command -v makepkg &> /dev/null; then
    print_status "Generating .SRCINFO..."
    cd "$AUR_OUTPUT_DIR"
    makepkg --printsrcinfo > .SRCINFO
    print_success ".SRCINFO generated"
else
    print_status "makepkg not found, skipping .SRCINFO generation"
fi

print_success "AUR package files prepared in $AUR_OUTPUT_DIR"
