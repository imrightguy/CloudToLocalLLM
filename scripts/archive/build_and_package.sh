#!/bin/bash
set -e

# Function to get version from pubspec.yaml
get_version() {
    grep 'version:' pubspec.yaml | awk '{print $2}'
}

# Variables
VERSION=$(get_version)
DEB_VERSION=$(echo $VERSION | cut -d '+' -f 1)
BUILD_NUMBER=$(echo $VERSION | cut -d '+' -f 2)
PACKAGE_NAME="cloudtolocalllm_${DEB_VERSION}_amd64.deb"
BUILD_DIR="/tmp/cloudtolocalllm-deb-build"
OUTPUT_DIR="dist/linux/deb"
OUTPUT_PATH="$OUTPUT_DIR/$PACKAGE_NAME"

# Create output directory
mkdir -p $OUTPUT_DIR

# Create temporary build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Created build directory: $BUILD_DIR"

# Copy debian package structure
cp -r packaging/deb/* "$BUILD_DIR/"
echo "Copied debian package structure"

# Copy Flutter Linux build to package structure
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/lib/CloudToLocalLLM"

cp build/linux/x64/release/bundle/CloudToLocalLLM "$BUILD_DIR/usr/lib/CloudToLocalLLM/"
cp -r build/linux/x64/release/bundle/data "$BUILD_DIR/usr/lib/CloudToLocalLLM/"
cp -r build/linux/x64/release/bundle/lib "$BUILD_DIR/usr/lib/CloudToLocalLLM/"

# Create wrapper script
cat > "$BUILD_DIR/usr/bin/CloudToLocalLLM" << EOF
#!/bin/bash
cd /usr/lib/CloudToLocalLLM
exec ./CloudToLocalLLM "$@"
EOF

echo "Copied Flutter build files and created wrapper script"

# Copy icon
if [ -f "assets/icons/app_icon.png" ]; then
    cp "assets/icons/app_icon.png" "$BUILD_DIR/usr/share/pixmaps/CloudToLocalLLM.png"
    echo "Copied app icon"
elif [ -f "linux/CloudToLocalLLM.png" ]; then
    cp "linux/CloudToLocalLLM.png" "$BUILD_DIR/usr/share/pixmaps/CloudToLocalLLM.png"
    echo "Copied linux icon"
fi

# Update control file
INSTALLED_SIZE=$(du -sk "$BUILD_DIR" | cut -f1)
sed -i "s/Version: .*/Version: $DEB_VERSION/" "$BUILD_DIR/DEBIAN/control"
sed -i "s/Installed-Size: .*/Installed-Size: $INSTALLED_SIZE/" "$BUILD_DIR/DEBIAN/control"
echo "Updated control file with version $DEB_VERSION and size $INSTALLED_SIZE KB"

# Set permissions
chmod 755 "$BUILD_DIR/DEBIAN/postinst"
chmod 755 "$BUILD_DIR/DEBIAN/postrm"
chmod 755 "$BUILD_DIR/usr/bin/CloudToLocalLLM"
chmod 755 "$BUILD_DIR/usr/lib/CloudToLocalLLM/CloudToLocalLLM"
find "$BUILD_DIR/usr/lib/CloudToLocalLLM/data" -type f -exec chmod 644 {} \; 2>/dev/null || true
find "$BUILD_DIR/usr/lib/CloudToLocalLLM/data" -type d -exec chmod 755 {} \; 2>/dev/null || true
find "$BUILD_DIR/usr/lib/CloudToLocalLLM/lib" -type f -exec chmod 644 {} \; 2>/dev/null || true
find "$BUILD_DIR/usr/lib/CloudToLocalLLM/lib" -type d -exec chmod 755 {} \; 2>/dev/null || true
echo "Set correct permissions"

# Build the DEB package
dpkg-deb --build "$BUILD_DIR" "$OUTPUT_PATH"

# Verify the package
if [ -f "$OUTPUT_PATH" ]; then
    echo "DEB package created successfully: $PACKAGE_NAME"
    echo "Package size: $(du -h "$OUTPUT_PATH" | cut -f1)"
    echo "Package location: $OUTPUT_PATH"
    
    # Run lintian for package validation
    echo "Running lintian validation..."
    if lintian "$OUTPUT_PATH" 2>&1 | tee /tmp/lintian_output.txt; then
        echo "Lintian validation passed"
    else
        echo "Lintian validation found issues:"
        cat /tmp/lintian_output.txt
        echo "Package created but has lintian warnings/errors"
    fi
else
    echo "Failed to create DEB package"
    exit 1
fi

# Cleanup
rm -rf "$BUILD_DIR"
echo "Cleanup completed"
