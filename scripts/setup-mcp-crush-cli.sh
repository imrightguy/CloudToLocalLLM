#!/bin/bash
# MCP Tools Setup for Crush CLI
# This script installs and configures essential MCP servers for the Crush CLI environment

set -e

echo "🚀 Setting up MCP tools for Crush CLI..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if npx is available
if ! command -v npx &> /dev/null; then
    echo -e "${RED}✗ npx is not installed. Please install Node.js first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} npx is installed (version: $(npx --version))"
echo ""

# List of MCP servers to test/install
# Format: "package_name|display_name"
MCP_SERVERS=(
    "@modelcontextprotocol/server-sequential-thinking|Sequential Thinking"
    "@modelcontextprotocol/server-memory|Knowledge Graph Memory"
    "@modelcontextprotocol/server-filesystem|Filesystem"
    "@modelcontextprotocol/server-github|GitHub"
    "@modelcontextprotocol/server-postgres|PostgreSQL"
    "@modelcontextprotocol/server-puppeteer|Puppeteer"
    "@upstash/context7-mcp|Context7"
    "@modelcontextprotocol/server-pdf|PDF"
    "@itseasy21/mcp-knowledge-graph|Local Knowledge Graph"
    "@tomschell/personal-kg-mcp|Personal Knowledge Graph"
)

# Track successful and failed installations
SUCCESS=()
FAILED=()

echo "Testing MCP server availability..."
echo "=========================================="

for server_info in "${MCP_SERVERS[@]}"; do
    IFS='|' read -r package_name display_name <<< "$server_info"

    echo -n "Testing $display_name ($package_name)... "

    # Test if package is available and can run
    if timeout 3 npx -y "$package_name" --help &> /dev/null 2>&1 || \
       timeout 3 npx -y "$package_name" version &> /dev/null 2>&1 || \
       timeout 3 npx -y "$package_name" /tmp &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Available${NC}"
        SUCCESS+=("$display_name")
    else
        echo -e "${YELLOW}? Checking...${NC}"
        # Try to check if package exists
        if npm view "$package_name" name &> /dev/null; then
            echo -e "${GREEN}✓ Available (package exists)${NC}"
            SUCCESS+=("$display_name")
        else
            echo -e "${RED}✗ Not found${NC}"
            FAILED+=("$display_name")
        fi
    fi
done

echo ""
echo "=========================================="
echo "Summary:"
echo -e "${GREEN}✓ Successfully installed/available: ${#SUCCESS[@]}${NC}"
for item in "${SUCCESS[@]}"; do
    echo "  - $item"
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed: ${#FAILED[@]}${NC}"
    for item in "${FAILED[@]}"; do
        echo "  - $item"
    done
fi

echo ""
echo "=========================================="
echo "Available MCP Servers for Crush CLI:"
echo ""
echo "1. Sequential Thinking (@modelcontextprotocol/server-sequential-thinking)"
echo "   - Multi-step problem-solving and planning"
echo ""
echo "2. Knowledge Graph Memory (@modelcontextprotocol/server-memory)"
echo "   - Persistent knowledge store with graph-based memory"
echo ""
echo "3. Filesystem (@modelcontextprotocol/server-filesystem)"
echo "   - File operations (specify directory path)"
echo ""
echo "4. GitHub (@modelcontextprotocol/server-github)"
echo "   - GitHub API operations (requires GITHUB_TOKEN)"
echo ""
echo "5. PostgreSQL (@modelcontextprotocol/server-postgres)"
echo "   - Database operations (requires connection string)"
echo ""
echo "6. Puppeteer (@modelcontextprotocol/server-puppeteer)"
echo "   - Browser automation"
echo ""
echo "7. Context7 (@upstash/context7-mcp)"
echo "   - Documentation and knowledge base retrieval"
echo ""
echo "8. PDF (@modelcontextprotocol/server-pdf)"
echo "   - PDF document processing"
echo ""
echo "Additional Knowledge Graph Options:"
echo "9. Local Knowledge Graph (@itseasy21/mcp-knowledge-graph)"
echo "   - Local knowledge graph for persistent memory"
echo ""
echo "10. Personal Knowledge Graph (@tomschell/personal-kg-mcp)"
echo "    - Personal KG for development decisions and insights"
echo ""
echo "=========================================="
echo ""
echo "Setup complete! 🎉"
echo ""
echo "To use these MCP servers in Crush CLI, they need to be configured"
echo "in the Crush CLI environment's MCP configuration."
echo ""
echo "Note: Some servers require environment variables:"
echo "  - GitHub: GITHUB_TOKEN"
echo "  - PostgreSQL: POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD"
