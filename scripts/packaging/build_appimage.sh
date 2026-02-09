#!/bin/bash
set -e

# CloudToLocalLLM AppImage Package Builder
# Builds AppImage packages for Linux distribution
# Version: 1.0.0

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [APPIMAGE-BUILD]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [APPIMAGE-BUILD]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [APPIMAGE-BUILD]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [APPIMAGE-BUILD]${NC} $1"
}

# Function to get version from pubspec.yaml
get_version() {
    grep 'version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | cut -d '+' -f 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for AppImage package build..."
    
    # Check if we're in the project root
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        log_error "pubspec.yaml not found. Please run from project root."
        exit 1
    fi
    
    # Check if Flutter Linux build exists
    if [[ ! -f "$PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" ]]; then
        log_error "Flutter Linux build not found. Please run 'flutter build linux --release' first."
        log_error "Expected: $PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm"
        exit 1
    fi
    
    # Check for appimagetool
    if ! command -v appimagetool &> /dev/null; then
        log_warning "appimagetool not found. Attempting to download..."
        download_appimagetool
    fi
    
    log_success "All prerequisites satisfied"
}

# Download appimagetool if not available
download_appimagetool() {
    log_info "Downloading appimagetool..."
    
    local appimagetool_url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    local appimagetool_path="/tmp/appimagetool"
    
    if curl -L "$appimagetool_url" -o "$appimagetool_path"; then
        chmod +x "$appimagetool_path"
        # Create a wrapper script in PATH
        sudo ln -sf "$appimagetool_path" /usr/local/bin/appimagetool 2>/dev/null || {
            log_warning "Could not install appimagetool to /usr/local/bin, using temporary location"
            export PATH="/tmp:$PATH"
        }
        log_success "Downloaded appimagetool successfully"
    else
        log_error "Failed to download appimagetool"
        exit 1
    fi
}

# Variables
VERSION=$(get_version)
PACKAGE_NAME="cloudtolocalllm-${VERSION}-x86_64.AppImage"
BUILD_DIR="/tmp/cloudtolocalllm-appimage-build"
OUTPUT_DIR="$PROJECT_ROOT/dist/linux"
OUTPUT_PATH="$OUTPUT_DIR/$PACKAGE_NAME"

# Create build environment
create_build_environment() {
    log_info "Creating build environment..."
    
    mkdir -p "$OUTPUT_DIR"
    
    # Create temporary build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    log_success "Created build directory: $BUILD_DIR"
}

# Copy AppImage structure and Flutter build
copy_appimage_files() {
    log_info "Copying AppImage structure..."
    
    # Create AppDir if missing
    if [[ ! -d "$PROJECT_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir" ]]; then
        log_warning "AppDir template missing, creating basic structure..."
        mkdir -p "$BUILD_DIR/CloudToLocalLLM.AppDir/usr/bin"
        mkdir -p "$BUILD_DIR/CloudToLocalLLM.AppDir/usr/share/applications"
        mkdir -p "$BUILD_DIR/CloudToLocalLLM.AppDir/usr/share/icons/hicolor/128x128/apps"
        
        # Create a basic desktop file if template missing
        cat > "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm.desktop" << EOF
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Utility;
EOF
    else
        # Copy AppImage directory structure
        cp -r "$PROJECT_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir" "$BUILD_DIR/"
    fi
    log_success "Copied AppImage structure"
    
    log_info "Copying Flutter Linux build artifacts..."
    
    # Copy Flutter Linux build to AppImage structure
    cp "$PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" "$BUILD_DIR/CloudToLocalLLM.AppDir/"
    cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/data" "$BUILD_DIR/CloudToLocalLLM.AppDir/"
    cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/lib" "$BUILD_DIR/CloudToLocalLLM.AppDir/"
    
    log_success "Copied Flutter build files"
}

# Update AppImage metadata
update_appimage_metadata() {
    log_info "Updating AppImage metadata..."

    # Remove Version line from desktop file (it's optional and causes validation issues)
    sed -i '/^Version=/d' "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm.desktop"

    # Update AppRun script to use current Flutter build structure
    cat > "$BUILD_DIR/CloudToLocalLLM.AppDir/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
cd "${HERE}"
exec ./cloudtolocalllm "$@"
EOF

    log_success "Updated AppImage metadata"
}

# Copy additional assets
copy_assets() {
    log_info "Copying application assets..."
    
    # Copy icon if available
    if [[ -f "$PROJECT_ROOT/assets/images/app_icon.png" ]]; then
        cp "$PROJECT_ROOT/assets/images/app_icon.png" "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm.png"
        log_success "Updated app icon from assets/images/"
    elif [[ -f "$PROJECT_ROOT/assets/images/icon.png" ]]; then
        cp "$PROJECT_ROOT/assets/icons/app_icon.png" "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm.png"
        log_success "Updated app icon from assets/icons/"
    else
        log_warning "Using existing icon from AppImage structure"
    fi
}

# Set file permissions
set_permissions() {
    log_info "Setting file permissions..."
    
    # Set executable permissions
    chmod +x "$BUILD_DIR/CloudToLocalLLM.AppDir/AppRun"
    chmod +x "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm"
    
    # Set data and lib permissions
    find "$BUILD_DIR/CloudToLocalLLM.AppDir/data" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$BUILD_DIR/CloudToLocalLLM.AppDir/data" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$BUILD_DIR/CloudToLocalLLM.AppDir/lib" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$BUILD_DIR/CloudToLocalLLM.AppDir/lib" -type d -exec chmod 755 {} \; 2>/dev/null || true
    
    # Set desktop file permissions
    chmod 644 "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm.desktop"
    chmod 644 "$BUILD_DIR/CloudToLocalLLM.AppDir/cloudtolocalllm.png"
    
    log_success "Set correct permissions"
}

# Build the AppImage package
build_appimage_package() {
    log_info "Building AppImage package..."
    
    cd "$BUILD_DIR"
    
    # Build the AppImage
    if appimagetool CloudToLocalLLM.AppDir "$OUTPUT_PATH"; then
        log_success "AppImage package built successfully"
    else
        log_error "Failed to build AppImage package"
        exit 1
    fi
}

# Generate checksums
generate_checksums() {
    log_info "Generating SHA256 checksum..."
    
    cd "$OUTPUT_DIR"
    sha256sum "$(basename "$OUTPUT_PATH")" > "$(basename "$OUTPUT_PATH").sha256"
    
    log_success "Generated SHA256 checksum: $(basename "$OUTPUT_PATH").sha256"
}

# Validate the package
validate_package() {
    log_info "Validating AppImage package..."
    
    if [[ -f "$OUTPUT_PATH" ]]; then
        local package_size=$(du -h "$OUTPUT_PATH" | cut -f1)
        log_success "AppImage package created successfully: $(basename "$OUTPUT_PATH")"
        log_info "Package size: $package_size"
        log_info "Package location: $OUTPUT_PATH"
        
        # Test if AppImage is executable
        if [[ -x "$OUTPUT_PATH" ]]; then
            log_success "AppImage is executable"
        else
            log_warning "AppImage may not be executable"
        fi
    else
        log_error "Failed to create AppImage package"
        exit 1
    fi
}

# Cleanup build artifacts
cleanup_build() {
    log_info "Cleaning up build artifacts..."
    
    rm -rf "$BUILD_DIR"
    
    log_success "Cleanup completed"
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM AppImage package build..."
    log_info "Version: $VERSION"
    log_info "Package: $PACKAGE_NAME"
    
    check_prerequisites
    create_build_environment
    copy_appimage_files
    update_appimage_metadata
    copy_assets
    set_permissions
    build_appimage_package
    generate_checksums
    validate_package
    cleanup_build
    
    log_success "AppImage package build completed successfully!"
    log_info "Package: $OUTPUT_PATH"
    log_info "Checksum: $OUTPUT_PATH.sha256"
}

# Execute main function
main "$@"
