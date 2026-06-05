#!/bin/bash
set -euo pipefail

# CloudToLocalLLM Flatpak Builder
# Builds a Flatpak from the Flutter Linux release bundle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
FLATPAK_DIR="$PROJECT_ROOT/flatpak"
DIST_DIR="$PROJECT_ROOT/dist/flatpak"
BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"

mkdir -p "$DIST_DIR"

if [ ! -f "$BUNDLE_DIR/cloudtolocalllm" ]; then
    echo "ERROR: Linux release bundle not found. Run 'flutter build linux --release' first."
    exit 1
fi

# Check flatpak-builder
if ! command -v flatpak-builder &>/dev/null; then
    echo "ERROR: flatpak-builder not found. Install it first."
    echo "  sudo pacman -S flatpak-builder"
    echo "  flatpak remote-add --user flathub https://flathub.org/repo/flathub.flatpakrepo"
    echo "  flatpak install --user flathub org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08"
    echo ""
    echo "Or on Ubuntu/Debian:"
    echo "  sudo apt install flatpak flatpak-builder"
    exit 1
fi

# Update metainfo with version
sed -i "s/release version=\".*\"/release version=\"$VERSION\"/" "$FLATPAK_DIR/online.cloudtolocalllm.app.metainfo.xml"

echo "Building Flatpak for CloudToLocalLLM v$VERSION..."

flatpak-builder \
    --user \
    --install-deps-from=flathub \
    --force-clean \
    "$DIST_DIR/build-dir" \
    "$FLATPAK_DIR/online.cloudtolocalllm.app.yml" 2>&1

echo "Bundling Flatpak..."

flatpak build-bundle \
    "$DIST_DIR/build-dir" \
    "$DIST_DIR/cloudtolocalllm-$VERSION-x86_64.flatpak" \
    online.cloudtolocalllm.app \
    "$VERSION" 2>&1

echo "Done: $DIST_DIR/cloudtolocalllm-$VERSION-x86_64.flatpak"