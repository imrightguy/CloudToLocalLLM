# MCP Tools for Crush CLI - Quick Reference

## What's Installed

All MCP (Model Context Protocol) tools for Crush CLI have been successfully tested and are available for use.

## Available MCP Servers (10 total)

### Core Servers

1. **Sequential Thinking** - Multi-step problem-solving and planning
2. **Knowledge Graph Memory** - Persistent knowledge store with graph-based memory
3. **Filesystem** - File operations (read, write, search)
4. **GitHub** - GitHub API operations (requires `GITHUB_TOKEN`)
5. **PostgreSQL** - Database operations (requires connection string)
6. **Puppeteer** - Browser automation
7. **Context7** - Documentation and knowledge base retrieval
8. **PDF** - PDF document processing

### Additional Knowledge Graph Options

9. **Local Knowledge Graph** - Local knowledge graph for persistent memory
10. **Personal Knowledge Graph** - Personal KG for development decisions

## Quick Setup

### Run the setup script:
```bash
./scripts/setup-mcp-crush-cli.sh
```

### Configure Crush CLI:
Copy the configuration from `.crush-mcp-config.json` to your Crush CLI MCP configuration file.

### Set environment variables (if needed):
```bash
export GITHUB_TOKEN="your_github_token_here"
export POSTGRES_USER="appuser"
export POSTGRES_PASSWORD="changeme"
```

## Configuration Files

- **Setup Script**: `scripts/setup-mcp-crush-cli.sh`
- **Configuration**: `.crush-mcp-config.json`
- **Documentation**: `docs/development/MCP_CRUSH_CLI_SETUP.md`

## Testing MCP Servers

Each MCP server can be tested individually:
```bash
npx -y @modelcontextprotocol/server-sequential-thinking
npx -y @modelcontextprotocol/server-memory
npx -y @modelcontextprotocol/server-filesystem /mnt/data/projects/CloudToLocalLLM
npx -y @modelcontextprotocol/server-github
npx -y @modelcontextprotocol/server-postgres postgresql://appuser:changeme@localhost:5432/CloudToLocalLLM
npx -y @upstash/context7-mcp
npx -y @modelcontextprotocol/server-pdf
npx -y @modelcontextprotocol/server-puppeteer
```

## Key Features

### Sequential Thinking
- Break down complex problems
- Multi-step reasoning
- Implementation planning

### Knowledge Graph Memory
- Persistent knowledge storage
- Graph-based relationships
- Cross-session context

### Filesystem
- Read/write files
- Search codebase
- Project structure management

### GitHub
- Pull request management
- Issue tracking
- Workflow management

### PostgreSQL
- Database migrations
- Query execution
- Schema management

### Context7
- API documentation
- Best practices
- Library references

### PDF
- Text extraction
- Document analysis
- Specification reading

### Puppeteer
- Browser automation
- End-to-end testing
- Web scraping

## Troubleshooting

**Problem**: MCP server not available
**Solution**: Run `./scripts/setup-mcp-crush-cli.sh` to verify all servers

**Problem**: GitHub operations fail
**Solution**: Ensure `GITHUB_TOKEN` is set and has proper permissions

**Problem**: PostgreSQL connection fails
**Solution**: Verify PostgreSQL is running and credentials are correct

## Next Steps

1. ✅ Run the setup script to verify installation
2. ✅ Copy `.crush-mcp-config.json` to your Crush CLI configuration
3. ✅ Set required environment variables
4. ✅ Test individual MCP servers
5. ✅ Start using MCP tools in your Crush CLI workflow

## Documentation

For detailed information, see:
- `docs/development/MCP_CRUSH_CLI_SETUP.md` - Complete setup guide
- `.crush-mcp-config.json` - Example configuration
- `scripts/setup-mcp-crush-cli.sh` - Setup and test script

---

**Status**: ✅ All 10 MCP servers installed and ready to use

**Last Updated**: February 18, 2026
