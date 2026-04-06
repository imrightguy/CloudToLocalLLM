# MCP Tools Setup and Configuration

This document describes the Model Context Protocol (MCP) tools configured for efficient development of CloudToLocalLLM (CloudToLocalLLM).

## Overview

MCP tools provide specialized capabilities for interacting with external services, automating tasks, and enhancing development workflows. All MCP servers are configured in `.claude/settings.json` (Claude Code) and `.vscode/settings.json` (VS Code).

## Configured MCP Servers

> **Mandatory Framework**: The **Sequential Thinking** MCP server is the primary framework for all complex development tasks. It must be used in conjunction with a **documentation-first methodology** to ensure systematic analysis.

### Knowledge & Documentation

#### 1. Context7 (`context7`)

- **Purpose**: Library documentation and knowledge base retrieval for Flutter, Node.js, Auth0, and other dependencies
- **Package**: `@modelcontextprotocol/server-context7`
- **Use Cases**:
  - Looking up Flutter package documentation
  - Finding Node.js API patterns
  - Auth0 integration examples
  - Best practices for libraries

#### 2. Sequential Thinking (`sequentialthinking`)

- **Purpose**: Primary framework for systematic reasoning, complex problem-solving, and iterative analysis
- **Package**: `@modelcontextprotocol/server-sequential-thinking`
- **Mandate**: **REQUIRED** for all multi-step tasks and architectural decisions
- **Use Cases**:
  - Planning complex implementations
  - Breaking down multi-file refactors
  - Validating architectural decisions
  - Systematic troubleshooting

#### 3. Memory (`memory`)

- **Purpose**: Persistent knowledge store for project decisions, architectural notes, and ongoing work across sessions
- **Package**: `@modelcontextprotocol/server-memory`
- **Use Cases**:
  - Storing architectural decisions
  - Remembering context between sessions
  - Tracking ongoing work items
  - Retrieving project-specific patterns

### Development Tools

#### 4. Filesystem (`filesystem`)

- **Purpose**: Structured file system operations for reading, writing, and searching files
- **Package**: `@modelcontextprotocol/server-filesystem`
- **Scope**: `/mnt/data/projects/CloudToLocalLLM`
- **Use Cases**:
  - Reading project files
  - Writing new files
  - Searching code patterns
  - Directory traversal

#### 5. Shell (`shell`)

- **Purpose**: Command execution with structured interface and output capture
- **Package**: `@modelcontextprotocol/server-shell`
- **Shell**: `bash`
- **Use Cases**:
  - Running build commands
  - Executing tests
  - Running scripts
  - System operations

#### 6. Git (`git`)

- **Purpose**: Git operations for version control, commits, branches, and history
- **Package**: `@modelcontextprotocol/server-git`
- **Scope**: `/mnt/data/projects/CloudToLocalLLM`
- **Use Cases**:
  - Creating commits
  - Managing branches
  - Viewing history
  - Status checking

#### 7. GitHub (`github`)

- **Purpose**: GitHub API operations for PRs, issues, workflows, and releases
- **Package**: `@modelcontextprotocol/server-github`
- **Environment Variables**:
  - `GITHUB_TOKEN` - GitHub Personal Access Token (optional)
- **Use Cases**:
  - Creating pull requests
  - Managing issues
  - Triggering workflows
  - Managing releases

### Database

#### 8. PostgreSQL (`postgres`)

- **Purpose**: PostgreSQL database operations for migrations, queries, and schema management
- **Package**: `@modelcontextprotocol/server-postgres`
- **Connection**: `postgresql://appuser:changeme@localhost:5432/CloudToLocalLLM`
- **Environment Variables**:
  - `POSTGRES_HOST` (default: `localhost`)
  - `POSTGRES_PORT` (default: `5432`)
  - `POSTGRES_DB` (default: `CloudToLocalLLM`)
  - `POSTGRES_USER` (default: `appuser`)
  - `POSTGRES_PASSWORD` (default: `changeme`)
- **Use Cases**:
  - Running migrations
  - Executing queries
  - Inspecting schema
  - Testing database changes

### Network & Web

#### 9. Fetch (`fetch`)

- **Purpose**: HTTP requests for APIs, web content, and external services
- **Package**: `@modelcontextprotocol/server-fetch`
- **Use Cases**:
  - Calling external APIs
  - Fetching web content
  - Testing endpoints
  - Webhook testing

#### 10. Brave Search (`brave-search`)

- **Purpose**: Web search for documentation lookup, troubleshooting, and research
- **Package**: `@modelcontextprotocol/server-brave-search`
- **Environment Variables**:
  - `BRAVE_API_KEY` - Brave Search API key (optional)
- **Use Cases**:
  - Searching documentation
  - Troubleshooting issues
  - Researching best practices
  - Finding examples

#### 11. Puppeteer (`puppeteer`)

- **Purpose**: Browser automation for end-to-end testing and web scraping
- **Package**: `@modelcontextprotocol/server-puppeteer`
- **Use Cases**:
  - End-to-end testing
  - Web scraping
  - Screenshot capture
  - DOM manipulation

### Observability

#### 12. Sentry (`sentry`)

- **Purpose**: Sentry error tracking and issue analysis with OAuth authentication
- **Wrapper**: `mcp-remote@latest` (enables OAuth flow for remote MCP servers)
- **Server**: `https://mcp.sentry.dev/mcp`
- **Use Cases**:
  - Analyzing production errors
  - Investigating stack traces
  - Tracking error trends
  - Root cause analysis
- **Note**: Uses `mcp-remote` wrapper to handle OAuth authentication. Opens browser for authentication when first accessed.

## Configuration Files

### Claude Code Configuration

**File**: `.claude/settings.json`

Contains all 12 MCP servers with descriptions, arguments, and environment variables where applicable.

### VS Code Configuration

**File**: `.vscode/settings.json`

Contains the same MCP server configuration to ensure consistency across both development environments.

**Note**: VS Code also has `kiroAgent.configureMCP: "Disabled"` - do not enable this as it would conflict with the configured MCP servers.

## Required Environment Variables

### Optional Environment Variables

These environment variables are optional but recommended for full functionality:

```bash
# GitHub (for github MCP server)
export GITHUB_TOKEN="your_github_personal_access_token"

# PostgreSQL (for postgres MCP server)
export POSTGRES_USER="appuser"
export POSTGRES_PASSWORD="your_secure_password"

# Brave Search (for brave-search MCP server)
export BRAVE_API_KEY="your_brave_api_key"
```

### Setting Environment Variables

Add to your shell configuration (`.bashrc`, `.zshrc`, etc.):

```bash
# GitHub (optional - for GitHub MCP server)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# PostgreSQL (optional - override defaults)
export POSTGRES_USER="appuser"
export POSTGRES_PASSWORD="changeme"

# Brave Search (optional - for search functionality)
export BRAVE_API_KEY="BSxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

**Note**: PostgreSQL uses default values if environment variables are not set:
- Host: `localhost`
- Port: `5432`
- Database: `CloudToLocalLLM`
- User: `appuser`
- Password: `changeme`

## Usage Examples

### Using Sequential Thinking for Complex Tasks

When working on multi-step implementations:

1. Start with documentation review
2. Use `sequentialthinking` to plan the approach
3. Execute systematically using other MCP tools
4. Store decisions in `memory` for future reference

### Using Memory for Context Persistence

Store important architectural decisions:

```
memory:save - "Added rate limiting to LLM router with ModelRegistry pattern. Model tiers defined in model_tiers.dart."
```

### Using Context7 for Documentation

Look up Flutter package usage:

```
context7:resolve - "package:flutter_riverpod"
context7:doc - "package:flutter_riverpod ProviderScope"
```

### Using PostgreSQL for Database Operations

Test database changes:

```
postgres:query - "SELECT * FROM users LIMIT 10"
postgres:execute - "INSERT INTO conversations (title, created_at) VALUES ('Test', NOW())"
```

## Troubleshooting

### MCP Server Connection Failures

If MCP servers fail to connect:

1. **Check Node.js and npm are installed**:
   ```bash
   node --version  # Should be >= 22.0.0 < 25.0.0
   npm --version
   ```

2. **Verify npx can download packages**:
   ```bash
   npx -y @modelcontextprotocol/server-context7 --help
   ```

3. **Check environment variables** (for servers that require them):
   ```bash
   echo $GITHUB_TOKEN
   echo $BRAVE_API_KEY
   echo $POSTGRES_USER
   echo $POSTGRES_PASSWORD
   ```

4. **Restart Claude Code or VS Code** after changing configuration

### PostgreSQL Connection Issues

If PostgreSQL MCP server fails:

1. **Verify PostgreSQL is running**:
   ```bash
   # Using Docker Compose
   docker-compose ps postgres

   # Using local installation
   pg_isready -h localhost -p 5432
   ```

2. **Test connection**:
   ```bash
   psql postgresql://appuser:changeme@localhost:5432/CloudToLocalLLM
   ```

3. **Check credentials**: Ensure `POSTGRES_USER` and `POSTGRES_PASSWORD` match your database configuration

### Sentry OAuth Issues

When using Sentry MCP server for the first time:

1. The `mcp-remote` wrapper will open a browser window
2. Complete the OAuth authentication flow
3. The bridge will create a local proxy for MCP client connections
4. If you see "Unexpected end of JSON input", ensure your MCP-capable client is configured correctly

### GitHub MCP Server Issues

If GitHub MCP server fails to authenticate:

1. **Verify token has correct permissions**:
   - `repo` - Full repository access
   - `workflow` - Workflow actions
   - `read:org` - Organization read access

2. **Test token**:
   ```bash
   gh auth status
   ```

3. **Regenerate token** if necessary:
   - Go to GitHub Settings > Developer Settings > Personal Access Tokens
   - Create new token with required scopes
   - Update `GITHUB_TOKEN` environment variable

## Best Practices

1. **Documentation-First Methodology**: Always review project documentation (`docs/`) and steering rules (`.kiro/steering/`, `.kilocode/rules-*/`) before tool execution.

2. **Sequential Thinking Primary**: Use the `sequentialthinking` tool as the foundation for all complex tasks to ensure systematic reasoning.

3. **Use MCP Tools Over CLI**: Prefer MCP tools when available for better integration and structured output.

4. **Atomic Operations**: Execute one tool at a time and wait for success before proceeding.

5. **Schema Adherence**: Strictly follow the input schema for all tool calls.

6. **Store Decisions**: Use `memory` to store architectural decisions and patterns for future reference.

7. **Context Preservation**: Use `context7` for library documentation rather than guessing or using outdated resources.

8. **Error Analysis**: Use `sentry` for production error investigation to understand root causes.

## Integration with Development Workflow

### During Feature Development

1. **Plan**: Use `sequentialthinking` to break down the task
2. **Research**: Use `context7` to find relevant documentation
3. **Implement**: Use `filesystem` to read/write code, `shell` for build/test
4. **Validate**: Use `postgres` for database tests if applicable
5. **Commit**: Use `git` and `github` for version control
6. **Document**: Use `memory` to store decisions and patterns

### During Troubleshooting

1. **Investigate**: Use `sentry` for production issues, `brave-search` for documentation
2. **Analyze**: Use `sequentialthinking` for systematic problem-solving
3. **Test**: Use `shell` for debugging commands, `postgres` for database queries
4. **Fix**: Use `filesystem` to make changes
5. **Verify**: Use `puppeteer` for E2E tests if applicable

## Additional Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [MCP Servers Registry](https://github.com/modelcontextprotocol/servers)
- [Claude Code Documentation](https://docs.anthropic.com/)
- [VS Code MCP Extension](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-dev-vscode)
- [mcp-remote Wrapper](https://github.com/modelcontextprotocol/mcp-remote)

## Project-Specific Notes

### Flutter Development

- Flutter uses `filesystem` for code operations
- Use `context7` to look up Flutter package documentation
- Use `shell` to run `flutter analyze`, `flutter test`, `flutter build`
- Code formatting is automated via hooks (see `.claude/settings.json`)

### Backend Development

- Node.js services use `shell` for `npm` commands
- PostgreSQL operations use `postgres` MCP server
- Use `fetch` to test API endpoints
- Use `memory` to store backend architectural decisions

### CI/CD Integration

- GitHub workflows can be managed via `github` MCP server
- Use `git` for local version control
- Deployments can be triggered via `github` MCP server

### Security Considerations

- Never store secrets in MCP configurations
- Use environment variables for sensitive data
- Sentry MCP uses OAuth flow for secure authentication
- PostgreSQL credentials should be kept secure (use environment variables, not hardcoded)

---

**Last Updated**: February 18, 2026
