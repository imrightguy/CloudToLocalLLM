#!/bin/bash

# CloudToLocalLLM Debian Package Build Script
# Packages the Flutter Linux bundle into a .deb file

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
PACKAGE_NAME="CloudToLocalLLM"
MAINTAINER="CloudToLocalLLM Team <team@cloudtolocalllm.online>"
DESCRIPTION="Manage and run powerful Large Language Models locally, orchestrated via a cloud interface."

# Output Directory
DIST_DIR="$PROJECT_ROOT/dist/linux"
mkdir -p "$DIST_DIR"

# Temporary packaging directory
PKG_ROOT=$(mktemp -d)
echo "Packaging in $PKG_ROOT"

# Create directory structure
mkdir -p "$PKG_ROOT/usr/bin"
mkdir -p "$PKG_ROOT/usr/lib/$PACKAGE_NAME"
mkdir -p "$PKG_ROOT/usr/share/applications"
mkdir -p "$PKG_ROOT/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$PKG_ROOT/DEBIAN"

# Copy bundle files
cp -r "$BUILD_DIR/"* "$PKG_ROOT/usr/lib/$PACKAGE_NAME/"

# Create executable wrapper
cat > "$PKG_ROOT/usr/bin/$PACKAGE_NAME" << EOF
#!/bin/bash
/usr/lib/$PACKAGE_NAME/$PACKAGE_NAME "\$@"
EOF
chmod +x "$PKG_ROOT/usr/bin/$PACKAGE_NAME"

# Create desktop entry
cat > "$PKG_ROOT/usr/share/applications/$PACKAGE_NAME.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CloudToLocalLLM
GenericName=AI Model Bridge
Comment=$DESCRIPTION
Icon=$PACKAGE_NAME
Exec=$PACKAGE_NAME %u
Terminal=false
Categories=Development;Utility;Network;
Keywords=AI;LLM;Ollama;OpenAI;Machine Learning;
StartupNotify=true
StartupWMClass=CloudToLocalLLM
MimeType=x-scheme-handler/$PACKAGE_NAME;
EOF

# Copy icon
if [ -f "$PROJECT_ROOT/linux/icons/zoidbot-128.png" ]; then
    cp "$PROJECT_ROOT/linux/icons/zoidbot-128.png" "$PKG_ROOT/usr/share/icons/hicolor/128x128/apps/$PACKAGE_NAME.png"
fi

# Create control file
cat > "$PKG_ROOT/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Architecture: amd64
Maintainer: $MAINTAINER
Depends: libgtk-3-0, libglib2.0-0, libayatana-appindicator3-1, liblzma5, libsecret-1-0, libcurl4, wmctrl
Section: utils
Priority: optional
Description: $DESCRIPTION
EOF

# Build package
dpkg-deb --build "$PKG_ROOT" "$DIST_DIR/${PACKAGE_NAME}_${VERSION}_amd64.deb"

# Cleanup
rm -rf "$PKG_ROOT"

echo "Debian package created: $DIST_DIR/${PACKAGE_NAME}_${VERSION}_amd64.deb"
