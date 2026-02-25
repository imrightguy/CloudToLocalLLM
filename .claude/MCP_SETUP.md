# MCP Setup Guide for Crush (AI Assistant)

This guide explains the MCP (Model Context Protocol) tools configured for Crush (AI Assistant) development on CloudToLocalLLM.

## Prerequisites

- **npx** (comes with Node.js 16+) - ✅ Installed (version 11.10.1)
- **npm** - Required for MCP server packages

## Configured MCP Servers

The following MCP servers are configured in `.claude/settings.json` and will auto-install via `npx` when needed:

| Server | Package | Purpose |
|--------|---------|---------|
| context7 | `@modelcontextprotocol/server-context7` | Library documentation and knowledge base retrieval |
| sequentialthinking | `@modelcontextprotocol/server-sequential-thinking` | Multi-step problem-solving and planning |
| memory | `@modelcontextprotocol/server-memory` | Persistent knowledge store for project decisions |
| sentry | `mcp-remote` (remote) | Error tracking and issue analysis with OAuth |
| puppeteer | `@modelcontextprotocol/server-puppeteer` | Browser automation for E2E testing |

## Why These Servers?

### Context7
- **Purpose**: Look up library documentation, API patterns, best practices
- **Used by Crush**: Quick access to Flutter, Node.js, Auth0 docs without web searches
- **No setup required**: Works out of the box

### Sequential Thinking
- **Purpose**: Multi-step problem-solving, planning complex implementations
- **Used by Crush**: Validate solutions, plan multi-file changes, think through architecture
- **No setup required**: Works out of the box

### Memory
- **Purpose**: Persistent knowledge store across sessions
- **Used by Crush**: Remember project decisions, architectural notes, ongoing work
- **No setup required**: Works out of the box

### Sentry (via mcp-remote)
- **Purpose**: Error tracking and issue analysis
- **Used by Crush**: Investigate production errors, analyze stack traces
- **OAuth authentication**: No token needed - browser OAuth on first use
- **Remote server**: `https://mcp.sentry.dev/mcp`

### Puppeteer
- **Purpose**: Browser automation for end-to-end testing
- **Used by Crush**: Web scraping, UI testing, screenshot capture
- **No setup required**: Works out of the box

## Not Included (Why?)

### PostgreSQL MCP Server
- **Reason**: Project no longer uses PostgreSQL
- **Alternative**: Local Drift/SQLite for Flutter app
- **Status**: ❌ Removed

### GitHub MCP Server
- **Reason**: `gh` CLI and `zread` MCP tools already available
- **Alternative**: Use `gh` via bash or built-in `mcp_zread_*` tools
- **Status**: ❌ Removed

### Brave Search MCP Server
- **Reason**: `mcp_web-search-prime_webSearchPrime` already available
- **Alternative**: Built-in `mcp_web-search-prime_webSearchPrime` tool
- **Status**: ❌ Removed

### Filesystem/Shell/Git MCP Servers
- **Reason**: Crush has built-in file, bash, and git tools
- **Alternative**: Use native `edit`, `write`, `view`, `bash` tools
- **Status**: ❌ Removed

## Testing MCP Connections

After configuration, test MCP servers to ensure they work:

### Test context7 (no setup required)
```bash
npx -y @modelcontextprotocol/server-context7
# Should output: "Context7 MCP Server running on stdio"
# Press Ctrl+C to exit
```

### Test sequentialthinking (no setup required)
```bash
npx -y @modelcontextprotocol/server-sequential-thinking
# Should output: "Sequential Thinking MCP Server running on stdio"
# Press Ctrl+C to exit
```

### Test memory (no setup required)
```bash
npx -y @modelcontextprotocol/server-memory
# Should output: "Knowledge Graph MCP Server running on stdio"
# Press Ctrl+C to exit
```

### Test puppeteer (no setup required)
```bash
npx -y @modelcontextprotocol/server-puppeteer
# Should output: "Puppeteer MCP Server running on stdio"
# Press Ctrl+C to exit
```

### Test sentry (OAuth-based)
```bash
npx -y mcp-remote@latest https://mcp.sentry.dev/mcp
# Will open browser for OAuth authentication
# After auth, outputs: "Sentry MCP Server running on stdio"
# Press Ctrl+C to exit
```

## Using MCP Tools

Once configured, use MCP tools in Crush (AI Assistant) conversations:

```
"Use context7 to look up Flutter Provider patterns"
"Use sequentialthinking to plan the avatar evolution feature"
"Use memory to recall previous architectural decisions"
"Use puppeteer to take screenshots of the web app"
"Use sentry to investigate production errors"
```

## Built-in Alternatives

Crush has built-in tools that replace some MCP servers:

| MCP Server | Built-in Alternative | When to Use |
|------------|-------------------|--------------|
| filesystem | `edit`, `write`, `view`, `ls`, `glob`, `grep` | Always - better integration |
| shell | `bash` tool | Always - better integration |
| git | `bash` with git commands | Always - better integration |
| github | `bash gh api:*`, `mcp_zread_*` | For GitHub operations |
| brave-search | `mcp_web-search-prime_webSearchPrime` | For web search |
| fetch | `fetch` tool | For HTTP requests |

## Troubleshooting

### MCP server not found
**Error**: `npm error 404 Not Found`
**Solution**: Check package name in `.claude/settings.json`. Verify with `npm view @modelcontextprotocol/server-*`.

### npx cache issues
**Error**: Old cached packages causing issues
**Solution**: Clear npx cache:
```bash
rm -rf ~/.npm/_npx/*
```

### Sentry OAuth fails
**Error**: OAuth authentication not completing
**Solution**:
1. Check browser popup is not blocked
2. Verify Sentry account has access to the project
3. Try again - OAuth tokens expire after some time

### Puppeteer dependencies
**Error**: Chromium download failed or missing
**Solution**: Puppeteer will download Chromium automatically on first run. Ensure network access is available.

## Additional Resources

- **MCP Documentation**: https://modelcontextprotocol.io/
- **Context7 Docs**: https://github.com/modelcontextprotocol/servers/tree/main/src/context7
- **Sequential Thinking**: https://github.com/modelcontextprotocol/servers/tree/main/src/sequential-thinking
- **Memory Server**: https://github.com/modelcontextprotocol/servers/tree/main/src/memory
- **Sentry MCP**: https://mcp.sentry.dev/mcp
- **Puppeteer MCP**: https://github.com/modelcontextprotocol/servers/tree/main/src/puppeteer

## Configuration File

**Location**: `.claude/settings.json`

Current configuration:
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-context7"],
      "description": "Library documentation and knowledge base retrieval for Flutter, Node.js, Auth0"
    },
    "sequentialthinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Multi-step problem-solving and planning tool for complex implementations"
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Persistent knowledge store for project decisions, architectural notes, and ongoing work"
    },
    "sentry": {
      "command": "npx",
      "args": ["-y", "mcp-remote@latest", "https://mcp.sentry.dev/mcp"],
      "description": "Sentry error tracking and issue analysis with OAuth authentication"
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
      "description": "Browser automation for end-to-end testing and web scraping"
    }
  }
}
```

## Summary

✅ **All configured MCP servers work out of the box** - no environment variables required
✅ **Minimal setup** - only 5 essential servers for AI development
✅ **Optimized for Crush** - uses built-in tools when available
✅ **No external dependencies** - Sentry uses OAuth, others are self-contained

**Note**: Crush (AI Assistant) has access to many built-in tools including file operations, bash commands, git, web search, and web reading. MCP servers are only used for specialized capabilities like documentation lookup, persistent memory, and error tracking.
