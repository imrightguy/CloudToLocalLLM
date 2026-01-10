#!/bin/bash
# OpenCode MCP Tools Setup Script
# This script installs and configures MCP tools for OpenCode agents

set -e

echo "=== OpenCode MCP Tools Setup ==="

# Install MCP server packages
echo "Installing MCP server packages..."
cd ~/.config/opencode
npm install @modelcontextprotocol/server-sequential-thinking @upstash/context7-mcp @modelcontextprotocol/server-memory 2>/dev/null || true

# Create wrapper scripts
echo "Creating MCP wrapper scripts..."
mkdir -p ~/.local/bin

for server_info in "sequentialthinking:@modelcontextprotocol/server-sequential-thinking" "context7:@upstash/context7-mcp" "memory:@modelcontextprotocol/server-memory"; do
    server_name=$(echo "$server_info" | cut -d':' -f1)
    package_name=$(echo "$server_info" | cut -d':' -f2)
    
    cat > ~/.local/bin/mcp-${server_name} << EOF
#!/bin/bash
cd ~/.config/opencode
exec npx -y ${package_name} "\${@}"
EOF
    chmod +x ~/.local/bin/mcp-${server_name}
done

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "MCP tools installed successfully!"
echo ""
echo "Available MCP tools:"
echo "  - mcp-sequentialthinking: Sequential thinking tool for complex problem-solving"
echo "  - mcp-context7: Context7 for library documentation retrieval"
echo "  - mcp-memory: Memory/knowledge graph for persistent storage"
echo ""
echo "To use manually, run:"
echo "  ~/.opencode/bin/opencode mcp add sequentialthinking"
echo "  (then enter: npx -y @modelcontextprotocol/server-sequential-thinking)"
echo "  (then enter: n)"
echo ""
echo "Or add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
