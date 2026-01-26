# MCP Tools Setup and Configuration

This document describes the Model Context Protocol (MCP) tools configured for efficient development of CloudToLocalLLM.

## Overview

MCP tools provide specialized capabilities for interacting with external services, automating tasks, and enhancing development workflows. All MCP servers are configured in `~/.cursor/mcp.json`.

## Configured MCP Servers

> **Mandatory Framework**: The **Sequential Thinking** MCP server is the primary framework for all complex development tasks. It must be used in conjunction with a **documentation-first methodology** to ensure systematic analysis.

### 1. Sequential Thinking (`sequentialthinking`)

- **Purpose**: Primary framework for systematic reasoning, complex problem-solving, and iterative analysis.
- **Package**: `@modelcontextprotocol/server-sequential-thinking`
- **Mandate**: **REQUIRED** for all multi-step tasks and architectural decisions.

### 2. GitHub (`github`)

- **Purpose**: GitHub repository and CI/CD management
- **Package**: `@modelcontextprotocol/server-github`
- **Capabilities**:
  - Manage workflows
  - Create secrets
  - Trigger deployments
  - Manage releases
  - Pull requests
  - Issues
  - File operations
- **Environment Variables**: `GITHUB_TOKEN` (GitHub Personal Access Token)

### 2. Filesystem (`filesystem`)

- **Purpose**: File system operations for project files
- **Package**: `@modelcontextprotocol/server-filesystem`
- **Capabilities**:
  - Read files
  - Write files
  - List directory
  - Search files
- **Scope**: `/home/rightguy/dev/CloudToLocalLLM`

### 3. PostgreSQL (`postgres`)

- **Purpose**: PostgreSQL database operations
- **Package**: `@modelcontextprotocol/server-postgres`
- **Capabilities**:
  - Query execution
  - Schema inspection
  - Table operations
- **Environment Variables**: `POSTGRES_CONNECTION_STRING`

### 4. Brave Search (`brave-search`)

- **Purpose**: Brave Search API for web research
- **Package**: `@modelcontextprotocol/server-brave-search`
- **Capabilities**:
  - Web search
  - Research
- **Environment Variables**: `BRAVE_API_KEY`

### 5. Puppeteer (`puppeteer`)

- **Purpose**: Puppeteer browser automation
- **Package**: `@modelcontextprotocol/server-puppeteer`
- **Capabilities**:
  - Page navigation
  - Screenshots
  - PDF generation
  - DOM manipulation

### 6. Kubernetes (`kubernetes`)

- **Purpose**: Kubernetes cluster management and operations
- **Type**: Custom server (project-specific)
- **Location**: `config/mcp/servers/kubernetes-server.js`
- **Capabilities**:
  - Deploy applications
  - Manage pods
  - View logs
  - Scale deployments
  - Rollback deployments
  - Manage services
  - Manage ingress
- **Environment Variables**:
  - `KUBECONFIG`: Path to kubeconfig file (default: `~/.kube/config`)
  - `KUBERNETES_NAMESPACE`: Namespace to operate in (default: `cloudtolocalllm`)

### 7. DigitalOcean (`digitalocean`)

- **Purpose**: DigitalOcean automation and management
- **Type**: Custom server (project-specific)
- **Location**: `config/mcp/servers/digitalocean-server.js`
- **Capabilities**:
  - Kubernetes operations
  - Container registry management
  - Cluster management
  - Load balancer configuration
  - DNS management
- **Environment Variables**:
  - `DIGITALOCEAN_TOKEN`: DigitalOcean API token
  - `DO_CLUSTER_NAME`: Cluster name (default: `cloudtolocalllm`)
  - `DO_REGION`: Region (default: `tor1`)
  - `DO_REGISTRY`: Container registry URL

### 8. SQLite (`sqlite`)

- **Purpose**: SQLite database operations for local app database
- **Package**: `@modelcontextprotocol/server-sqlite`
- **Capabilities**:
  - Query execution
  - Schema inspection
  - Table operations
- **Database**: `/home/rightguy/dev/CloudToLocalLLM/data/app.db`

### 9. Memory (`memory`)

- **Purpose**: Persistent memory storage for context across sessions
- **Package**: `@modelcontextprotocol/server-memory`
- **Capabilities**:
  - Store memories
  - Retrieve memories
  - Search memories

### 10. Sentry (`sentry`)

- **Purpose**: Production error monitoring and detailed debugging.
- **Server**: `mcp-server-sentry`
- **Capabilities**: Retrieve and analyze Sentry issues, stacktraces, and error patterns.

### 11. n8n-mcp (`n8n-mcp`)

- **Purpose**: Automation workflow management and node documentation.
- **Package**: `n8n-mcp`
- **Capabilities**: List nodes, get documentation, search properties, and validate workflows.

### 12. Context7 (`context7`)

- **Purpose**: Up-to-date documentation and code examples for libraries.
- **Package**: `@upstash/context7-mcp`
- **Capabilities**: Resolve library IDs and retrieve deep documentation.

### 13. Playwright (`playwright`)

- **Purpose**: Browser automation and end-to-end testing.
- **Package**: `@playwright/mcp`
- **Capabilities**: Full browser interaction and snapshotting.

### 14. Auth0 (`auth0`)

- **Purpose**: Identity and Access Management (IAM) operations.
- **Package**: `@auth0/auth0-mcp-server`
- **Capabilities**: Manage users, applications, and APIs.

## Required CLI Tools

The following CLI tools are required for the MCP servers to function:

### Core Tools

- ✅ **Flutter** (3.8+) - Installed via FVM
- ✅ **Dart** (3.9+) - Included with Flutter
- ✅ **Git** - Installed
- ✅ **Docker** - Installed
- ✅ **kubectl** - Installed
- ✅ **GitHub CLI (gh)** - Installed
- ✅ **Azure CLI (az)** - Installed
- ✅ **Sentry CLI** - Installed
- ✅ **Node.js** (18+) - Installed (custom installation, not in PATH)
- ✅ **npm** - Included with Node.js

### Platform-Specific Tools

- **doctl** - DigitalOcean CLI (required for DigitalOcean MCP server)

## Environment Variables

Set the following environment variables in your shell configuration (`.bashrc`, `.zshrc`, etc.) or in Cursor's environment:

```bash
# GitHub
export GITHUB_TOKEN="your_github_personal_access_token"

# PostgreSQL
export POSTGRES_CONNECTION_STRING="postgresql://user:password@host:port/database"

# Brave Search
export BRAVE_API_KEY="your_brave_api_key"

# DigitalOcean
export DIGITALOCEAN_TOKEN="your_digitalocean_token"
export DO_CLUSTER_NAME="cloudtolocalllm"
export DO_REGION="tor1"
export DO_REGISTRY="registry.digitalocean.com/cloudtolocalllm"

# Kubernetes
export KUBECONFIG="$HOME/.kube/config"
export KUBERNETES_NAMESPACE="cloudtolocalllm"
```

## Browser Testing

Cursor provides integrated browser tools for web testing and automation:

- `browser_navigate` - Navigate to URLs
- `browser_snapshot` - Capture accessibility snapshots
- `browser_click` - Click elements
- `browser_type` - Type text
- `browser_screenshot` - Take screenshots
- `browser_console_messages` - Get console logs
- `browser_network_requests` - Monitor network activity

These tools are available directly in Cursor and do not require separate MCP servers.

## Setup Instructions

### 1. Verify Node.js Installation

Node.js is installed via NVM. The PATH has been configured in `~/.zshrc` to include Node.js binaries:

```bash
# Verify Node.js is in PATH
which node
which npx
node --version
npx --version
```

If Node.js is not found, ensure your `~/.zshrc` includes:

```bash
export PATH="$HOME/.nvm/versions/node/v24.11.1/bin:$PATH"
```

**Note**: After updating Node.js via NVM, update the PATH in `~/.zshrc` to point to the new version. Restart your terminal or run `source ~/.zshrc` for changes to take effect.

### 2. Verify MCP Configuration

The MCP configuration is located at `~/.cursor/mcp.json`. After making changes:

1. Restart Cursor for changes to take effect
2. Check Cursor's MCP server status in Settings > Features > MCP Servers
3. Verify each server connects successfully

### 3. Test MCP Tools

Test each MCP server by using its tools in Cursor:

- **GitHub**: List repository issues
- **Filesystem**: List project directory
- **Kubernetes**: Get pods in namespace
- **DigitalOcean**: List clusters
- **Browser** (Cursor integrated): Navigate to a URL and take a snapshot

## Troubleshooting

### Node.js Not Found

If `node` command is not found:

- Node.js is installed but not in PATH
- Use full path to node in custom MCP servers
- Or add Node.js to PATH in your shell configuration

### MCP Server Connection Failures

1. Check server logs in Cursor's MCP server status
2. Verify environment variables are set correctly
3. Ensure required CLI tools are installed
4. Check network connectivity for external services

### Custom Servers Not Working

For custom Kubernetes and DigitalOcean servers:

1. Verify Node.js can execute the server files
2. Check file permissions: `chmod +x config/mcp/servers/*.js`
3. Verify environment variables are set
4. Test server directly: `node config/mcp/servers/kubernetes-server.js`

## Best Practices

1. **Documentation-First Methodology**: Always review project documentation (`docs/`) and steering rules (`.kiro/steering/`) before tool execution.
2. **Sequential Thinking Primary**: Use the `sequentialthinking` tool as the foundation for all complex tasks to ensure systematic reasoning.
3. **Use MCP Tools Over CLI**: Prefer MCP tools when available for better integration and structured output.
4. **Atomic Operations**: Execute one tool at a time and wait for success before proceeding.
5. **Schema Adherence**: Strictly follow the input schema for all tool calls.
6. **Kilocode Identity**: All development actions must align with the technical excellence and architectural standards defined for Kilocode.

## Kiro IDE Integration

CloudToLocalLLM includes specialized configuration for Kiro IDE with custom AI assistant modes and enhanced MCP integration. See the [Kiro IDE Configuration Guide](KIRO_IDE_CONFIGURATION.md) for:

- Custom AI assistant modes (Documentation Specialist, Code Reviewer, Test Engineer, Code Simplifier)
- Enhanced MCP server configurations
- Development workflow automation
- Gemini CLI integration

## Additional Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [MCP Servers Registry](https://github.com/modelcontextprotocol/servers)
- [Cursor MCP Documentation](https://docs.cursor.com/)
- [Browser Tools MCP](https://github.com/AgentDeskAI/browser-tools-mcp)
- [Kiro IDE Configuration Guide](KIRO_IDE_CONFIGURATION.md)
