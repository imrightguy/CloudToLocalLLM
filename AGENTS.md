# CloudToLocalLLM - Agent Instructions

This file provides guidance for AI coding agents working in this repository.

## Build/Lint/Test Commands

### Flutter (Frontend)
```bash
# Install dependencies
flutter pub get

# Run app (Linux desktop)
flutter run -d linux

# Run app (Web)
flutter run -d chrome

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
flutter format .

# Build release
flutter build web --release
```

### Node.js (Backend Services)

#### Root/Backend
```bash
npm install           # Development (updates package.json)
npm ci                # Production builds (faster, more reliable)
npm run dev           # Development with nodemon
npm run test          # Run all tests
npm run test:unit     # Unit tests only
npm run test:integration  # Integration tests
npm run lint          # ESLint
npm run format        # Prettier
```

#### API Backend (`services/api-backend/`)
```bash
cd services/api-backend
npm install
npm run dev
npm run test
npm run test:unit             # Test/api-backend/
npm run test:integration      # Test/api-backend/
npm run test:security         # Security tests
npm run test:tunnel           # Tunnel tests
npm run test:user-isolation   # User isolation tests
npm run test:auth             # Auth tests
npm run test:security:verbose # Security tests with verbose output
npm run db:migrate            # Database migrations
npm run db:validate           # Validate migrations
npm run db:stats              # Migration stats
npm run db:test               # Test database connection
npm run lint                  # ESLint
npm run format                # Prettier
```

#### SDK (`services/sdk/`)
```bash
cd services/sdk
npm install
npm run build        # Build TypeScript to JavaScript
npm run dev          # Build with watch mode
npm run test         # Run Jest tests
npm run test:watch   # Run tests in watch mode
npm run lint         # ESLint on src/
npm run format       # Format source with Prettier
```

#### Streaming Proxy (`services/streaming-proxy/`)
```bash
cd services/streaming-proxy
npm install && npm run dev
npm run test
npm run lint         # ESLint
npm run format       # ESLint with auto-fix
```

#### Auth Backend (`backend/auth/`)
```bash
cd backend/auth
npm install && npm run dev
```

### Single Test Execution
```bash
# Run specific test file (Jest)
node --experimental-vm-modules ./node_modules/jest/bin/jest.js path/to/test.test.js

# Run with verbose output
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --verbose

# Run with coverage
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --coverage

# Run specific security test
npm run test:user-isolation  # User isolation tests
npm run test:auth           # Authentication tests
```

## CLI Tools Available

### Flutter CLI
- `flutter pub get` - Install Flutter dependencies
- `flutter run -d linux` - Run on Linux desktop
- `flutter run -d chrome` - Run on Chrome (Web)
- `flutter test` - Run Flutter tests
- `flutter analyze` - Analyze code for issues
- `flutter format .` - Format code
- `flutter build web --release` - Build web release

### Node.js/npm
- `npm install` - Install dependencies (dev mode)
- `npm ci` - Clean install (production mode)
- `npm run dev` - Start development server
- `npm test` - Run all tests
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier

### API Backend (`services/api-backend/`)
- `npm run start` - Start API backend server
- `npm run dev` - Start with nodemon for development
- `npm test` - Run all tests
- `npm run test:unit` - Run unit tests
- `npm run test:integration` - Run integration tests
- `npm run test:security` - Run security tests
- `npm run test:tunnel` - Run tunnel tests
- `npm run test:tunnel:unit` - Run tunnel unit tests
- `npm run test:tunnel:integration` - Run tunnel integration tests
- `npm run test:tunnel:security` - Run tunnel security tests
- `npm run test:user-isolation` - Run user isolation tests
- `npm run test:auth` - Run authentication tests
- `npm run test:security:verbose` - Run security tests with verbose output
- `npm run db:migrate` - Run database migrations
- `npm run db:validate` - Validate database migrations
- `npm run db:stats` - Show migration statistics
- `npm run db:test` - Test database connection
- `npm run db:setup-cloud-sql` - Setup Google Cloud SQL
- `npm run deploy:cloud-run` - Deploy to Google Cloud Run
- `npm run test:auth-flow` - Test authentication flow
- `npm run deploy:after-auth` - Deploy after auth setup
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier

### Streaming Proxy (`services/streaming-proxy/`)
- `npm run start` - Start proxy server
- `npm run health` - Run health check
- `npm run test-tunnel` - Test tunnel connection
- `npm run dev` - Start with inspect mode for debugging
- `npm test` - Run tests
- `npm run lint` - Run ESLint
- `npm run format` - Run ESLint with auto-fix

### SDK (`services/sdk/`)
- `npm run build` - Build TypeScript to JavaScript
- `npm run dev` - Build with watch mode
- `npm test` - Run Jest tests
- `npm run test:watch` - Run tests in watch mode
- `npm run lint` - Run ESLint on src/
- `npm run format` - Format source with Prettier
- `npm run prepublishOnly` - Build before publishing

### Auth Backend (`backend/auth/`)
- `npm run start` - Start auth handlers
- `npm run dev` - Start auth handlers with nodemon

### Single Test Execution (Jest)
```bash
# Run specific test file
node --experimental-vm-modules ./node_modules/jest/bin/jest.js path/to/test.test.js

# Run with verbose output
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --verbose

# Run with coverage
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --coverage
```

### Git
- `git status` - Show working tree status
- `git diff` - Show unstaged changes
- `git log` - Show commit history
- `git add .` - Stage all changes
- `git commit -m "message"` - Create commit

### Docker
- `docker build` - Build Docker image
- `docker run` - Run Docker container
- `docker-compose up` - Start services with docker-compose
- `docker-compose down` - Stop services

### GitHub CLI (gh)
- `gh auth login` - Authenticate with GitHub
- `gh pr create` - Create pull request
- `gh pr view` - View pull request details
- `gh pr list` - List pull requests
- `gh issue create` - Create issue
- `gh issue list` - List issues
- `gh repo view` - View repository information
- `gh release create` - Create release
- `gh workflow run` - Run GitHub Actions workflow

### Azure CLI (az)
- `az login` - Log in to Azure
- `az aks get-credentials --resource-group rg --name cluster` - Get kubeconfig
- `az group create` - Create resource group
- `az aks create` - Create AKS cluster
- `az acr list` - List container registries
- `az vm list-sizes` - List VM sizes

### kubectl
- `kubectl get pods` - List pods
- `kubectl get services` - List services
- `kubectl get deployments` - List deployments
- `kubectl apply -f file.yaml` - Apply configuration
- `kubectl delete -f file.yaml` - Delete resources
- `kubectl logs pod-name` - View pod logs
- `kubectl exec -it pod-name -- sh` - Execute command in pod
- `kubectl describe pod pod-name` - Describe pod details

### Helm
- `helm install release-name chart-path` - Install chart
- `helm upgrade release-name chart-path` - Upgrade release
- `helm uninstall release-name` - Uninstall release
- `helm list` - List releases
- `helm repo add repo-name url` - Add repository
- `helm search repo keyword` - Search repository
- `helm status release-name` - Show release status

### Cloudflare (cloudflare)
- `cloudflare zone list` - List zones
- `cloudflare dns record list` - List DNS records
- `cloudflare dns record create` - Create DNS record
- `cloudflare cache purge` - Purge cache

### MCP Tools - USE THESE EXTENSIVELY
- `auth0-*` - Auth0 management and configuration (NEW!)
- `mcp-sequentialthinking` - Structured problem-solving
- `mcp-context7` - Library documentation lookup
- `mcp-memory` - Knowledge graph storage
- `context7-*` - Library documentation and code examples
- `memory-*` - Knowledge graph management

## MCP Tools Installation & Usage

### Required MCP Tools for Agents - NOW AVAILABLE
```bash
# Run the setup script
./setup-opencode-mcp.sh

# Or install manually
cd ~/.config/opencode
npm install @modelcontextprotocol/server-sequential-thinking @upstash/context7-mcp @modelcontextprotocol/server-memory

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Available MCP Tools - USE THESE AS MUCH AS POSSIBLE

#### Auth0 Management Tools (NEW!)
- **auth0_list_applications**: List all Auth0 applications
- **auth0_get_application**: Get details about a specific Auth0 application
- **auth0_create_application**: Create a new Auth0 application
- **auth0_update_application**: Update an existing Auth0 application
- **auth0_list_resource_servers**: List all resource servers (APIs)
- **auth0_get_resource_server**: Get details about a specific resource server
- **auth0_create_resource_server**: Create a new resource server (API)
- **auth0_update_resource_server**: Update an existing resource server
- **auth0_list_actions**: List all Auth0 actions
- **auth0_get_action**: Get details about a specific action
- **auth0_create_action**: Create a new Auth0 action
- **auth0_update_action**: Update an existing Auth0 action
- **auth0_deploy_action**: Deploy an Auth0 action
- **auth0_list_logs**: List Auth0 tenant logs
- **auth0_get_log**: Get a specific log entry
- **auth0_list_forms**: List all Auth0 forms
- **auth0_get_form**: Get details about a specific form
- **auth0_create_form**: Create a new Auth0 form
- **auth0_update_form**: Update an existing Auth0 form

#### Library Documentation Tools
- **context7_resolve-library-id**: Resolve package names to Context7 library IDs
- **context7_query-docs**: Query up-to-date documentation and code examples

#### Knowledge Graph Tools
- **memory_create_entities**: Create new entities in knowledge graph
- **memory_create_relations**: Create relations between entities
- **memory_add_observations**: Add observations to existing entities
- **memory_delete_entities**: Remove entities from knowledge graph
- **memory_delete_observations**: Remove specific observations
- **memory_delete_relations**: Remove relations between entities
- **memory_read_graph**: Read entire knowledge graph
- **memory_search_nodes**: Search entities by query
- **memory_open_nodes**: Retrieve specific entities

#### Problem-Solving Tools
- **sequentialthinking**: Dynamic problem-solving through structured thinking process

## Code Style Guidelines

### Root Directory Preservation Protocol (RDPP)
**MANDATORY / ZERO TOLERANCE**
- DO NOT create new files/directories in repository root.
- Permitted root files: .gitignore, LICENSE, package.json, pubspec.yaml, README.md, CHANGELOG.md, Gemini.md, .kilocode/, .cursor/, .kiro/.
- Redirect outputs: docs/ for docs, config/ for configs, scripts/ for scripts, build-tools/ for tools.

### Single Source of Truth (SSOT)
- Centralize all documentation in docs/.
- Merge duplicates, use relative links.

### Knowledge Graph Protocol
- Query KG first before asking user or reading files.
- Update KG as you learn (architecture, preferences).

### Sequential Thinking Protocol
- Use sequential-thinking tool for complex tasks, architecture, debugging.
- Structure: Analyze, Plan, Execute, Reflect.

### MCP Tools Integration
- **MANDATORY**: USE MCP TOOLS AS MUCH AS POSSIBLE for all operations to enhance efficiency and accuracy.
- **Auth0 Operations**: Use auth0_* MCP tools for ALL Auth0 management tasks (applications, APIs, actions, logs, forms).
- Use memory tools for knowledge graph management and queries.
- Use sequentialthinking tool for complex reasoning and planning.
- Use context7 tools for library documentation and code examples (ensure API key is configured).
- Incorporate repository library tools (scripts/, lib/) wherever applicable for DevOps and utility tasks.
- Continuous monitoring: verify MCP tool functionality and update integrations as new tools emerge.

### Node.js (Express.js)

#### Imports & Dependencies
- Use ES modules (`"type": "module"` in package.json)
- Group imports: built-ins, third-party, local
- Use named imports for clarity

#### Error Handling Pattern
```javascript
try {
  const result = await someAsyncOperation();
  return result;
} catch (error) {
  logger.error('Operation failed', { error, context });
  throw new Error('User-friendly error message');
}
```

#### Logging
- Use `winston` for structured logging
- Include correlation IDs for request tracking
- Log levels: ERROR, WARN, INFO, DEBUG
- Never log secrets or user credentials (hash user IDs)

#### API Development
- Use Express middleware for authentication (`express-oauth2-jwt-bearer`)
- Implement proper CORS configuration
- Use Zod for input validation
- Return consistent error responses

#### Naming Conventions
- Files: `kebab-case.js`
- Classes: `PascalCase`
- Functions/variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- Async functions: suffix with `Async` when ambiguous

#### TypeScript Configuration
- Target: ES2020, Module: ESNext
- Strict mode enabled
- Declaration files generated
- Source maps enabled
- Use `tsc` for building, ESLint + Prettier for linting/formatting

### Flutter/Dart

#### Dependency Injection
- Use `GetIt` for service locator pattern
- Register services in `lib/di/locator.dart`
- Setup functions: `setupCoreServices()`, `setupAuthenticatedServices()`

#### State Management
- Use `provider` for simple state
- Complex state: consider other patterns

#### Web-Specific
- Use `dart:js_interop` (replaces deprecated `js` package)
- Platform detection: `kIsWeb` from `package:flutter/foundation.dart`
- Handle OAuth redirects properly

#### Code Quality
- Run `flutter analyze` before committing
- Use `flutter format` for consistent formatting
- Prefer `debugPrint()` over `print()` for logging

### Docker Container Security
- **NEVER run Flutter/Node.js as root**
- Use `USER 1000:1000` or container default UID before any application commands
- Multi-stage builds: build as root, run as non-root
- Layer caching: copy package files first, install deps, then copy source

### Free Tier Only Policy

**STRICTLY ENFORCED**: All cloud resources must stay within free tier limits. Non-compliance is not acceptable.

### Azure Free Tier Limits (Must Respect)
- **Compute**: Azure B-series VMs (B1s/B2s) within free monthly limits.
- **Kubernetes**: AKS Free Tier (Cluster management is free).
- **Databases**: Azure Database for PostgreSQL Flexible Server (Free Tier B1ms for 12 months).
- **Storage**: Managed Disks (P6 or smaller within free limits), Blob Storage.
- **Bandwidth**: First 100GB/month outbound is free.

### Prohibited Resources (Will Cause Charges)
- **NEVER create**: Standard SKU Load Balancers (Basic is free, or use NodePort/Ingress/Tunnel).
- **NEVER create**: Application Gateway or Azure Front Door (unless within credits).
- **NEVER create**: Azure Container Registry (ACR) unless Basic SKU and necessary (use GHCR).
- **NEVER create**: Premium SSDs or large Managed Disks.

### Required Pre-Creation Checks
Before creating any Azure resource:
1. Verify it has a free tier option.
2. Check current usage: `az consumption usage list`.
3. Use Azure Pricing Calculator.

### Post-Creation Validation
After any `az` command that creates resources:
```bash
# Verify no paid resources were created
az resource list --output table
```

### Free Tier Alternatives
| Paid Resource Type | Free Tier Alternative |
|-------------------|---------------------|
| AKS Standard LB | AKS Basic LB or Cloudflare Tunnel |
| ACR (Paid) | ghcr.io or Docker Hub |
| Large VMs | Standard_B2s / B1s |

### Violation Response
If charges are detected:
1. Immediately identify resource: `az consumption usage list --query "[?pretaxCost > '0'"`
2. Delete resource: `az resource delete --id <resource-id>`
3. Report violation and remediation

## Security Best Practices
- Never hardcode secrets, API keys, or credentials
- Use environment variables or secret management systems
- Validate and sanitize all user inputs
- Run containers as non-root users
- Use connection pooling for databases
- Implement request rate limiting

## Project Structure

```
CloudToLocalLLM/
├── lib/                  # Flutter app
│   ├── services/         # LLM providers, auth, tunnel services
│   ├── widgets/          # UI components
│   ├── di/               # Dependency injection (GetIt)
│   └── utils/            # Utilities
├── services/
│   ├── api-backend/      # Main API server
│   ├── streaming-proxy/  # WebSocket proxy
│   └── sdk/              # Client SDK
├── backend/
│   └── auth/             # Auth0 JWT validation
├── config/
│   └── mcp/              # MCP server configurations
├── docs/                 # Documentation
└── test/                 # Test files
```

## Git Workflow

- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- Keep commits focused and atomic
- Use agent prefix for automated commits: `ai(OpenCode): description`

## Key Files & Locations

- Flutter app: `lib/`, `pubspec.yaml`
- Node services: `services/api-backend/`, `backend/auth/`
- MCP configs: `config/mcp/`, `.vscode/settings.json`
- Auth: Auth0 (web uses JS bridge, desktop uses native flows)
- Local models: Ollama/LM Studio via OpenAI-compatible APIs

## Developer Tips

1. **Sequential Thinking**: Use for complex problem-solving, debugging, architectural tasks
2. **Context7**: Look up package docs, API patterns, best practices
3. **Memory**: Store project decisions and architectural notes
4. **Documentation-First**: Review relevant docs before coding
5. **Linting**: Always fix linter errors before committing
6. **Testing**: Fix failing tests before committing
7. **MCP Priority**: USE MCP TOOLS AS MUCH AS POSSIBLE - prefer over CLI commands for enhanced efficiency

## Copilot / AI Agent Operational Rules

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

Azure Cosmos DB Best Practices
- Model data to minimize cross-partition queries; prefer embedding for related data accessed together, but avoid large items (2 MB limit).
- Choose partition keys for high cardinality, common query patterns, and even distribution (e.g., userId, tenantId).
- Use latest SDK, enable retries/preferred regions, handle 429 errors, reuse clients.
- Use VS Code extension for inspection, emulator for local dev.
- Recommended for AI/chat apps, user/business apps, IoT (low-latency, scalable, multi-region).

AI Toolkit Guidelines
- `aitk-get_agent_code_gen_best_practices`: Best practices for AI agent development.
- `aitk-get_tracing_code_gen_best_practices`: Guidelines for tracing in AI apps.
- `aitk-get_ai_model_guidance`: Best practices for using AI models.
- `aitk-evaluation_planner`: Clarify metrics and datasets for evaluation.
- `aitk-get_evaluation_code_gen_best_practices`: Code gen for AI app evaluation.
- `aitk-evaluation_agent_runner_best_practices`: Guidance for using agent runners in evaluation.

## Additional Resources

- See `.cursor/rules/` for framework-specific guidelines
- See `.github/copilot-instructions.md` for AI agent operational rules
- See `docs/development/` for detailed development documentation
- See `.kilocode/rules/` for development guidelines and MCP tool usage
