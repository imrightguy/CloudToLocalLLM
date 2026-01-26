# Tools Inventory: MCP and CLI Comparison

This document provides a comprehensive audit of all available tools within both the Model Context Protocol (MCP) framework and the command-line interface (CLI) environment for the CloudToLocalLLM project.

## 1. MCP Servers Configuration

### 1.1 Connected MCP Servers

The following MCP servers are currently configured and connected to this session:

#### 1.1.1 Context7 Server (`@upstash/context7-mcp`)

**Configuration:**

```json
{
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp"],
  "env": {"DEFAULT_MINIMUM_TOKENS": ""},
  "alwaysAllow": ["resolve-library-id", "query-docs"]
}
```

**Available Tools:**
| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `mcp--context7--resolve-library-id` | Resolves a package/product name to a Context7-compatible library ID | `libraryName`: string, `query`: string | Library ID, name, description, code snippets count, source reputation, benchmark score |
| `mcp--context7--query-docs` | Retrieves and queries up-to-date documentation and code examples | `libraryId`: string, `query`: string | Documentation content, code examples, source URLs |

**Trust Settings:** Both tools are in the `alwaysAllow` list, meaning they don't require user confirmation for execution.

**Dependencies:** Requires API key configuration in environment variables. Currently non-functional due to missing API key.

**Setup Requirements:**

- Configure `CONTEXT7_API_KEY` environment variable
- Can be set in `.kilocode/mcp.json` env section

#### 1.1.2 Memory Server (`@modelcontextprotocol/server-memory`)

**Configuration:**

```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"],
  "alwaysAllow": ["create_entities", "create_relations", "add_observations", "delete_entities", "delete_observations", "delete_relations", "read_graph", "search_nodes", "open_nodes"]
}
```

**Available Tools:**
| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `mcp--memory--create_entities` | Create multiple new entities in the knowledge graph | `entities`: array of {name, entityType, observations} | Success confirmation |
| `mcp--memory--create_relations` | Create multiple new relations between entities | `relations`: array of {from, relationType, to} | Success confirmation |
| `mcp--memory--add_observations` | Add new observations to existing entities | `observations`: array of {entityName, contents} | Updated entity data |
| `mcp--memory--delete_entities` | Delete multiple entities and their relations | `entityNames`: array of strings | Success confirmation |
| `mcp--memory--delete_observations` | Delete specific observations from entities | `deletions`: array of {entityName, observations} | Success confirmation |
| `mcp--memory--delete_relations` | Delete multiple relations | `relations`: array of {from, relationType, to} | Success confirmation |
| `mcp--memory--read_graph` | Read the entire knowledge graph | None | All entities and relations |
| `mcp--memory--search_nodes` | Search for nodes in the knowledge graph | `query`: string | Matching entities |
| `mcp--memory--open_nodes` | Open specific nodes by their names | `names`: array of strings | Entity details |

**Trust Settings:** All tools are in the `alwaysAllow` list.

**Resource Requirements:** Low - stores data in memory, limited to current session unless persisted externally.

#### 1.1.3 Sequential Thinking Server (`@modelcontextprotocol/server-sequential-thinking`)

**Configuration:**

```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
  "alwaysAllow": ["sequentialthinking"]
}
```

**Available Tools:**
| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `mcp--sequentialthinking--sequentialthinking` | Structured chain-of-thought for complex tasks | `thought`: string, `nextThoughtNeeded`: boolean, `thoughtNumber`: number, `totalThoughts`: number, `isRevision`: boolean, `revisesThought`: number, `branchFromThought`: number, `branchId`: string, `needsMoreThoughts`: boolean | Thought analysis, solution hypothesis, verification results |

**Trust Settings:** Tool is in the `alwaysAllow` list.

**Best Practices:**

- Use for complex tasks, architecture planning, debugging
- Structure: Analyze, Plan, Execute, Reflect
- Mandatory sequentialThinking in all commits/PRs

#### 1.1.4 Playwright Server (`@playwright/mcp@0.0.38`)

**Configuration:** Mentioned in documentation but not currently in `.kilocode/mcp.json`

**Available Tools:**
| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `playwright_navigate` | Navigate to a URL | `url`: string | Navigation result |
| `playwright_screenshot` | Take a screenshot | `selector`: string (optional) | Screenshot data |
| `playwright_click` | Click on an element | `selector`: string | Click result |
| `playwright_assert` | Make assertions | `assertion`: string, `value`: any | Assertion result |

**Setup Requirements:**

- Run `npx playwright install` to set up browsers
- Run `npx playwright test` to execute tests
- Reference: `docs/development/MCP_TOOLS_SETUP.md`, `test/e2e/*.spec.js`

## 2. Native MCP Tools (Kilo Code Core)

### 2.1 Core File Operations

| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `delete_file` | Delete file/dir (irreversible, validated) | `path`: string (relative) | Success/failure |
| `search_and_replace` | Surgical edits with SEARCH/REPLACE blocks | `path`: string, `operations`: array of {search, replace} | Edit confirmation |
| `read_file` | Read file(s) with line numbers | `files`: array of {path} | File contents with line numbers |
| `write_to_file` | Complete write/overwrite | `path`: string, `content`: string | Success confirmation |
| `list_files` | List directory contents | `path`: string, `recursive`: boolean | Directory listing |
| `search_files` | Regex search recursive | `path`: string, `regex`: string, `file_pattern`: string (optional) | Search results with context |
| `codebase_search` | Semantic search across workspace | `query`: string, `path`: string (optional) | Relevant code files |

### 2.2 Execution & Interaction

| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `execute_command` | Run CLI command | `command`: string, `cwd`: string (optional) | Command output, exit code |
| `browser_action` | Puppeteer browser automation | `action`: string, `url`: string, `coordinate`: array | Browser interaction result |
| `ask_followup_question` | Clarify with suggestions | `question`: string, `follow_up`: array of {text, mode} | User response |

### 2.3 Task Management

| Tool Name | Description | Parameters | Return Values |
|-----------|-------------|------------|---------------|
| `update_todo_list` | Markdown checklist | `todos`: string | Updated todo list |
| `attempt_completion` | Submit final result | `result`: string | Completion confirmation |
| `switch_mode` | Change mode | `mode_slug`: string, `reason`: string | Mode switch confirmation |
| `new_task` | Start subtask | `mode`: string, `message`: string, `todos`: string | Task creation |
| `fetch_instructions` | Retrieve task instructions | `task`: "create_mcp_server" or "create_mode" | Instructions content |

## 3. CLI Tools Available

### 3.1 System Tools

| Command | Version | Primary Function | Dependencies | Common Usage |
|---------|---------|------------------|--------------|--------------|
| `node` | v24.12.0 | JavaScript runtime | None | `node script.js` |
| `npm` | 11.7.0 | Node package manager | Node.js | `npm install`, `npm run dev` |
| `npx` | 11.7.0 | Execute npm packages | Node.js, npm | `npx package-name` |
| `python3` | 3.13.11 | Python interpreter | None | `python3 script.py` |
| `pip3` | - | Python package manager | Python3 | `pip3 install package` |
| `git` | 2.52.0 | Version control | None | `git commit`, `git push` |
| `curl` | - | HTTP client | None | `curl url`, `curl -X POST` |
| `wget` | - | Download files | None | `wget url` |
| `jq` | - | JSON processor | None | `jq '.key' file.json` |

### 3.2 Global NPM Packages

| Package | Version | Primary Function | Dependencies |
|---------|---------|------------------|--------------|
| `@google/gemini-cli` | 0.23.0 | Gemini CLI integration | Node.js |
| `node-gyp` | 12.1.0 | Node.js native addon build tool | Node.js, Python, make |
| `nopt` | 7.2.1 | Option parsing | Node.js |
| `npm` | 11.7.0 | Node package manager | Node.js |
| `semver` | 7.7.3 | Semantic version parsing | Node.js |

### 3.3 Development Tools in PATH

| Tool | Location | Version | Primary Function |
|------|----------|---------|------------------|
| `flutter` | `/home/rightguy/dev/flutter/bin` | - | Flutter SDK |
| `zsh` | `/usr/bin/zsh` | - | Shell |

### 3.4 Shell Built-ins

Available through `compgen -b`:

- `:` - Null command
- `.` - Source file
- `bg` - Background job
- `bind` - Key binding
- `break` - Exit loop
- `builtin` - Builtin command
- `cd` - Change directory
- `command` - Execute command
- `continue` - Continue loop
- `declare` - Variable declaration
- `echo` - Print text
- `enable` - Enable/disable builtins
- `eval` - Evaluate command
- `exec` - Execute command
- `exit` - Exit shell
- `export` - Export variable
- `fc` - Fix command
- `fg` - Foreground job
- `getopts` - Option parsing
- `hash` - Remember command
- `history` - Command history
- `jobs` - List jobs
- `kill` - Send signal
- `let` - Arithmetic
- `local` - Local variable
- `logout` - Exit shell
- `popd` - Pop directory
- `printf` - Formatted print
- `pushd` - Push directory
- `pwd` - Print working directory
- `read` - read_file input
- `readonly` - read_file-only variable
- `return` - Return from function
- `select` - Menu selection
- `set` - Set options
- `shift` - Shift arguments
- `suspend` - Suspend shell
- `test` - Conditional test
- `times` - Print times
- `trap` - Signal handling
- `true` - True command
- `typeset` - Variable declaration
- `ulimit` - Set limits
- `umask` - Set file mask
- `unalias` - Remove alias
- `unset` - Remove variable
- `wait` - Wait for jobs

## 4. Cross-Reference Analysis

### 4.1 Redundant Functionalities

| MCP Tool | CLI Equivalent | Comparison |
|----------|----------------|------------|
| `read_file` | `cat`, `less` | MCP tool provides structured output with line numbers, better for programmatic use |
| `list_files` | `ls` | MCP tool can do recursive listing with simple boolean parameter |
| `search_files` | `grep`, `ripgrep` | MCP tool uses Rust regex, provides context-rich results |
| `execute_command` | Shell execution | Both execute commands, MCP provides better integration with workspace |
| `search_and_replace` | `sed`, `ed` | MCP tool provides safer, validated edits with exact match requirement |

### 4.2 Complementary Features

| MCP Tool | CLI Tool | Use Case |
|----------|----------|----------|
| `mcp--context7--query-docs` | `curl`, `wget` | MCP provides curated, up-to-date documentation; CLI fetches raw content |
| `mcp--memory--*` | `git` | MCP manages session knowledge; git manages version history |
| `mcp--sequentialthinking--sequentialthinking` | `man`, `help` | MCP provides structured reasoning; CLI provides reference documentation |

### 4.3 Integration Opportunities

1. **Documentation Workflow:**
   - Use `mcp--context7--query-docs` to get relevant code examples
   - Use `read_file` to examine local files
   - Use `search_and_replace` to implement changes
   - Use `execute_command` to test changes

2. **Knowledge Management:**
   - Use `mcp--memory--create_entities` to track discovered information
   - Use `mcp--memory--search_nodes` to query previous findings
   - Use `codebase_search` to find related code

3. **Testing & Validation:**
   - Use `playwright_navigate` and `playwright_screenshot` for web UI testing
   - Use `execute_command` to run test suites
   - Use `search_and_replace` to fix test failures

### 4.4 Performance Comparison

| Operation | MCP Tool | CLI Tool | Recommendation |
|-----------|----------|----------|----------------|
| File reading | `read_file` | `cat`, `less` | Use MCP for structured output |
| Directory listing | `list_files` | `ls` | Use MCP for recursive capability |
| Text search | `search_files` | `grep` | Use MCP for context-rich results |
| Documentation lookup | `mcp--context7--query-docs` | `curl` | Use MCP for curated examples |
| Command execution | `execute_command` | Direct shell | Use MCP for workspace integration |

## 5. Tool Selection Guidelines

### 5.1 When to Use MCP Tools

- **File Operations:** Always prefer `read_file`, `list_files`, `search_files`, `search_and_replace` over CLI equivalents
- **Documentation:** Use `mcp--context7--query-docs` for library documentation
- **Knowledge Management:** Use `mcp--memory--*` tools for tracking session information
- **Complex Reasoning:** Use `mcp--sequentialthinking--sequentialthinking` for architectural decisions
- **Web Testing:** Use `playwright_navigate`, `playwright_screenshot` when configured

### 5.2 When to Use CLI Tools

- **Package Management:** Use `npm`, `pip3` for dependency installation
- **Version Control:** Use `git` for source code management
- **Network Operations:** Use `curl`, `wget` for HTTP requests and downloads
- **Data Processing:** Use `jq` for JSON manipulation
- **Shell Operations:** Use built-ins for shell scripting

### 5.3 Environment-Specific Considerations

**Shell Configuration:**

- Current shell: `/usr/bin/zsh`
- Configuration files: `~/.zshrc`, `~/.zshenv`
- Key environment variables: `PATH` includes flutter, npm packages

**Project-Specific Tools:**

- Flutter SDK: `/home/rightguy/dev/flutter/bin`
- Node.js packages: Global packages in `/usr/lib/node_modules`
- Project dependencies: Listed in `package.json`

## 6. Security Considerations

### 6.1 MCP Tool Trust Settings

**Always Allowed (No Confirmation Required):**

- File operations: `read_file`, `list_files`, `search_files`
- Documentation tools: `mcp--context7--resolve-library-id`, `mcp--context7--query-docs`
- Knowledge graph: All `mcp--memory--*` tools
- Reasoning: `mcp--sequentialthinking--sequentialthinking`

**Requiring Confirmation (if any):**

- `delete_file` - File deletion is validated
- `execute_command` - Command execution may require approval

### 6.2 Resource Requirements

| Tool Category | Resource Impact | Notes |
|---------------|-----------------|-------|
| MCP servers | Low - runs via npx | Context7 may require API calls |
| Memory server | Minimal | In-memory storage |
| File operations | Low | Workspace-relative paths |
| Command execution | Variable | Depends on command |

## 7. Setup and Configuration

### 7.1 MCP Configuration

**Location:** `.kilocode/mcp.json`

**Current Configuration:**

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {"DEFAULT_MINIMUM_TOKENS": ""},
      "alwaysAllow": ["resolve-library-id", "query-docs"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "alwaysAllow": ["create_entities", "create_relations", "add_observations", "delete_entities", "delete_observations", "delete_relations", "read_graph", "search_nodes", "open_nodes"]
    },
    "sequentialthinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "alwaysAllow": ["sequentialthinking"]
    }
  }
}
```

### 7.2 Required Setup Steps

1. **Context7 API Key:**
   - Obtain API key from Context7 service
   - Add to environment: `export CONTEXT7_API_KEY="your-key"`
   - Or configure in `.kilocode/mcp.json` env section

2. **Playwright Setup:**
   - Run: `npx playwright install`
   - Configure browsers for testing
   - Reference: `docs/development/MCP_TOOLS_SETUP.md`

3. **Shell Configuration:**
   - Ensure `~/.zshrc` is sourced for prompt and environment
   - Flutter SDK is already in PATH via `~/.zshenv`

## 8. Recommendations

### 8.1 Immediate Actions

1. **Configure Context7 API Key:**
   - Add API key to environment or MCP configuration
   - This will enable full documentation lookup capabilities

2. **Enable Playwright MCP:**
   - Add playwright configuration to `.kilocode/mcp.json`
   - Run `npx playwright install` to set up browsers
   - This will enable web testing capabilities

### 8.2 Future Enhancements

1. **Add GitHub MCP Server:**
   - For direct git operations without CLI
   - Enable better integration with GitHub workflows

2. **Add Filesystem MCP Server:**
   - For enhanced file operations across the system
   - Beyond workspace-relative operations

3. **Custom MCP Servers:**
   - The project has custom MCP servers in `config/mcp/servers/`
   - Consider adding ArgoCD, Kubernetes, Node.js, Flutter servers

---

**Last Updated:** 2026-01-07
**Document Version:** 1.0.0
