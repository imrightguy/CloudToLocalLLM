#!/bin/bash
# =============================================================================
# One-time setup script for Claude Code development environment
# =============================================================================

set -e

PROJECT_ROOT="/mnt/data/dev/CloudToLocalLLM"
SHELLRC="$HOME/.bashrc"
SOURCE_LINE="source $PROJECT_ROOT/claude_code_dev_env.sh"

echo "======================================================================"
echo "CloudToLocalLLM - Claude Code Development Environment Setup"
echo "======================================================================"
echo ""

# Check if already sourced
if grep -q "$SOURCE_LINE" "$SHELLRC" 2>/dev/null; then
    echo "✓ Development aliases already configured in ~/.bashrc"
else
    echo "Adding development aliases to ~/.bashrc..."
    echo "" >> "$SHELLRC"
    echo "# CloudToLocalLLM development environment" >> "$SHELLRC"
    echo "$SOURCE_LINE" >> "$SHELLRC"
    echo "✓ Added to ~/.bashrc"
fi

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo ""
    echo "⚠ GITHUB_TOKEN not set in environment"
    echo ""
    echo "To enable GitHub MCP server, create a token at:"
    echo "  https://github.com/settings/tokens"
    echo ""
    echo "Required scopes: repo, workflow, read:org"
    echo ""
    read -p "Enter your GitHub token (or press Enter to skip): " GITHUB_TOKEN_INPUT
    if [ -n "$GITHUB_TOKEN_INPUT" ]; then
        echo "export GITHUB_TOKEN=\"$GITHUB_TOKEN_INPUT\"" >> "$SHELLRC"
        echo "✓ GITHUB_TOKEN added to ~/.bashrc"
    fi
else
    echo "✓ GITHUB_TOKEN is set"
fi

# Check if config.json exists
CONFIG_FILE="$PROJECT_ROOT/.claude/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo "⚠ MCP config file not found: $CONFIG_FILE"
    echo ""
    echo "Please create it from the example:"
    echo "  cp $PROJECT_ROOT/.claude/config.json.example $CONFIG_FILE"
    echo ""
    echo "Then update with your actual credentials."
else
    echo "✓ MCP config file exists"
fi

# Check PostgreSQL connection
echo ""
echo "Checking PostgreSQL..."
if command -v psql &> /dev/null; then
    echo "✓ psql client is installed"
else
    echo "⚠ PostgreSQL client not found"
    echo "  Install: sudo pacman -S postgresql-client"
fi

# Check Docker
echo ""
echo "Checking Docker..."
if command -v docker &> /dev/null; then
    echo "✓ Docker is installed"
    if groups | grep -q docker; then
        echo "✓ User is in docker group"
    else
        echo "⚠ User not in docker group"
        echo "  Run: sudo usermod -aG docker \$USER"
        echo "  Then log out and back in"
    fi
else
    echo "⚠ Docker not found"
    echo "  Install: sudo pacman -S docker"
fi

# Optional tools
echo ""
echo "Optional tools (not required):"
echo "  pgcli:     Better PostgreSQL CLI  - pip install pgcli"
echo "  lazygit:   Terminal Git UI        - yay -S lazygit"
echo "  watchexec: File watcher           - cargo install watchexec"
echo ""

# Summary
echo "======================================================================"
echo "Setup complete!"
echo "======================================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Create MCP config from example:"
echo "   cp .claude/config.json.example .claude/config.json"
echo ""
echo "2. Update .claude/config.json with your credentials:"
echo "   - PostgreSQL connection string from services/api-backend/.env"
echo "   - GitHub token (if not already set)"
echo ""
echo "3. Reload your shell:"
echo "   source ~/.bashrc"
echo ""
echo "4. Verify setup:"
echo "   echo \$CLOUD_TO_LOCAL_LLM_ROOT"
echo "   alias | grep -E '^fw|^api-|^db-'"
echo ""
echo "For more information, see:"
echo "   .claude/SETUP.md"
echo ""
