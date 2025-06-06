#!/bin/bash
# Build script for CloudToLocalLLM Enhanced Tray Daemon
# Builds the enhanced tray daemon with universal connection management

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
TRAY_DAEMON_DIR="$PROJECT_ROOT/tray_daemon"
BUILD_DIR="$PROJECT_ROOT/build/tray_daemon"
DIST_DIR="$PROJECT_ROOT/dist/tray_daemon"

# Platform detection
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac

echo -e "${BLUE}CloudToLocalLLM Enhanced Tray Daemon Build Script${NC}"
echo -e "${BLUE}===============================================${NC}"
echo "Platform: $PLATFORM-$ARCH"
echo "Project Root: $PROJECT_ROOT"
echo "Tray Daemon Dir: $TRAY_DAEMON_DIR"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Python is available
check_python() {
    print_status "Checking Python installation..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python not found. Please install Python 3.7 or later."
        exit 1
    fi
    
    # Check Python version
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    print_status "Found Python $PYTHON_VERSION"
    
    # Check if version is 3.7+
    if ! $PYTHON_CMD -c "import sys; exit(0 if sys.version_info >= (3, 7) else 1)" 2>/dev/null; then
        print_error "Python 3.7 or later is required. Found: $PYTHON_VERSION"
        exit 1
    fi
}

# Check if pip is available
check_pip() {
    print_status "Checking pip installation..."
    
    if ! $PYTHON_CMD -m pip --version &> /dev/null; then
        print_error "pip not found. Please install pip."
        exit 1
    fi
    
    print_status "pip is available"
}

# Install Python dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    
    cd "$TRAY_DAEMON_DIR"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        $PYTHON_CMD -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install requirements
    pip install -r requirements.txt
    pip install pyinstaller

    # Install additional dependencies for enhanced daemon
    pip install aiohttp requests
    
    print_status "Dependencies installed successfully"
}

# Build the daemon executable
build_daemon() {
    print_status "Building tray daemon executable..."
    
    cd "$TRAY_DAEMON_DIR"
    source venv/bin/activate
    
    # Create output directory
    mkdir -p "$DIST_DIR/$PLATFORM-$ARCH"
    
    # Executable name
    EXE_NAME="cloudtolocalllm-enhanced-tray"
    
    # PyInstaller arguments with size optimization
    PYINSTALLER_ARGS=(
        "--onefile"
        "--name" "$EXE_NAME"
        "--distpath" "$DIST_DIR/$PLATFORM-$ARCH"
        "--workpath" "$BUILD_DIR"
        "--specpath" "$BUILD_DIR"
        "--clean"
        "--strip"
        "--optimize" "2"
        "--exclude-module" "tkinter"
        "--exclude-module" "matplotlib"
        "--exclude-module" "numpy"
        "--exclude-module" "scipy"
        "--exclude-module" "pandas"
        "--exclude-module" "jupyter"
        "--exclude-module" "IPython"
        "--exclude-module" "test"
        "--exclude-module" "unittest"
        "--exclude-module" "doctest"
        "--exclude-module" "pdb"
        "--exclude-module" "profile"
        "--exclude-module" "pstats"
    )
    
    # Platform-specific arguments
    case "$PLATFORM" in
        linux)
            PYINSTALLER_ARGS+=(
                "--console"
                "--hidden-import" "pystray._xorg"
            )
            ;;
        darwin)
            PYINSTALLER_ARGS+=(
                "--windowed"
                "--hidden-import" "pystray._darwin"
                "--osx-bundle-identifier" "com.cloudtolocalllm.tray"
            )
            ;;
        *)
            print_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    # Add the main script
    PYINSTALLER_ARGS+=("enhanced_tray_daemon.py")
    
    print_status "Running PyInstaller with args: ${PYINSTALLER_ARGS[*]}"
    
    # Run PyInstaller
    if pyinstaller "${PYINSTALLER_ARGS[@]}"; then
        print_status "Build completed successfully"
        
        # Verify executable
        EXE_PATH="$DIST_DIR/$PLATFORM-$ARCH/$EXE_NAME"
        if [ -f "$EXE_PATH" ]; then
            print_status "Executable created: $EXE_PATH"
            print_status "Size: $(du -h "$EXE_PATH" | cut -f1)"
            
            # Make executable
            chmod +x "$EXE_PATH"
            
            return 0
        else
            print_error "Executable not found at expected path: $EXE_PATH"
            return 1
        fi
    else
        print_error "PyInstaller build failed"
        return 1
    fi
}

# Build the settings application
build_settings_app() {
    print_status "Building settings application..."

    cd "$TRAY_DAEMON_DIR"
    source venv/bin/activate

    # Settings app executable name
    SETTINGS_EXE_NAME="cloudtolocalllm-settings"

    # PyInstaller arguments for settings app with size optimization
    SETTINGS_PYINSTALLER_ARGS=(
        "--onefile"
        "--name" "$SETTINGS_EXE_NAME"
        "--distpath" "$DIST_DIR/$PLATFORM-$ARCH"
        "--workpath" "$BUILD_DIR/settings"
        "--specpath" "$BUILD_DIR/settings"
        "--clean"
        "--strip"
        "--optimize" "2"
        "--exclude-module" "matplotlib"
        "--exclude-module" "numpy"
        "--exclude-module" "scipy"
        "--exclude-module" "pandas"
        "--exclude-module" "jupyter"
        "--exclude-module" "IPython"
        "--exclude-module" "test"
        "--exclude-module" "unittest"
        "--exclude-module" "doctest"
        "--exclude-module" "pdb"
        "--exclude-module" "profile"
        "--exclude-module" "pstats"
        "--exclude-module" "pystray"
    )

    # Platform-specific arguments for settings app
    case "$PLATFORM" in
        linux)
            SETTINGS_PYINSTALLER_ARGS+=(
                "--windowed"
                "--hidden-import" "tkinter"
                "--hidden-import" "tkinter.ttk"
                "--hidden-import" "tkinter.scrolledtext"
            )
            ;;
        darwin)
            SETTINGS_PYINSTALLER_ARGS+=(
                "--windowed"
                "--hidden-import" "tkinter"
                "--osx-bundle-identifier" "com.cloudtolocalllm.settings"
            )
            ;;
        *)
            print_error "Unsupported platform for settings app: $PLATFORM"
            return 1
            ;;
    esac

    # Add the settings script
    SETTINGS_PYINSTALLER_ARGS+=("settings_app.py")

    print_status "Building settings app with args: ${SETTINGS_PYINSTALLER_ARGS[*]}"

    # Run PyInstaller for settings app
    if pyinstaller "${SETTINGS_PYINSTALLER_ARGS[@]}"; then
        print_status "Settings app build completed successfully"

        # Verify settings executable
        SETTINGS_EXE_PATH="$DIST_DIR/$PLATFORM-$ARCH/$SETTINGS_EXE_NAME"
        if [ -f "$SETTINGS_EXE_PATH" ]; then
            print_status "Settings executable created: $SETTINGS_EXE_PATH"
            print_status "Size: $(du -h "$SETTINGS_EXE_PATH" | cut -f1)"

            # Make executable
            chmod +x "$SETTINGS_EXE_PATH"

            return 0
        else
            print_error "Settings executable not found at expected path: $SETTINGS_EXE_PATH"
            return 1
        fi
    else
        print_error "Settings app PyInstaller build failed"
        return 1
    fi
}

# Copy additional files
copy_additional_files() {
    print_status "Copying additional files..."

    # Copy startup script
    if [ -f "$TRAY_DAEMON_DIR/start_enhanced_daemon.sh" ]; then
        cp "$TRAY_DAEMON_DIR/start_enhanced_daemon.sh" "$DIST_DIR/$PLATFORM-$ARCH/"
        chmod +x "$DIST_DIR/$PLATFORM-$ARCH/start_enhanced_daemon.sh"
        print_status "Copied startup script"
    fi

    # Copy requirements file
    if [ -f "$TRAY_DAEMON_DIR/requirements.txt" ]; then
        cp "$TRAY_DAEMON_DIR/requirements.txt" "$DIST_DIR/$PLATFORM-$ARCH/"
        print_status "Copied requirements.txt"
    fi

    # Copy documentation
    if [ -f "$TRAY_DAEMON_DIR/ENHANCED_ARCHITECTURE.md" ]; then
        cp "$TRAY_DAEMON_DIR/ENHANCED_ARCHITECTURE.md" "$DIST_DIR/$PLATFORM-$ARCH/"
        print_status "Copied architecture documentation"
    fi
}

# Test the built executable
test_executable() {
    EXE_PATH="$DIST_DIR/$PLATFORM-$ARCH/cloudtolocalllm-enhanced-tray"
    
    if [ ! -f "$EXE_PATH" ]; then
        print_error "Executable not found for testing: $EXE_PATH"
        return 1
    fi
    
    print_status "Testing executable..."
    
    # Test version flag
    if timeout 10 "$EXE_PATH" --version &> /dev/null; then
        print_status "Version test passed"
    else
        print_warning "Version test failed or timed out"
    fi
    
    # Test help flag
    if timeout 10 "$EXE_PATH" --help &> /dev/null; then
        print_status "Help test passed"
    else
        print_warning "Help test failed or timed out"
    fi
    
    print_status "Executable testing completed"
}

# Clean up build artifacts
cleanup() {
    print_status "Cleaning up build artifacts..."
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_status "Removed build directory"
    fi
    
    # Clean Python cache
    find "$TRAY_DAEMON_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TRAY_DAEMON_DIR" -name "*.pyc" -delete 2>/dev/null || true
}

# Main build process
main() {
    # Check if tray daemon directory exists
    if [ ! -d "$TRAY_DAEMON_DIR" ]; then
        print_error "Tray daemon directory not found: $TRAY_DAEMON_DIR"
        exit 1
    fi
    
    # Check prerequisites
    check_python
    check_pip
    
    # Install dependencies
    install_dependencies
    
    # Build daemon
    if build_daemon; then
        print_status "Enhanced tray daemon build successful!"

        # Build settings app
        if build_settings_app; then
            print_status "Settings app build successful!"
        else
            print_warning "Settings app build failed, continuing without it"
        fi

        # Copy additional files
        copy_additional_files

        # Test executable
        test_executable

        # Show final status
        EXE_PATH="$DIST_DIR/$PLATFORM-$ARCH/cloudtolocalllm-enhanced-tray"
        SETTINGS_PATH="$DIST_DIR/$PLATFORM-$ARCH/cloudtolocalllm-settings"
        echo ""
        echo -e "${GREEN}✓ Enhanced tray daemon built successfully!${NC}"
        echo -e "${GREEN}  Main Executable: $EXE_PATH${NC}"
        if [ -f "$SETTINGS_PATH" ]; then
            echo -e "${GREEN}  Settings App: $SETTINGS_PATH${NC}"
        fi
        echo -e "${GREEN}  Platform: $PLATFORM-$ARCH${NC}"
        echo -e "${GREEN}  Output Directory: $DIST_DIR/$PLATFORM-$ARCH${NC}"
        echo ""
    else
        print_error "Build failed!"
        exit 1
    fi
    
    # Cleanup
    cleanup
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--clean]"
        echo ""
        echo "Build the CloudToLocalLLM Enhanced Tray Daemon with universal connection management."
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --clean       Clean build artifacts and exit"
        exit 0
        ;;
    --clean)
        cleanup
        print_status "Cleanup completed"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
