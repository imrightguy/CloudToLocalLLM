# Claude Code Automation Setup

Automations configured for CloudToLocalLLM codebase.

## ✅ Configured

### 🔌 MCP Servers

#### context7
- **Purpose**: Live documentation lookup for Flutter, Node.js, Auth0, LangChain
- **Config**: `.claude/settings.json`
- **Status**: Ready to use

#### Sentry
- **Purpose**: Error investigation and stack trace analysis
- **Config**: `.claude/settings.json`
- **Status**: Ready to use

### 🎯 Skills

#### api-endpoint
- **Purpose**: Generate Express.js API endpoints with Auth0 JWT middleware
- **Location**: `.claude/skills/api-endpoint/SKILL.md`
- **Invocation**: `/api-endpoint` (user-only)
- **Usage**: `/api-endpoint feature=user-management`

#### flutter-service
- **Purpose**: Generate Flutter services with Provider pattern
- **Location**: `.claude/skills/flutter-service/SKILL.md`
- **Invocation**: `/flutter-service` (user-only)
- **Usage**: `/flutter-service feature=tunnel-management`

### ⚡ Hooks

#### Auto-Format on Edit
- Flutter Dart files: `flutter format` runs automatically
- Node.js files: `npm run format` runs automatically
- **Status**: Active

#### Block Sensitive Files
- Blocks edits to `*.secret.yaml`
- Blocks edits to `.env.production`
- Warns on `.env` edits
- Blocks edits to `seets/` directories
- Blocks edits to `*.key` files
- **Status**: Active

### 🤖 Subagents

#### security-reviewer
- **Purpose**: Review code for Auth0, Stripe, SSH, and database security issues
- **Location**: `.claude/agents/security-reviewer.md`
- **Focus**:
  - JWT token handling
  - Payment security
  - SSH tunneling
  - SQL injection
  - XSS prevention
  - Encryption

#### integration-tester
- **Purpose**: Generate integration tests for services and endpoints
- **Location**: `.claude/agents/integration-tester.md`
- **Focus**:
  - Flutter service tests
  - Express.js endpoint tests
  - Authentication tests
  - Error handling tests

### 📦 Plugin

#### anthropic-agent-skills
- **Status**: Manual installation recommended
- **Install**: `claude plugin install anthropic-agent-skills`
- **Includes**:
  - `commit` - Conventional commits
  - `feature-dev` - Feature planning
  - `frontend-design` - UI generation

## 🚀 Quick Start

### Using Skills

```bash
# Generate a new API endpoint
/api-endpoint feature=subscription-management

# Generate a new Flutter service
/flutter-service feature=tunnel-monitoring
```

### Using Subagents

Subagents are automatically invoked by Claude when:
- Reviewing security-sensitive code
- Generating tests for new features
- Analyzing authentication/payment flows

### MCP Servers

Context7 and Sentry are now available in all Claude sessions:
- Ask about Auth0 Flutter docs
- Query Sentry issues
- Get LangChain API examples

## 📝 Configuration Files

- `.claude/settings.json` - Hooks, permissions, MCP servers
- `.claude/skills/*/SKILL.md` - Skill definitions
- `.claude/agents/*.md` - Subagent templates

## 🔧 Manual Installation Required

### Plugin Installation

```bash
claude plugin install anthropic-agent-skills
```

### Prerequisites for MCP Servers

1. **GitHub CLI** (for gh commands in permissions):
   ```bash
   # Already installed based on active permissions
   ```

2. **Node.js** (for MCP servers):
   ```bash
   # Already installed (Node.js 22+)
   ```

## 📊 Automation Coverage

| Category | Automated | Notes |
|----------|-----------|-------|
| Code formatting | ✅ | Auto-format on edit |
| Sensitive file protection | ✅ | Pre-edit hooks |
| Documentation lookup | ✅ | Context7 MCP |
| Error investigation | ✅ | Sentry MCP |
| Security review | ✅ | Subagent |
| Test generation | ✅ | Subagent |
| API scaffolding | ✅ | Skill |
| Service scaffolding | ✅ | Skill |

## 🎯 Recommended Workflow

1. **New Feature**: Use `/feature-dev` skill to plan
2. **Create Service**: Use `/flutter-service` to scaffold
3. **Create Endpoint**: Use `/api-endpoint` to scaffold
4. **Security Review**: Subagent auto-invokes on auth/payment code
5. **Generate Tests**: Subagent auto-invokes on new code
6. **Format**: Auto-applies on save
7. **Commit**: Use `/commit` skill (after plugin install)

## 🔍 Verifying Setup

Test your automations:

```bash
# Test auto-format
echo "test" > test.dart
# Edit the file - should auto-format

# Test sensitive file blocking
# Try editing .env.production - should be blocked

# Test skills
/flutter-service feature=test-service

# Test MCP servers
# Ask: "How do I configure Auth0 JWT middleware?" (uses context7)
```

## 📚 Documentation

- CLAUDE.md - Project-specific guidance
- `.claude/SETUP.md` - Original Claude setup
- `.claude/agents/*.md` - Subagent documentation
- `.claude/skills/*/SKILL.md` - Skill documentation

## 🆘 Troubleshooting

### MCP Servers Not Working
- Check Node.js version: `node --version` (should be 22+)
- Verify settings.json syntax
- Restart Claude Code

### Hooks Not Firing
- Check `.claude/settings.json` permissions
- Verify patterns match file paths
- Check command syntax

### Skills Not Appearing
- Verify SKILL.md files exist
- Check YAML frontmatter syntax
- Restart Claude Code

---

**Generated**: 2025-02-09
**Codebase**: CloudToLocalLLM
**Automations**: 8 configured
