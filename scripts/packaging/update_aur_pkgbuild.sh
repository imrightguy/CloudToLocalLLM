#!/bin/bash

# CloudToLocalLLM AUR PKGBUILD Update Script
# Updates PKGBUILD with current version and checksum for AppImage

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PKGBUILD_TEMPLATE="$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD"
AUR_OUTPUT_DIR="$PROJECT_ROOT/dist/aur"
VERSION="${AUR_VERSION_OVERRIDE:-$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)}"

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

# Calculate checksum from explicit override first, then local AppImage if present
APPIMAGE="$PROJECT_ROOT/dist/linux/cloudtolocalllm-${VERSION}-x86_64.AppImage"
CHECKSUM="${AUR_APPIMAGE_SHA256:-}"
if [ -n "$CHECKSUM" ]; then
    print_status "Using provided AppImage checksum from AUR_APPIMAGE_SHA256..."
    sed -i "s/sha256sums=('SKIP')/sha256sums=('$CHECKSUM')/" "$AUR_OUTPUT_DIR/PKGBUILD"
    print_success "Updated PKGBUILD with provided checksum: $CHECKSUM"
elif [ -f "$APPIMAGE" ]; then
    print_status "Calculating checksum for $APPIMAGE..."
    CHECKSUM=$(sha256sum "$APPIMAGE" | cut -d' ' -f1)
    sed -i "s/sha256sums=('SKIP')/sha256sums=('$CHECKSUM')/" "$AUR_OUTPUT_DIR/PKGBUILD"
    print_success "Updated PKGBUILD with local checksum: $CHECKSUM"
else
    print_status "AppImage not found locally ($APPIMAGE), PKGBUILD will use SKIP for checksums"
fi

# Generate .SRCINFO
if command -v makepkg &> /dev/null; then
    print_status "Generating .SRCINFO with makepkg..."
    cd "$AUR_OUTPUT_DIR"
    makepkg --printsrcinfo > .SRCINFO
    print_success ".SRCINFO generated"
else
    print_status "makepkg not found, generating .SRCINFO with fallback parser..."
    python3 - "$AUR_OUTPUT_DIR/PKGBUILD" "$AUR_OUTPUT_DIR/.SRCINFO" <<'PY'
import re
import sys
from pathlib import Path

pkgbuild_path = Path(sys.argv[1])
srcinfo_path = Path(sys.argv[2])
text = pkgbuild_path.read_text()

def scalar(name: str) -> str:
    m = re.search(rf'^{name}=(.+)$', text, re.M)
    if not m:
        raise SystemExit(f'missing field: {name}')
    value = m.group(1).strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        value = value[1:-1]
    return value

def array(name: str) -> list[str]:
    m = re.search(rf'^{name}=\((.*?)\)$', text, re.M)
    if not m:
        return []
    vals = re.findall(r'"([^"]*)"|\'([^\']*)\'', m.group(1))
    return [a or b for a, b in vals]

pkgname = scalar('pkgname')
pkgver = scalar('pkgver')
pkgrel = scalar('pkgrel')
pkgdesc = scalar('pkgdesc')
url = scalar('url')
arch = array('arch')
licenses = array('license')
depends = array('depends')
provides = array('provides')
conflicts = array('conflicts')
options = array('options')
sha256sums = array('sha256sums')
appimage = f'{pkgname}-{pkgver}-x86_64.AppImage'
source = f'{appimage}::{url}/releases/download/v{pkgver}/{appimage}'

lines = [
    f'pkgbase = {pkgname}',
    f'\tpkgdesc = {pkgdesc}',
    f'\tpkgver = {pkgver}',
    f'\tpkgrel = {pkgrel}',
    f'\turl = {url}',
]
for item in arch:
    lines.append(f'\tarch = {item}')
for item in licenses:
    lines.append(f'\tlicense = {item}')
for item in depends:
    lines.append(f'\tdepends = {item}')
for item in provides:
    lines.append(f'\tprovides = {item}')
for item in conflicts:
    lines.append(f'\tconflicts = {item}')
for item in options:
    lines.append(f'\toptions = {item}')
lines.append(f'\tsource = {source}')
for item in sha256sums:
    lines.append(f'\tsha256sums = {item}')
lines.extend(['', f'pkgname = {pkgname}', ''])
srcinfo_path.write_text('\n'.join(lines))
PY
    print_success ".SRCINFO generated with fallback parser"
fi

print_success "AUR package files prepared in $AUR_OUTPUT_DIR"
