#!/bin/bash
# Build and install CloudToLocalLLM AppImage locally

set -e

PROJECT_DIR="/mnt/data/projects/CloudToLocalLLM"
BUILD_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
APPIMAGE_DIR="/tmp/appimage-build"
APPIMAGE_OUTPUT="/tmp/CloudToLocalLLM-x86_64.AppImage"

echo "🚀 Building CloudToLocalLLM AppImage..."

# Step 1: Build Flutter Linux release
echo "📦 Building Flutter Linux release..."
cd "$PROJECT_DIR"
flutter build linux --release

# Step 2: Download AppImage tools if not present
mkdir -p "$APPIMAGE_DIR"
cd "$APPIMAGE_DIR"

if [ ! -f linuxdeploy-x86_64.AppImage ]; then
    echo "⬇️ Downloading linuxdeploy..."
    wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
    chmod +x linuxdeploy-x86_64.AppImage
fi

if [ ! -f appimagetool-x86_64.AppImage ]; then
    echo "⬇️ Downloading appimagetool..."
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# Step 3: Prepare AppImage structure
echo "📁 Preparing AppImage structure..."
rm -rf "$APPIMAGE_DIR/AppDir"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/bin"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/lib"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/share/applications"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/share/metainfo"

# Copy bundle contents
cp -r "$BUILD_DIR"/* "$APPIMAGE_DIR/AppDir/usr/bin/"

# Create AppRun
cat > "$APPIMAGE_DIR/AppDir/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/cloudtolocalllm" "$@"
EOF
chmod +x "$APPIMAGE_DIR/AppDir/AppRun"

# Copy desktop file
cp "$PROJECT_DIR/assets/linux/cloudtolocalllm.desktop" "$APPIMAGE_DIR/AppDir/usr/share/applications/"
cp "$PROJECT_DIR/assets/linux/cloudtolocalllm.desktop" "$APPIMAGE_DIR/AppDir/"

# Copy icon if exists, otherwise use placeholder
if [ -f "$PROJECT_DIR/assets/icon/icon.png" ]; then
    cp "$PROJECT_DIR/assets/icon/icon.png" "$APPIMAGE_DIR/AppDir/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png"
    cp "$PROJECT_DIR/assets/icon/icon.png" "$APPIMAGE_DIR/AppDir/cloudtolocalllm.png"
else
    echo "⚠️ Icon not found, AppImage will use default"
fi

# Step 4: Fix AppDir structure for appimagetool
echo "🔨 Preparing AppDir for appimagetool..."
cd "$APPIMAGE_DIR"

# desktop file needs to be at root of AppDir
cp AppDir/usr/share/applications/cloudtolocalllm.desktop AppDir/

# Copy icon if exists
if [ -f AppDir/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png ]; then
    cp AppDir/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png AppDir/cloudtolocalllm.png
fi

# Step 5: Build AppImage using appimagetool
echo "🔨 Building AppImage with appimagetool..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage AppDir "$APPIMAGE_OUTPUT" --no-appstream

# Step 6: Install locally
echo "💿 Installing AppImage..."
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"
cp "$APPIMAGE_OUTPUT" "$INSTALL_DIR/cloudtolocalllm"
chmod +x "$INSTALL_DIR/cloudtolocalllm"

# Create desktop entry for AppImage
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/cloudtolocalllm-appimage.desktop" << EOF
[Desktop Entry]
Name=CloudToLocalLLM
Exec=$INSTALL_DIR/cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Hybrid LLM workspace and Agent Dashboard
Terminal=false
EOF

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo ""
echo "✅ AppImage built and installed successfully!"
echo ""
echo "📍 Location: $INSTALL_DIR/cloudtolocalllm"
echo "📍 AppImage: $APPIMAGE_OUTPUT"
echo ""
echo "🚀 Launch with: cloudtolocalllm"
echo "🚀 Or run: $APPIMAGE_OUTPUT"
