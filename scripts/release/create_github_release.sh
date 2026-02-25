#!/bin/bash

# CloudToLocalLLM GitHub Release Creator
# Creates GitHub releases with binary artifacts for AUR distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_OWNER="imrightguy"
REPO_NAME="CloudToLocalLLM"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get version from pubspec.yaml
get_version() {
    if [[ -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1
    else
        print_error "pubspec.yaml not found"
        exit 1
    fi
}

# Check if GitHub CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_error "Install with: sudo apt install gh"
        exit 1
    fi

    # Skip authentication check since SSH authentication is already working
    print_status "Using existing SSH authentication for GitHub operations"
}

# Build Windows packages
build_windows_packages() {
    local version="$1"
    print_status "Building Windows packages..."
    powershell.exe -ExecutionPolicy Bypass -File "$PROJECT_ROOT/scripts/powershell/Build-GitHubReleaseAssets.ps1" -InstallInnoSetup
    if [[ $? -ne 0 ]]; then
        print_error "Failed to build Windows packages."
        exit 1
    fi
    print_success "Windows packages built successfully."
}

# Build Linux packages in WSL
# Check if release already exists

# Check if release already exists
check_existing_release() {
    local version="$1"
    local tag="v$version"
    local force_recreate="${2:-false}"

    if gh release view "$tag" --repo "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        if [[ "$force_recreate" == "true" ]]; then
            print_warning "Release $tag already exists - recreating due to force flag"
            print_status "Deleting existing release $tag..."
            gh release delete "$tag" --repo "$REPO_OWNER/$REPO_NAME" --yes
            git tag -d "$tag" 2>/dev/null || true
            git push origin --delete "$tag" 2>/dev/null || true
        else
            print_error "Release $tag already exists"
            print_error "Use --force to recreate the release"
            exit 1
        fi
    fi
}

# Verify packages from Phase 3 builds
verify_packages() {
    local version="$1"
    local missing_packages=()

    print_status "Verifying Phase 3 build packages for version $version..."

    # Check Windows packages
    if [[ ! -f "$PROJECT_ROOT/dist/windows/cloudtolocalllm-$version-portable.zip" ]]; then
        missing_packages+=("Windows portable ZIP")
    fi

    if [[ ! -f "$PROJECT_ROOT/dist/windows/CloudToLocalLLM-Windows-$version-Setup.exe" ]]; then
        missing_packages+=("Windows installer")
    fi

    # Check Linux packages
    if [[ ! -f "$PROJECT_ROOT/dist/linux/cloudtolocalllm-$version-amd64.deb" ]]; then
        missing_packages+=("Linux .deb package")
    fi

    if [[ ! -f "$PROJECT_ROOT/dist/linux/cloudtolocalllm-$version-x86_64.AppImage" ]]; then
        missing_packages+=("Linux AppImage")
    fi

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_error "Missing packages from Phase 3 builds:"
        for package in "${missing_packages[@]}"; do
            print_error "  - $package"
        done
        print_error "Please run Phase 3 (Multi-Platform Build) first"
        exit 1
    fi

    print_success "All Phase 3 packages verified and ready for release"
}

# Generate release notes
generate_release_notes() {
    local version="$1"
    local notes_file="/tmp/release_notes_$version.md"
    
    cat > "$notes_file" << EOF
# CloudToLocalLLM v$version

## 🚀 New Features & Improvements

### Enhanced Architecture
- **Unified Flutter application** with integrated system tray functionality
- **Improved deployment workflow** with GitHub releases as primary distribution
- **Streamlined AUR package** with automated GitHub release downloads
- **Enhanced build pipeline** with automated version management

### System Integration
- **Python-based system tray daemon** for improved Linux compatibility
- **TCP socket IPC** communication between components
- **Authentication-aware menus** with dynamic state updates
- **Cross-platform compatibility** improvements

### Security & Performance
- **Non-root container architecture** with proper privilege dropping
- **Enhanced authentication flow** with JWT PKCE support
- **Improved error handling** and logging
- **Memory optimization** and resource management

### User Interface
- **Material Design 3 compliance** with comprehensive dark theme
- **Production-quality interface** matching homepage design
- **ChatGPT-like chat interface** for improved user experience
- **Responsive design** with mobile-first breakpoints

## 📦 Installation

### Linux (AUR Package)
\`\`\`bash
# Install from AUR (recommended)
yay -S CloudToLocalLLM

# Or build manually
git clone https://aur.archlinux.org/CloudToLocalLLM.git
cd CloudToLocalLLM
makepkg -si
\`\`\`

### Manual Installation
1. Download the binary package: \`CloudToLocalLLM-$version-x86_64.tar.gz\`
2. Verify integrity: \`sha256sum -c CloudToLocalLLM-$version-x86_64.tar.gz.sha256\`
3. Extract and install according to included instructions

### System Requirements
- **Linux**: Ubuntu 20.04+, Debian 11+, Arch Linux, or compatible
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 2GB available space
- **Network**: Internet connection for cloud features

## 🔗 Links

- **Homepage**: https://cloudtolocalllm.online
- **Web App**: https://app.cloudtolocalllm.online
- **Documentation**: https://github.com/$REPO_OWNER/$REPO_NAME/wiki
- **Issues**: https://github.com/$REPO_OWNER/$REPO_NAME/issues

## 🙏 Acknowledgments

Thanks to the community for feedback and contributions that made this release possible.

---

**Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/v3.0.3...v$version
EOF

    echo "$notes_file"
}

# Create GitHub release
create_release() {
    local version="$1"
    local tag="v$version"
    local notes_file=$(generate_release_notes "$version")

    print_status "Creating GitHub release $tag..."

    # Create and push tag (handle existing tags)
    print_status "Creating and pushing tag $tag..."
    if git tag -l | grep -q "^$tag$"; then
        print_warning "Tag $tag already exists locally"
        if [[ "$FORCE_RECREATE" == "true" ]]; then
            print_status "Deleting existing local tag due to force flag"
            git tag -d "$tag"
            git tag -a "$tag" -m "CloudToLocalLLM v$version"
        fi
    else
        git tag -a "$tag" -m "CloudToLocalLLM v$version"
    fi

    # Push tag (force push if recreating)
    if [[ "$FORCE_RECREATE" == "true" ]]; then
        git push origin "$tag" --force
    else
        git push origin "$tag"
    fi

    # Collect all release assets from Phase 3 builds
    local assets=()

    # Windows packages
    if [[ -f "$PROJECT_ROOT/dist/windows/cloudtolocalllm-$version-portable.zip" ]]; then
        assets+=("$PROJECT_ROOT/dist/windows/cloudtolocalllm-$version-portable.zip")
        assets+=("$PROJECT_ROOT/dist/windows/cloudtolocalllm-$version-portable.zip.sha256")
    fi

    if [[ -f "$PROJECT_ROOT/dist/windows/CloudToLocalLLM-Windows-$version-Setup.exe" ]]; then
        assets+=("$PROJECT_ROOT/dist/windows/CloudToLocalLLM-Windows-$version-Setup.exe")
        assets+=("$PROJECT_ROOT/dist/windows/CloudToLocalLLM-Windows-$version-Setup.exe.sha256")
    fi

    # Linux packages
    if [[ -f "$PROJECT_ROOT/dist/linux/cloudtolocalllm_${version}_amd64.deb" ]]; then
        assets+=("$PROJECT_ROOT/dist/linux/cloudtolocalllm_${version}_amd64.deb")
        assets+=("$PROJECT_ROOT/dist/linux/cloudtolocalllm_${version}_amd64.deb.sha256")
    fi

    if [[ -f "$PROJECT_ROOT/dist/linux/cloudtolocalllm-$version-x86_64.AppImage" ]]; then
        assets+=("$PROJECT_ROOT/dist/linux/cloudtolocalllm-$version-x86_64.AppImage")
        assets+=("$PROJECT_ROOT/dist/linux/cloudtolocalllm-$version-x86_64.AppImage.sha256")
    fi

    # Create release with multi-platform assets
    print_status "Creating GitHub release with multi-platform assets..."
    gh release create "$tag" \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --title "CloudToLocalLLM v$version" \
        --notes-file "$notes_file" \
        "${assets[@]}"

    print_success "GitHub release created successfully!"
    print_success "Release URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$tag"
    print_status "Uploaded ${#assets[@]} assets to the release"

    # Clean up
    rm -f "$notes_file"
}

# Parse command line arguments
parse_arguments() {
    FORCE_RECREATE="false"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_RECREATE="true"
                shift
                ;;
            --help|-h)
                echo "CloudToLocalLLM GitHub Release Creator"
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force     Recreate release if it already exists"
                echo "  --help, -h  Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"

    print_status "CloudToLocalLLM GitHub Release Creator"
    print_status "======================================"

    # Change to project root
    cd "$PROJECT_ROOT"

    # Check prerequisites
    check_gh_cli

    # Get version
    local version=$(get_version)
    print_status "Current version: $version"

    # Check for existing release
    check_existing_release "$version" "$FORCE_RECREATE"

    # Verify packages from Phase 3 builds
    verify_packages "$version"

    # Create GitHub release
    create_release "$version"

    print_success "GitHub release creation completed!"
    print_status "Next steps:"
    print_status "1. Proceed to Phase 5: VPS Deployment"
    print_status "2. Verify release functionality"
    print_status "3. Update documentation if needed"
}

# Execute main function
main "$@"
