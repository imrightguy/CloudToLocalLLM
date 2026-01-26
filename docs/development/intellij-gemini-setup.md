# Gemini Settings for IntelliJ IDEA Community

This file contains the settings adapted for setup in IntelliJ IDEA Community.

## Development Guidelines

### Project Structure & Module Organization

- `lib/` contains the Flutter app (screens, services, widgets); `web/` holds Flutter web config; `assets/` stores static media and version metadata.
- `services/api-backend/` is the Node/Express API; `services/streaming-proxy/` handles the proxy runtime; `services/sdk/` ships client helpers; `services/postgres/` covers database support.
- `scripts/` and `build-tools/` manage packaging and installers; `infra/`, `k8s/`, and `config/` house deployment manifests and shared configuration.
- Tests: `test/` (unit/widget/integration plus Playwright helpers), backend Jest specs in `test/api-backend` and `services/api-backend/test`, and sample Playwright E2E in `e2e/`.

### Build, Test, and Development Commands

- Flutter: `flutter pub get`; dev web via `./run_dev.sh` (Chrome on :3000) or desktop with `flutter run -d linux`; format/lint using `dart format lib test` and `flutter analyze`.
- Flutter tests: `flutter test` for unit/widget; narrow scope with `flutter test test/widgets/widget_test.dart`.
- Backend (from `services/api-backend`): `npm install`, `npm run dev` (nodemon), `npm start`, `npm test`, and `npm test -- --coverage`.
- Playwright: `npx playwright install` once, then `npx playwright test e2e` for smoke checks.

### Coding Style & Naming Conventions

- Dart/Flutter: 2-space indent, `PascalCase` classes/widgets, `snake_case` files, prefer const widgets and typed services; document public APIs when behavior is non-obvious.
- JavaScript backend: ES modules (`import`/`export`), `camelCase` functions, `SCREAMING_SNAKE_CASE` env vars; keep middleware ordering explicit.
- Configuration comes from `.env` (copy `env.template`); do not commit secrets or generated binaries.

### Testing Guidelines

- Jest matches `**/test/**/*.test.js`; keep mocks local to specs and reset state per test.
- Flutter tests live in `test/` with `*_test.dart`; favor widget/golden coverage for UI and integration coverage for tunnel/auth flows.
- Add at least one automated check per feature and avoid regressing coverage on `services/**` (Jest collects from there).

### Commit & Pull Request Guidelines

- Use the conventional prefixes seen in history (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`); keep subjects imperative and under ~70 chars.
- PRs should include a short summary, how to run/verify (commands above), linked issue/ticket, and screenshots or logs for UX/back-end changes.
- Note configuration/env var changes or migrations in the PR and update `docs/` when user-facing behavior shifts.

### Security & Configuration Tips

- Rotate secrets via env vars; never hardcode DSNs or tokens in code or tests.
- Keep Sentry/remote calls toggleable via config, prefer localhost defaults for development, and avoid exposing debug ports publicly.

## MCP Tools Documentation

This document provides detailed documentation and usage guidelines for the Model Context Protocol (MCP) tools available in this environment.

### Table of Contents

- [Sequential Thinking](#sequential-thinking)
- [Playwright](#playwright)
- [Context7](#context7)
- [n8n MCP](#n8n-mcp)

---

## Sequential Thinking

**Server:** `sequentialthinking`
**Tool:** `sequentialthinking`

### Description

A detailed tool for dynamic and reflective problem-solving through thoughts. This tool helps analyze problems through a flexible thinking process that can adapt and evolve. Each thought can build on, question, or revise previous insights as understanding deepens.

### When to use this tool

- Breaking down complex problems into steps
- Planning and design with room for revision
- Analysis that might need course correction
- Problems where the full scope might not be clear initially
- Problems that require a multi-step solution
- Tasks that need to maintain context over multiple steps
- Situations where irrelevant information needs to be filtered out

### Key features

- You can adjust total_thoughts up or down as you progress
- You can question or revise previous thoughts
- You can add more thoughts even after reaching what seemed like the end
- You can express uncertainty and explore alternative approaches
- Not every thought needs to build linearly - you can branch or backtrack
- Generates a solution hypothesis
- Verifies the hypothesis based on the Chain of Thought steps
- Repeats the process until satisfied
- Provides a correct answer

### Parameters

- `thought` (string, required): Your current thinking step, which can include:
  - Regular analytical steps
  - Revisions of previous thoughts
  - Questions about previous decisions
  - Realizations about needing more analysis
  - Changes in approach
  - Hypothesis generation
  - Hypothesis verification
- `nextThoughtNeeded` (boolean, required): True if you need more thinking, even if at what seemed like the end
- `thoughtNumber` (integer, required): Current number in sequence (can go beyond initial total if needed)
- `totalThoughts` (integer, required): Current estimate of thoughts needed (can be adjusted up/down)
- `isRevision` (boolean, optional): A boolean indicating if this thought revises previous thinking
- `revisesThought` (integer, optional): If is_revision is true, which thought number is being reconsidered
- `branchFromThought` (integer, optional): If branching, which thought number is the branching point
- `branchId` (string, optional): Identifier for the current branch (if any)
- `needsMoreThoughts` (boolean, optional): If reaching end but realizing more thoughts needed

### Example

```json
{
  "thought": "I need to analyze the user's request and break it down into steps.",
  "nextThoughtNeeded": true,
  "thoughtNumber": 1,
  "totalThoughts": 3
}
```

---

## Playwright

**Server:** `playwright`

### Description

Provides browser automation capabilities for testing, scraping, and interacting with web pages.

### Key Tools

- `browser_navigate`: Navigate to a URL.
- `browser_click`: Click an element.
- `browser_type`: Type text into an input field.
- `browser_take_screenshot`: Capture a screenshot of the page.
- `browser_evaluate`: Execute JavaScript on the page.

### Usage

Use this tool for:

- End-to-end testing of web applications.
- Verifying UI elements and interactions.
- Automating browser-based tasks.

### Example (Navigate)

```json
{
  "url": "https://example.com"
}
```

---

## Context7

**Server:** `context7`

### Description

Retrieves up-to-date documentation and code examples for libraries and frameworks.

### Key Tools

- `resolve-library-id`: Find the correct library ID for a given name.
- `get-library-docs`: Fetch documentation for a specific library.

### Usage

Use this tool when you need:

- Accurate API references.
- Code examples for specific libraries.
- To understand how to use a third-party package.

### Workflow

1. Call `resolve-library-id` with the library name.
2. Use the returned `context7CompatibleLibraryID` to call `get-library-docs`.

### Example (Get Docs)

```json
{
  "context7CompatibleLibraryID": "/vercel/next.js",
  "mode": "code",
  "topic": "routing"
}
```

---

## n8n MCP

**Server:** `n8n-mcp`

### Description

Integrates with n8n for workflow automation, allowing you to manage workflows, nodes, and executions.

### Key Tools

- `list_workflows`: List available workflows.
- `n8n_get_workflow`: Retrieve details of a specific workflow.
- `n8n_trigger_webhook_workflow`: Trigger a workflow via webhook.
- `list_nodes`: List available n8n nodes.

### Usage

Use this tool to:

- Automate complex tasks using n8n workflows.
- Manage and monitor n8n executions.
- Integrate external services via n8n nodes.

### Example (List Workflows)

```json
{
  "limit": 10,
  "active": true
}
```

## MCP Settings

The MCP settings configured for the project:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "node",
      "args": ["E:/dev/CloudToLocalLLM/mcp-playwright-server/build/index.js"]
    }
  }
}
```

## Setup Instructions for IntelliJ IDEA Community

1. Download and install IntelliJ IDEA Community Edition from the official JetBrains website.

2. Install the Flutter plugin:
   - Open IntelliJ IDEA.
   - Go to File > Settings > Plugins.
   - Search for "Flutter" and install it.
   - Restart IntelliJ if prompted.

3. Open the project:
   - File > Open.
   - Select the project directory (E:/dev/CloudToLocalLLM).

4. Configure Flutter SDK:
   - In the project, IntelliJ should detect Flutter.
   - If not, go to File > Settings > Languages & Frameworks > Flutter and set the Flutter SDK path.

5. For AI assistance:
   - IntelliJ has built-in AI features via JetBrains AI.
   - To replicate MCP-like functionality, you may need to configure MCP servers if JetBrains supports it.
   - Check Settings > Tools > AI Assistant > MCP Servers to add servers.
   - Since the MCP settings are empty, no servers are configured. You may need to install and configure MCP servers separately if desired.

6. Follow the Development Guidelines above for coding standards and project structure.

Note: Gemini CLI is the standard tool for this project. IntelliJ IDEA has its own AI and plugin ecosystem. The rules and guidelines have been copied for consistency.
