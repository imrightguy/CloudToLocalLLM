# CLI-Tools.md

## Guidelines

- **MCP Priority**: Prefer MCP tools over CLI commands whenever possible for enhanced efficiency and accuracy.
- **Environment Awareness**: Check SYSTEM INFORMATION (Linux 6.12, zsh, /home/rightguy). Tailor commands.
- **Directory Handling**: Cannot cd workspace; prepend `cd path && cmd` for other dirs.
- **Complex Commands**: Prefer CLI over scripts for flexibility, but use repository scripts for consistency.
- **Active Terminals**: Check environment_details for running processes (e.g., no restart server).
- **Output Handling**: Assume success if no output; ask user for paste if needed.
- **Sandbox**: Use docker-compose for risky ops if applicable.
- **Logging**: Redirect to raw_output.json if long-running.
- **Repository Tools**: Incorporate scripts from scripts/ directory for DevOps tasks like deployment, monitoring, and setup.

## Examples from History
- `ls -la`: Executed in /home/rightguy/dev/CloudToLocalLLM, partial output (SIGINT).
- Benchmarks: ~1-2s response, reliable for ls/list, truncate for long.

## Best Practices
- Explain command purpose before execute_command.
- Interactive/long-running OK (VSCode terminal).
- New terminal per cmd, respects cwd changes.
