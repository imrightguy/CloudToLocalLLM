# Claude Code Development Environment Setup

This directory contains configuration for Claude Code CLI development environment.

## Files

- `config.json` - MCP server configurations
- `settings.local.json` - Local permissions settings
- `../claude_code_dev_env.sh` - Shell aliases and functions

## Quick Setup

### 1. Enable MCP Servers

The MCP servers are configured in `.claude/config.json`. Some require setup:

#### GitHub MCP Server
```bash
# Set your GitHub token (required for creating PRs, issues, releases)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Or add to ~/.bashrc for persistence
echo 'export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"' >> ~/.bashrc
```

#### PostgreSQL MCP Server
Update the connection string in `.claude/config.json`:
```json
"postgres": {
  "command": "npx",
  "args": [
    "-y",
    "@modelcontextprotocol/server-postgres",
    "postgresql://username:password@localhost:5432/cloudtolocallm"
  ]
}
```

Get credentials from `services/api-backend/.env`:
```bash
grep DATABASE_URL services/api-backend/.env
```

#### Docker MCP Server
Ensure Docker is running:
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER  # Add user to docker group
```

### 2. Enable Shell Aliases

Add to your `~/.bashrc`:
```bash
source /mnt/data/dev/CloudToLocalLLM/claude_code_dev_env.sh
```

Or create a symlink:
```bash
ln -s /mnt/data/dev/CloudToLocalLLM/claude_code_dev_env.sh ~/.claude_code_env.sh
echo 'source ~/.claude_code_env.sh' >> ~/.bashrc
```

Then reload:
```bash
source ~/.bashrc
```

### 3. Install Optional Tools

These tools enhance development but aren't required:

```bash
# Better PostgreSQL CLI
pip install pgcli

# Terminal Git UI (on Arch Linux)
yay -S lazygit

# File watcher for development
cargo install watchexec

# Flutter version manager
dart pub global activate fvm
```

## Available MCP Tools

### GitHub (`github`)
- Create issues, pull requests, releases
- Manage repository settings
- Automate release workflows

### PostgreSQL (`postgres`)
- Direct database queries
- Schema inspection
- Data manipulation

### Docker (`docker`)
- Container management
- Log viewing
- Service control

### Fetch (`fetch`)
- Test API endpoints
- Debug backend services
- HTTP requests

### Puppeteer (`puppeteer`)
- Web testing
- Visual regression
- Automated browser actions

### Brave Search (`brave-search`)
- Documentation lookup
- Error debugging
- Web search

### Filesystem (`filesystem`)
- File operations
- Project navigation
- Code inspection

## Usage Examples

### Using GitHub MCP
```
Ask Claude: "Create a release for version 10.2.0 with the changelog from commits"
Ask Claude: "Open a PR for my-feature branch"
```

### Using PostgreSQL MCP
```
Ask Claude: "Show me all users in the database"
Ask Claude: "What's the schema of the tunnels table?"
```

### Using Docker MCP
```
Ask Claude: "Restart the streaming-proxy container"
Ask Claude: "Show logs from the api-backend container"
```

### Using Fetch MCP
```
Ask Claude: "Test the /api/health endpoint"
Ask Claude: "Send a POST request to /api/tunnels with this data"
```

## Troubleshooting

### MCP Server Not Starting
```bash
# Check if npx is available
which npx

# Test MCP server manually
npx -y @modelcontextprotocol/server-github

# Check Claude Code logs
cat ~/.claude/debug/*.log
```

### PostgreSQL Connection Failed
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Test connection
psql -U cloudtolocallm -d cloudtolocallm -h localhost

# Check connection string
grep DATABASE_URL services/api-backend/.env
```

### Docker Permission Denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for changes to take effect
```

### Shell Aliases Not Working
```bash
# Verify file is sourced
echo $CLOUD_TO_LOCAL_LLM_ROOT

# Should output: /mnt/data/dev/CloudToLocalLLM

# If empty, manually source
source /mnt/data/dev/CloudToLocalLLM/claude_code_dev_env.sh
```

## Development Workflow

### Typical Backend Development
```bash
# 1. Start database
docker-compose up -d postgres

# 2. Run migrations
db-migrate

# 3. Start backend in dev mode
api-dev

# 4. In Claude Code, test the API
# Ask: "Test the /api/health endpoint"
```

### Typical Flutter Development
```bash
# 1. Get dependencies
fp

# 2. Run on Linux
fw

# 3. In Claude Code, analyze code
# Ask: "Analyze the authentication flow in lib/services/"
```

### Full Stack Testing
```bash
# 1. Start all services
dcu

# 2. Run backend tests
api-test

# 3. Run Flutter tests
ft

# 4. In Claude Code, check test coverage
# Ask: "What's the test coverage for the API backend?"
```

## Customization

### Adding Custom MCP Servers

Edit `.claude/config.json`:
```json
{
  "mcpServers": {
    "my-custom-server": {
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {
        "API_KEY": "your-key"
      }
    }
  }
}
```

### Adding Custom Aliases

Edit `claude_code_dev_env.sh` and add:
```bash
alias mycommand='your-command-here'
```

Then reload:
```bash
source ~/.bashrc
```

## Security Notes

- Never commit actual credentials to version control
- Use environment variables for sensitive data
- The `config.json` file is in `.gitignore` (add if not present)
- GitHub tokens should have minimal required permissions
- Database credentials should match local development setup

## Additional Resources

- [Claude Code Documentation](https://claude.ai/code)
- [MCP Specification](https://modelcontextprotocol.io)
- [Flutter Docs](https://flutter.dev/docs)
- [Project CLAUDE.md](../CLAUDE.md)
