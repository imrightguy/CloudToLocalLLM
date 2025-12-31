# MCP-Tools.md

## Available MCP Tools Inventory

### Core File Operations
- **delete_file**: Delete file/dir (irreversible, validated). Param: path (relative).
- **apply_diff**: Surgical edits with SEARCH/REPLACE blocks. Params: path, diff (exact match req.). Limitation: 100% match or fail.
- **read_file**: Read file(s) w/ line nums. Params: files array [{path}]. Example: read README.md (1-139 lines), Gemini.md (1-222).
- **write_to_file**: Complete write/overwrite. Params: path, content (full). Example: Rewrote Development_guidelines.md.
- **list_files**: List dir (recursive opt.). Params: path, recursive (bool). Example: \".\" false -> top-level files incl. Gemini.md.
- **search_files**: Regex search recursive. Params: path, regex (Rust), file_pattern opt. Example: (?i)(MCP|tool...) *.md -> 294 matches in docs/.

### Execution & Interaction
- **execute_command**: Run CLI cmd. Param: command. Example: `ls -la` executed (partial output due SIGINT).
- **browser_action**: Puppeteer browser. Params: action (launch/click..), url/coordinate etc. Not used.
- **ask_followup_question**: Clarify w/ suggestions. Params: question, follow_up (2-4 opts).

### Task Management
- **update_todo_list**: Markdown checklist. Param: todos string. Example: Multiple updates for eval task.
- **attempt_completion**: Submit final result. Param: result. Attempted once (interrupted).
- **switch_mode**: Change mode. Params: mode_slug, reason.
- **new_task**: Start subtask. Params: mode, message, todos opt.
- **fetch_instructions**: For create_mode/mcp_server.

## Usage Guidelines
- **Sequential**: One tool per step, wait for result.
- **KG Integration**: Update KG before/after major ops (explicit text).
- **Precision**: read_file before apply_diff.
- **Safety**: Workspace relative paths, user approval.
- **Efficiency**: Multiple tools parallel if independent; iterative for dependent.
- **sequentialThinking**: Prefix responses: 1.Analyze 2.Plan 3.Execute 4.KG Update 5.Reflect.

## Limitations
- Iterative (no batch).
- No compute/JSON parse native.
- File restrictions per mode (architect: .md$).
- Exec: New terminal, may truncate long output.
