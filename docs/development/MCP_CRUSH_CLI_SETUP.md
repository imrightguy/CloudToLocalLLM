# MCP Tools Configuration for Crush CLI

This guide explains how to configure and use MCP (Model Context Protocol) servers with Crush CLI.

## Available MCP Servers

### Core MCP Servers

| Server | Package | Purpose | Requires |
|--------|---------|---------|----------|
| **Sequential Thinking** | `@modelcontextprotocol/server-sequential-thinking` | Multi-step problem-solving and planning | None |
| **Knowledge Graph Memory** | `@modelcontextprotocol/server-memory` | Persistent knowledge store with graph-based memory | None |
| **Filesystem** | `@modelcontextprotocol/server-filesystem` | File operations (read, write, search) | Directory path |
| **GitHub** | `@modelcontextprotocol/server-github` | GitHub API operations (PRs, issues, workflows) | `GITHUB_TOKEN` |
| **PostgreSQL** | `@modelcontextprotocol/server-postgres` | Database operations (migrations, queries) | Connection string |
| **Puppeteer** | `@modelcontextprotocol/server-puppeteer` | Browser automation | None |
| **Context7** | `@upstash/context7-mcp` | Documentation and knowledge base retrieval | None |
| **PDF** | `@modelcontextprotocol/server-pdf` | PDF document processing | None |

### Additional Knowledge Graph Options

| Server | Package | Purpose | Requires |
|--------|---------|---------|----------|
| **Local Knowledge Graph** | `@itseasy21/mcp-knowledge-graph` | Local knowledge graph for persistent memory | None |
| **Personal Knowledge Graph** | `@tomschell/personal-kg-mcp` | Personal KG for development decisions | None |

## Installation

All MCP servers are already tested and available. Run the setup script to verify:

```bash
./scripts/setup-mcp-crush-cli.sh
```

## Configuration

### Crush CLI MCP Configuration

MCP servers for Crush CLI need to be configured in the appropriate configuration file. The configuration format depends on your Crush CLI setup.

#### Example Configuration Format

```json
{
  "mcpServers": {
    "sequentialthinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Multi-step problem-solving and planning"
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Persistent knowledge store with graph-based memory"
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/mnt/data/projects/CloudToLocalLLM"],
      "description": "File system operations for the project directory"
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      },
      "description": "GitHub API operations"
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://appuser:changeme@localhost:5432/CloudToLocalLLM"],
      "description": "PostgreSQL database operations",
      "env": {
        "POSTGRES_HOST": "localhost",
        "POSTGRES_PORT": "5432",
        "POSTGRES_DB": "cloudtolocalllm",
        "POSTGRES_USER": "${POSTGRES_USER:-appuser}",
        "POSTGRES_PASSWORD": "${POSTGRES_PASSWORD:-changeme}"
      }
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "description": "Documentation and knowledge base retrieval"
    },
    "pdf": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-pdf"],
      "description": "PDF document processing"
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
      "description": "Browser automation"
    }
  }
}
```

### Environment Variables

Some MCP servers require environment variables:

```bash
# GitHub (required for GitHub MCP server)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# PostgreSQL (required for PostgreSQL MCP server)
export POSTGRES_HOST="localhost"
export POSTGRES_PORT="5432"
export POSTGRES_DB="CloudToLocalLLM"
export POSTGRES_USER="appuser"
export POSTGRES_PASSWORD="changeme"
```

## Usage Examples

### Sequential Thinking

Use for complex multi-step problem solving:
- Planning architecture changes
- Breaking down large tasks
- Reasoning through complex logic

### Knowledge Graph Memory

Use for persistent knowledge:
- Storing architectural decisions
- Remembering project-specific patterns
- Maintaining context across sessions

### Filesystem

Use for file operations:
- Reading and writing files
- Searching through codebase
- Managing project structure

### GitHub

Use for GitHub operations:
- Creating pull requests
- Managing issues
- Checking CI/CD status
- Managing workflows

### PostgreSQL

Use for database operations:
- Running migrations
- Querying data
- Schema management

### Context7

Use for documentation lookup:
- API references
- Best practices
- Library documentation

### PDF

Use for PDF processing:
- Extracting text from PDFs
- Analyzing documentation
- Reading specifications

### Puppeteer

Use for browser automation:
- End-to-end testing
- Web scraping
- UI automation

## Testing MCP Servers

After configuration, test each MCP server:

```bash
# Test sequential thinking
npx -y @modelcontextprotocol/server-sequential-thinking

# Test memory
npx -y @modelcontextprotocol/server-memory

# Test filesystem
npx -y @modelcontextprotocol/server-filesystem /mnt/data/projects/CloudToLocalLLM

# Test GitHub (requires token)
npx -y @modelcontextprotocol/server-github
```

## Troubleshooting

### MCP Server Not Available

If an MCP server shows as "not available":
1. Ensure `npx` is installed: `npx --version`
2. Check internet connection for npm registry access
3. Verify package name is correct
4. Run the setup script: `./scripts/setup-mcp-crush-cli.sh`

### GitHub Operations Fail

1. Check `GITHUB_TOKEN` is set and valid
2. Ensure token has necessary permissions
3. Verify token hasn't expired

### PostgreSQL Operations Fail

1. Check PostgreSQL server is running
2. Verify connection string is correct
3. Ensure database and user exist
4. Check firewall settings

### Permission Errors

1. Check file system permissions for the filesystem server
2. Ensure Crush CLI has appropriate access rights
3. Verify directory paths are correct

## Additional Resources

- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [MCP SDK](https://npm.im/@modelcontextprotocol/sdk)
- [Claude MCP Integration](https://docs.anthropic.com/claude/mcp)

## Project-Specific Notes

For the CloudToLocalLLM project:

- The Filesystem server should point to `/mnt/data/projects/CloudToLocalLLM`
- The PostgreSQL server should use the project database connection string
- GitHub tokens can be generated at https://github.com/settings/tokens

## Support

For issues or questions:
1. Check the setup script output: `./scripts/setup-mcp-crush-cli.sh`
2. Review MCP server logs
3. Consult the [MCP documentation](https://modelcontextprotocol.io/)
4. Open an issue in the project repository
