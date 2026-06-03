#!/bin/bash

# CloudToLocalLLM Unified Package Build Script
# Builds all package formats with unified version management

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Version management functions
get_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-semantic
}

get_full_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get
}

get_build_number() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-build
}

# Increment version based on type
increment_version() {
    local increment_type="$1"
    log_info "Incrementing $increment_type version..."
    "$PROJECT_ROOT/scripts/version_manager.sh" increment "$increment_type"
}

# Validate version consistency across all packages
validate_version_consistency() {
    log_info "Validating version consistency across all packages..."
    
    local semantic_version=$(get_version)
    local full_version=$(get_full_version)
    local build_number=$(get_build_number)
    
    log_info "Semantic Version: $semantic_version"
    log_info "Full Version: $full_version"
    log_info "Build Number: $build_number"
    
    # Validate version format
    if ! "$PROJECT_ROOT/scripts/version_manager.sh" validate; then
        log_error "Version validation failed"
        exit 1
    fi
    
    log_success "Version validation passed"
}

# Update Flutter app configuration with current version
update_flutter_version() {
    log_info "Updating Flutter application version configuration..."
    
    local semantic_version=$(get_version)
    local build_number=$(get_build_number)
    
    # Update app_config.dart with current version
    local app_config_file="$PROJECT_ROOT/lib/config/app_config.dart"
    if [[ -f "$app_config_file" ]]; then
        sed -i "s/static const String appVersion = '[^']*';/static const String appVersion = '$semantic_version';/" "$app_config_file"
        log_success "Updated app_config.dart with version $semantic_version"
    fi
    
    # Create version.json asset for runtime version access
    local assets_dir="$PROJECT_ROOT/assets"
    mkdir -p "$assets_dir"
    
    cat > "$assets_dir/version.json" << EOFVERSION
{
  "version": "$semantic_version",
  "build_number": "$build_number",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
}
EOFVERSION
    
    log_success "Created version.json asset"
}

# Build Flutter Linux application
build_flutter_linux() {
    log_info "Building Flutter Linux application..."

    # Check if we're in WSL or need to use WSL
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "Linux build requires WSL or native Linux environment"
        return 1
    fi

    # Use WSL-native Flutter installation
    local flutter_cmd="/opt/flutter/bin/flutter"

    # Check if WSL-native Flutter is available
    if [[ ! -f "$flutter_cmd" ]]; then
        log_error "WSL-native Flutter not found at $flutter_cmd"
        log_error "Please install Flutter in WSL or use the PowerShell build scripts"
        return 1
    fi

    # Clean previous builds
    log_info "Cleaning previous Flutter builds..."
    "$flutter_cmd" clean

    # Get dependencies
    log_info "Getting Flutter dependencies..."
    "$flutter_cmd" pub get

    # Build Linux release
    log_info "Building Flutter Linux release..."
    if "$flutter_cmd" build linux --release; then
        log_success "Flutter Linux build completed"

        # Verify build artifacts
        if [[ -f "$PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" ]]; then
            log_success "Flutter Linux build artifacts verified"
        else
            log_error "Flutter Linux build artifacts not found"
            return 1
        fi
    else
        log_error "Flutter Linux build failed"
        return 1
    fi
}

# Build AppImage package
build_appimage() {
    log_info "Building AppImage package..."

    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_warning "Skipping AppImage build (Linux required)"
        return 0
    fi

    cd "$SCRIPT_DIR"
    if ./build_appimage.sh; then
        log_success "AppImage build completed"
    else
        log_error "AppImage build failed"
        return 1
    fi
}

# Build Debian package (DEPRECATED - Use AppImage instead)
build_debian() {
    log_warning "Debian package generation has been discontinued"
    log_info "Please use AppImage for universal Linux distribution compatibility"
    log_info "Run: ./scripts/packaging/build_appimage.sh"
    return 0
}



# Validate all generated packages
validate_packages() {
    log_info "Validating generated packages..."

    local version=$(get_version)
    local dist_dir="$PROJECT_ROOT/dist/linux"
    local validation_errors=0

    # Check Debian package
    if [[ -f "$dist_dir/CloudToLocalLLM_${version}_amd64.deb" ]]; then
        log_success "Debian package found: CloudToLocalLLM_${version}_amd64.deb"
        if [[ -f "$dist_dir/CloudToLocalLLM_${version}_amd64.deb.sha256" ]]; then
            log_success "Debian package checksum found"
        else
            log_error "Debian package checksum missing"
            ((validation_errors++))
        fi
    else
        log_warning "Debian package not found (may have been skipped)"
    fi

    # Check AppImage package
    if [[ -f "$dist_dir/cloudtolocalllm-${version}-x86_64.AppImage" ]]; then
        log_success "AppImage package found: CloudToLocalLLM-${version}-x86_64.AppImage"
        if [[ -f "$dist_dir/cloudtolocalllm-${version}-x86_64.AppImage.sha256" ]]; then
            log_success "AppImage package checksum found"
        else
            log_error "AppImage package checksum missing"
            ((validation_errors++))
        fi
    else
        log_warning "AppImage package not found (may have been skipped)"
    fi

    if [[ $validation_errors -gt 0 ]]; then
        log_error "Package validation failed with $validation_errors errors"
        return 1
    else
        log_success "All packages validated successfully"
        return 0
    fi
}

# Generate build summary
generate_summary() {
    log_info "Generating build summary..."

    local version=$(get_version)
    local full_version=$(get_full_version)
    local build_number=$(get_build_number)
    local dist_dir="$PROJECT_ROOT/dist/linux"

    echo
    echo "=== CloudToLocalLLM Build Summary ==="
    echo "Semantic Version: $version"
    echo "Full Version: $full_version"
    echo "Build Number: $build_number"
    echo "Build Date: $(date)"
    echo
    echo "Generated Packages:"

    # List all generated packages with sizes
    if [[ -f "$dist_dir/CloudToLocalLLM_${version}_amd64.deb" ]]; then
        local size=$(du -h "$dist_dir/CloudToLocalLLM_${version}_amd64.deb" | cut -f1)
        echo "  Debian: CloudToLocalLLM_${version}_amd64.deb ($size)"
    fi

    if [[ -f "$dist_dir/cloudtolocalllm-${version}-x86_64.AppImage" ]]; then
        local size=$(du -h "$dist_dir/cloudtolocalllm-${version}-x86_64.AppImage" | cut -f1)
        echo "  AppImage: CloudToLocalLLM-${version}-x86_64.AppImage ($size)"
    fi

    echo
    echo "Distribution Directory: $dist_dir"
    echo
}

# Main execution function
main() {
    local increment_type=""
    local skip_version_increment=false
    local packages_to_build="all"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --increment)
                increment_type="$2"
                shift 2
                ;;
            --skip-increment)
                skip_version_increment=true
                shift
                ;;
            --packages)
                packages_to_build="$2"
                shift 2
                ;;
            --help|-h)
                echo "CloudToLocalLLM Unified Package Build Script"
                echo
                echo "Usage: $0 [options]"
                echo
                echo "Options:"
                echo "  --increment <type>    Increment version (major|minor|patch)"
                echo "  --skip-increment      Skip version increment"
                echo "  --packages <list>     Build specific packages (all|debian|appimage)"
                echo "  --help, -h           Show this help message"
                echo
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting CloudToLocalLLM unified package build..."
    
    # Increment version if requested
    if [[ -n "$increment_type" ]] && [[ "$skip_version_increment" == false ]]; then
        increment_version "$increment_type"
    fi
    
    # Validate version consistency
    validate_version_consistency
    
    # Update Flutter version configuration
    update_flutter_version

    # Build Flutter Linux application first
    build_flutter_linux || exit 1

    # Build packages based on selection
    local build_errors=0

    case "$packages_to_build" in
        "all")
            build_appimage || ((build_errors++))
            ;;
        "debian")
            log_warning "Debian package generation has been discontinued"
            log_info "Building AppImage instead for universal Linux compatibility"
            build_appimage || ((build_errors++))
            ;;
        "appimage")
            build_appimage || ((build_errors++))
            ;;
        *)
            log_error "Invalid package selection: $packages_to_build"
            log_error "Supported options: all, appimage (debian redirects to appimage)"
            exit 1
            ;;
    esac
    
    # Validate generated packages
    if ! validate_packages; then
        ((build_errors++))
    fi
    
    # Generate summary
    generate_summary
    
    # Final status
    if [[ $build_errors -eq 0 ]]; then
        log_success "All package builds completed successfully!"
        exit 0
    else
        log_error "Package build completed with $build_errors errors"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
