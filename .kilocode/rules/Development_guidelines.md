# Development Guidelines

## Root Directory Preservation Protocol (RDPP)
**MANDATORY / ZERO TOLERANCE**

- DO NOT create new files/directories in repository root.
- Permitted root files: .gitignore, LICENSE, package.json, pubspec.yaml, README.md, CHANGELOG.md, Gemini.md, .kilocode/, .cursor/, .kiro/.
- Redirect outputs: docs/ for docs, config/ for configs, scripts/ for scripts, build-tools/ for tools.

## Single Source of Truth (SSOT)
- Centralize all documentation in docs/.
- Merge duplicates, use relative links.

## Knowledge Graph Protocol
- Query KG first before asking user or reading files.
- Update KG as you learn (architecture, preferences).

## Sequential Thinking Protocol
- Use sequential-thinking tool for complex tasks, architecture, debugging.
- Structure: Analyze, Plan, Execute, Reflect.

## CLI Strategy
- Prioritize WSL Ubuntu 24.04.
- No direct git; use github-mcp-server tools.
- Use wsl -d Ubuntu-24.04 for Linux tools.

## Additional Mandatory Guidelines
- Mandatory sequentialThinking in all commits/PRs
- KnowledgeGraph audits pre-merge
- Tool eval todos must complete before benchmarks
