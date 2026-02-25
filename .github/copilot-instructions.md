# CloudToLocalLLM — Copilot / AI Agent Instructions (concise)

This file gives AI coding agents the actionable, repo-specific knowledge needed to be productive quickly. It focuses on architecture, key files, developer workflows, and integration points discovered in the workspace.

Core architecture (big picture)
- Frontend: Flutter app in `lib/` and `android/` — cross-platform (Windows, Linux, Web). Key pattern: `provider` + `GetIt` for DI.
- Backend/Tools: `services/` and `api/` contain Node.js services and MCP helpers. `config/mcp/` holds MCP server wiring used by local tooling.
- Data: PostgreSQL for server sessions (services), local SQLite/IndexedDB for client conversation storage.

Essential files & locations (start here)
- Frontend app: `lib/`, `pubspec.yaml`, `android/`, `windows/` folders.
- Node services: `services/` (look for `api-backend` and `server.js`).
- MCP configs: `config/mcp/` and repo-root `mcp.json` (workspace MCP server mapping).
- VS Code user MCP: user-level `mcp.json` lives at `%APPDATA%/Code/User/mcp.json` (we use this to add remote servers like Sentry).
- Workspace VS Code: `.vscode/settings.json` contains `mcpServers` and other agent mappings.

Developer workflows (commands you will use)
- Flutter dev: `flutter pub get`, `flutter run -d windows` / `-d chrome` (web), `flutter analyze`, `flutter test`.
- Backend dev: `npm install` then `npm run dev` in service folders (nodemon/watch common).
- MCP remote access (examples):
	- Direct (OAuth-enabled clients): add `{ "Sentry": { "url": "https://mcp.sentry.dev/mcp" } }` to `mcp.json` and let the client handle OAuth.
	- Legacy / wrapper: `npx -y mcp-remote@latest https://mcp.sentry.dev/mcp` — opens browser for OAuth and exposes a local STDIO bridge for clients that need it.

Project-specific conventions
- Commit messages: conventional form with agent prefix for automated commits (example: `ai(Cursor): update provider DI`). Keep small, focused commits.
- Formatting & lint: run `flutter format .`, `flutter analyze` before pushing; Node code: `eslint`, `npm audit`.
- DI pattern: `lib/di/locator.dart` registers services in `setupCoreServices()` and `setupAuthenticatedServices()` — prefer adding services via these functions.

Integration & cross-component notes
- Auth: Auth0 is used; web uses a JS bridge (`auth0-bridge.js`) while desktop uses native flows. See `auth_service.dart` and `auth0_*_service.dart`.
- Local models: Ollama/LM Studio integrations are in `lib/services/` and `llm_providers/`. They use OpenAI-compatible APIs; follow provider config in `provider_configuration.dart`.
- MCP servers: repo includes `config/mcp` and a workspace `mcp.json`. VS Code may also use a user `mcp.json`. Avoid editing user-level files in commits; add or update workspace `mcp.json` when you intend the team to share MCP server definitions.

AI-agent operational rules (must-follow)
- **Gemini** uses `x-ai/grok-code-fast-1` model for code generation and analysis.
- Use the `manage_todo_list` tool to claim, in-progress, and complete multi-step work. Update it as you progress.
- Respect `.cursor/rules/` and other agent steering files before making changes.
- Do not change unrelated files; keep edits minimal and scoped to the issue.
- If multiple agents may touch a file, create a feature branch and open a PR rather than pushing directly to `main`.

Examples (concrete snippets)
- Add Sentry remote (workspace `mcp.json`):
	```json
	{
		"Sentry": { "command": "npx", "args": ["-y","mcp-remote@latest","https://mcp.sentry.dev/mcp"] }
	}
	```

Troubleshooting notes
- If `mcp-remote` starts and you see `Unexpected end of JSON input`, it usually means the bridge started but no local client connected to STDIO — ensure your MCP-capable client (VS Code MCP extension or other) is configured to use the local proxy or use a direct `url` entry supporting OAuth.

Available MCP tools (workspace-configured, in `.vscode/settings.json`)
- **context7**: Library documentation and knowledge base retrieval — use to look up package docs, API patterns, best practices.
- **sequentialthinking**: Multi-step problem-solving tool — use for planning complex implementations, validating solutions.
- **memory**: Persistent knowledge store — use to track project decisions, architectural notes, and ongoing work across sessions.
- **Sentry (getsentry/sentry-mcp)**: Issue tracking and AI debugging — configured in user `mcp.json` to use `https://mcp.sentry.dev/mcp` with OAuth.

Agent MCP tools (built-in to the AI assistant):
- **Sentry tools**: Comprehensive issue tracking and debugging (analyze_issue_with_seer for root cause analysis, search_issues/events, get_issue_details, find_projects/organizations/releases/teams, get_trace_details, whoami).
- **Playwright tools**: Full browser automation suite (navigate, click, type, fill forms, take screenshots, handle dialogs, run code, network requests, console messages, tabs management, drag/drop, hover, press keys, wait for elements/text).

## Azure Cosmos DB Best Practices
- Model data to minimize cross-partition queries; prefer embedding for related data accessed together, but avoid large items (2 MB limit).
- Choose partition keys for high cardinality, common query patterns, and even distribution (e.g., userId, tenantId).
- Use latest SDK, enable retries/preferred regions, handle 429 errors, reuse clients.
- Use VS Code extension for inspection, emulator for local dev.
- Recommended for AI/chat apps, user/business apps, IoT (low-latency, scalable, multi-region).

## AI Toolkit Guidelines
- `aitk-get_agent_code_gen_best_practices`: Best practices for AI agent development.
- `aitk-get_tracing_code_gen_best_practices`: Guidelines for tracing in AI apps.
- `aitk-get_ai_model_guidance`: Best practices for using AI models.
- `aitk-evaluation_planner`: Clarify metrics and datasets for evaluation.
- `aitk-get_evaluation_code_gen_best_practices`: Code gen for AI app evaluation.
- `aitk-evaluation_agent_runner_best_practices`: Guidance for using agent runners in evaluation.

Where to look for more context
- `config/mcp/` and `config/mcp/servers/` — local server wiring (Auth0, DigitalOcean, Kubernetes, Docker, GitHub integrations)
- `.github/workflows/` — CI build and deploy flows (`build-release.yml`, `deploy-aks.yml`)
- `lib/` and `services/` — implementation surfaces for feature work

If anything's unclear or you'd like this shorter/longer, tell me which parts to expand (auth, MCP, Flutter dev, or CI). After your feedback I'll iterate.

**Last updated**: December 10, 2025
