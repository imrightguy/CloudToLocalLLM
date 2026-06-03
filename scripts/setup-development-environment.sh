#!/bin/bash
# CloudToLocalLLM Development Environment Setup Script
# This script installs all required tools and dependencies for CloudToLocalLLM development
# on CachyOS / Manjaro Linux with all green checkmarks in flutter doctor (except VSCode)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Function to check command success
check_command() {
    if [ $? -eq 0 ]; then
        log_success "$1"
    else
        log_error "$1 failed"
        exit 1
    fi
}

REPO_ROOT="/home/rightguy/CloudToLocalLLM"
log_info "Starting CloudToLocalLLM development environment setup..."
log_info "Target directory: $REPO_ROOT"

# Ensure repository ownership
log_info "Ensuring repository ownership for $USER..."
sudo chown -R $USER:$(id -gn $USER) "$REPO_ROOT"

# Phase 1: Enable multilib repository
log_info "Phase 1: Enabling multilib repository for 32-bit Android libraries..."
sudo sed -i '/\[multilib\]/,/^$/ { s/^#//; }' /etc/pacman.conf || true
sudo pacman -Syu --noconfirm
check_command "Multilib repository enabled"

# Phase 2: Install AUR helper (yay)
log_info "Phase 2: Checking for yay AUR helper..."
if ! command -v yay &> /dev/null; then
    log_info "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd /tmp
    rm -rf yay
fi
yay --version > /dev/null
check_command "yay AUR helper verified"

# Phase 3: Install Flutter
log_info "Phase 3: Installing Flutter SDK..."
# Using flutter-bin to avoid long build times
yay -S flutter-bin --noconfirm --needed
# Standard path for flutter-bin is /opt/flutter
export PATH="$PATH:/opt/flutter/bin"
check_command "Flutter SDK installed"

# Phase 4: Install Flutter build dependencies and Chrome/Chromium
log_info "Phase 4: Installing Flutter build dependencies and Chromium..."
sudo pacman -S --noconfirm clang cmake ninja pkgconf gtk3 libglvnd libepoxy libdrm libxkbcommon libxml2 libpng libtiff chromium
# Set CHROME_EXECUTABLE in bashrc if not present
if ! grep -q 'CHROME_EXECUTABLE' "$HOME/.bashrc"; then
    echo 'export CHROME_EXECUTABLE=/usr/bin/chromium' >> "$HOME/.bashrc"
fi
export CHROME_EXECUTABLE=/usr/bin/chromium
check_command "Flutter dependencies installed"

# Phase 5: Install Ollama and download Gemma3
log_info "Phase 5: Installing Ollama and downloading Gemma3 model..."
sudo pacman -S --noconfirm ollama
sudo systemctl enable --now ollama
sleep 5
log_info "Pulling Gemma 3 model..."
ollama pull gemma3
check_command "Ollama and Gemma3 installed"

# Phase 6: Install Android Studio
log_info "Phase 6: Installing Android Studio..."
yay -S android-studio --noconfirm --needed
check_command "Android Studio installed"

# Phase 7: Install Android SDK components
log_info "Phase 7: Installing Android SDK components..."
yay -S --noconfirm android-sdk-cmdline-tools-latest android-sdk-platform-tools android-sdk-build-tools android-platform-36 android-emulator --needed
check_command "Android SDK components installed"

# Phase 8: Configure Android SDK and accept licenses
log_info "Phase 8: Configuring Android SDK and accepting licenses..."
sudo chown -R $USER:$(id -gn $USER) /opt/android-sdk || true
flutter config --android-sdk /opt/android-sdk
# Automatically accept licenses
yes | flutter doctor --android-licenses || true
check_command "Android SDK configured"

# Phase 9: Install 32-bit libraries for Android emulator
log_info "Phase 9: Installing 32-bit libraries for Android emulator..."
sudo pacman -S --noconfirm lib32-ncurses lib32-zlib lib32-gcc-libs lib32-glibc
check_command "32-bit Android libraries installed"

# Phase 10: Install Docker
log_info "Phase 10: Installing Docker..."
sudo pacman -S --noconfirm docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER || true
check_command "Docker installed"

# Phase 11: Install GitHub CLI
log_info "Phase 11: Installing GitHub CLI..."
sudo pacman -S --noconfirm github-cli
check_command "GitHub CLI installed"

# Phase 12: Install Azure CLI
log_info "Phase 12: Installing Azure CLI..."
yay -S azure-cli --noconfirm --needed
check_command "Azure CLI installed"

# Phase 13: Install kubectl
log_info "Phase 13: Installing kubectl..."
sudo pacman -S --noconfirm kubectl
check_command "kubectl installed"

# Phase 14: Install Helm
log_info "Phase 14: Installing Helm..."
sudo pacman -S --noconfirm helm
check_command "Helm installed"

# Phase 15: Install MCP packages
log_info "Phase 15: Installing MCP server packages..."
mkdir -p "$HOME/.config/opencode"
cd "$HOME/.config/opencode"
npm install @modelcontextprotocol/server-sequential-thinking @upstash/context7-mcp @modelcontextprotocol/server-memory
check_command "MCP packages installed"

# Phase 16: Create MCP wrapper scripts
log_info "Phase 16: Creating MCP wrapper scripts..."
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/mcp-sequentialthinking" << 'EOF'
#!/bin/bash
cd "$HOME/.config/opencode"
exec npx -y @modelcontextprotocol/server-sequential-thinking "$@"
EOF
chmod +x "$HOME/.local/bin/mcp-sequentialthinking"

cat > "$HOME/.local/bin/mcp-context7" << 'EOF'
#!/bin/bash
cd "$HOME/.config/opencode"
exec npx -y @upstash/context7-mcp "$@"
EOF
chmod +x "$HOME/.local/bin/mcp-context7"

cat > "$HOME/.local/bin/mcp-memory" << 'EOF'
#!/bin/bash
cd "$HOME/.config/opencode"
exec npx -y @modelcontextprotocol/server-memory "$@"
EOF
chmod +x "$HOME/.local/bin/mcp-memory"
check_command "MCP wrapper scripts created"

# Phase 17: Add ~/.local/bin to PATH
log_info "Phase 17: Updating PATH..."
if ! grep -q '\.local/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# Phase 18: Configure MCP tools in Opencode
log_info "Phase 18: Configuring MCP tools..."
mkdir -p "$HOME/.config/opencode/mcp"

cat > "$HOME/.config/opencode/mcp/sequentialthinking.json" << 'EOF'
{
  "command": "mcp-sequentialthinking",
  "args": []
}
EOF

cat > "$HOME/.config/opencode/mcp/context7.json" << 'EOF'
{
  "command": "mcp-context7",
  "args": []
}
EOF

cat > "$HOME/.config/opencode/mcp/memory.json" << 'EOF'
{
  "command": "mcp-memory",
  "args": []
EOF
check_command "MCP tools configured"

# Phase 18.5: Configure MCP tools for Antigravity
log_info "Phase 18.5: Configuring MCP tools for Antigravity..."
mkdir -p "$HOME/.gemini/antigravity"

cat > "$HOME/.gemini/antigravity/mcp_config.json" << 'EOF'
{
  "mcpServers": {
    "dart-mcp-server": {
      "command": "dart",
      "args": [
        "mcp-server"
      ],
      "env": {}
    },
    "sequential-thinking": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ],
      "env": {}
    },
    "context7": {
      "command": "npx",
      "args": [
        "-y",
        "@upstash/context7-mcp"
      ]
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ]
    }
  }
}
EOF
check_command "Antigravity MCP tools configured"


# Phase 19: Configure Git
log_info "Phase 19: Configuring Git (Christopher Maltais)..."
git config --global user.name "Christopher Maltais"
git config --global user.email "christopher.maltais@gmail.com"
check_command "Git configured"

# Phase 20: Install project dependencies
log_info "Phase 20: Installing repository dependencies..."
cd "$REPO_ROOT"
# Use --prefix or absolute paths for reliability
npm install
cd "$REPO_ROOT/services/api-backend" && npm install
cd "$REPO_ROOT/services/streaming-proxy" && npm install
cd "$REPO_ROOT/services/sdk" && npm install
cd "$REPO_ROOT/backend/auth" && npm install
cd "$REPO_ROOT"
flutter pub get || true
check_command "Repository dependencies installed"

# Phase 21: Create OpenCode configuration with Antigravity models
log_info "Phase 21: Creating Antigravity model definitions..."
mkdir -p "$HOME/.config/opencode"

cat > "$HOME/.config/opencode/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-antigravity-auth@latest"],
  "provider": {
    "google": {
      "models": {
        "antigravity-gemini-3-pro": {
          "name": "Gemini 3 Pro (Antigravity)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingLevel": "low" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-gemini-3-flash": {
          "name": "Gemini 3 Flash (Antigravity)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "minimal": { "thinkingLevel": "minimal" },
            "low": { "thinkingLevel": "low" },
            "medium": { "thinkingLevel": "medium" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-claude-sonnet-4-5": {
          "name": "Claude Sonnet 4.5 (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "antigravity-claude-sonnet-4-5-thinking": {
          "name": "Claude Sonnet 4.5 Thinking (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingConfig": { "thinkingBudget": 8192 } },
            "max": { "thinkingConfig": { "thinkingBudget": 32768 } }
          }
        },
        "antigravity-claude-opus-4-5-thinking": {
          "name": "Claude Opus 4.5 Thinking (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingConfig": { "thinkingBudget": 8192 } },
            "max": { "thinkingConfig": { "thinkingBudget": 32768 } }
          }
        },
        "gemini-2.5-flash": {
          "name": "Gemini 2.5 Flash (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-2.5-pro": {
          "name": "Gemini 2.5 Pro (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3-flash-preview": {
          "name": "Gemini 3 Flash Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3-pro-preview": {
          "name": "Gemini 3 Pro Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        }
      }
    }
  }
}
EOF
check_command "OpenCode configuration created"

log_success "Setup complete! Please restart your terminal or run 'source ~/.bashrc' and then 'flutter doctor'."
