# AGENTS.md

This file provides guidance to agents working on **CloudToLocalLLM** — OpenClaw Agent Manager.

## Project Vision

CloudToLocalLLM is an **OpenClaw Agent Manager** with five core pillars:
1. **Chat** — Unified chat interface with streaming responses, conversation history, and multi-model support
2. **OpenClaw Gateway Management** — Start, stop, monitor OpenClaw (localhost:18789)
3. **Evolving Avatar** — Visual 2D/3D character with growing personality
4. **Desktop Control** — GUI automation + system integration
5. **Vision** — Screen capture and camera input, powered by OpenClaw

---

## Build / Lint / Test Commands

### Flutter (Frontend)

```bash
# Install dependencies
flutter pub get

# Run applications
flutter run -d linux          # Linux desktop
flutter run -d windows        # Windows desktop
flutter run -d chrome         # Web (Chrome)
flutter run -d edge           # Web (Edge)

# Run tests
flutter test                   # Run all tests
flutter test test/widget_test.dart  # Run single test file
flutter test integration_test/auth_test.dart  # Integration test

# Code quality (REQUIRED before commit)
flutter analyze               # Must pass with no errors
flutter format .              # Must pass

# Build
flutter build linux --release    # Linux desktop
flutter build web --release      # Web
flutter build windows --release  # Windows
flutter build apk               # Android APK
```

### Backend Services

All backend services are in `services/`:

#### API Backend (Express.js) - `services/api-backend/`
```bash
npm install
npm run dev                    # Development with nodemon
npm start                      # Production start
npm test                       # Run all tests (with ES modules flag)
node --experimental-vm-modules node_modules/jest/bin/jest.js path/to/test.test.js

# Specific test suites
npm run test:unit              # Unit tests only
npm run test:auth              # Authentication tests
npm run test:security          # Security tests
npm run test:tunnel            # Tunnel tests
npm run test:tunnel:unit       # Tunnel unit tests
npm run test:tunnel:security   # Tunnel security tests
npm run test:user-isolation     # User isolation tests

# Database operations
npm run db:migrate             # Run PostgreSQL migrations
npm run db:validate            # Validate schema
npm run db:stats               # Database statistics
npm run db:test                # Test database connection
npm run db:setup-cloud-sql     # Setup Cloud SQL

# Code quality
npm run lint                   # ESLint
npm run format                 # Prettier

# Deployment
npm run deploy:cloud-run       # Deploy to Google Cloud Run
npm run test:auth-flow         # Test authentication flow
```

#### Streaming Proxy (TypeScript/Express) - `services/streaming-proxy/`
```bash
npm install
npm run dev                    # Development with inspect
npm start                      # Production start
npm test                       # Run Jest tests
npm run build                  # TypeScript compilation
npm run lint                   # ESLint
npm run format                 # ESLint with fix
npm health                     # Health check
npm test-tunnel                # Test tunnel functionality
```

#### SDK (TypeScript) - `services/sdk/`
```bash
npm install
npm run build                  # TypeScript compilation
npm run dev                    # Watch mode
npm test                       # Run Jest tests
npm run test:watch             # Jest in watch mode
npm run lint                   # ESLint
npm run format                 # Prettier
```

### LLM Router (Flutter Embedded Server)

The Flutter app runs an embedded HTTP server on port 1337:

```bash
# Router runs automatically on app start
# Health check
curl http://localhost:1337/health

# List available models
curl http://localhost:1337/v1/models

# Chat completion (OpenAI-compatible)
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"glm-4","messages":[{"role":"user","content":"Hello"}]}'
```

### Docker / Kubernetes

```bash
# Local development with Docker Compose
docker-compose -f docker-compose.production.yml up -d

# Kubernetes deployment
cd k8s/
./deploy.sh                    # Deploy to cluster
kubectl apply -f base/         # Apply base resources
kubectl apply -f overlays/production/  # Production overlay

# Build Docker images
docker build -f Dockerfile/api -t zoidbot-api:latest .
docker build -f Dockerfile/streaming -t zoidbot-streaming:latest .
```

---

## Code Style Guidelines

### General Principles
- Keep commits small and focused
- Run linters before every commit
- Use `todo` tool to track multi-step work
- Avoid changing unrelated files
- Follow existing patterns when adding new features

### Flutter / Dart Conventions

**Imports:**
- Use relative imports within `lib/` (`import '../services/foo.dart'`)
- Use package imports for external packages (`import 'package:provider/provider.dart'`)
- Avoid relative lib imports (`- avoid_relative_lib_imports`)
- Group imports: external packages, then internal, then relative
- Conditional imports for platform-specific code using `if (dart.library.html)`

**Formatting:**
- Use `flutter format .` (wraps Prettier)
- Prefer single quotes (`prefer_single_quotes`)
- Use `const` where possible (`unnecessary_const`)
- Use spread operators (`prefer_spread_collections`)

**Types:**
- Always declare return types (`always_declare_return_types`)
- No implicit casts/dynamic (`implicit-casts: false`, `implicit-dynamic: false`)
- Use `late` for late-initialized fields
- Avoid `var`; prefer explicit types or `final`

**Naming:**
- Classes: `CamelCase` (`class UserService`)
- Methods/variables: `camelCase` (`getUserData`)
- Constants: `CamelCase` with `k` prefix (`kMaxRetries`)
- Private members: underscore prefix (`_internalMethod`)
- Files: `snake_case.dart` (`auth_service.dart`)
- Directories: `snake_case/` (`services/`)

**Error Handling:**
- Use `try-catch` with specific exception types
- Never use empty catch blocks (`- empty_catches`)
- Prefer rethrowing with `rethrow` (`use_rethrow_when_possible`)
- Use `Result` types or sealed classes for error states
- Service initialization should use timeouts and graceful degradation

**Async/Await:**
- Don't use `.then()` chains; prefer `async/await`
- Mark async functions with `Future<ReturnType>`
- Handle unawaited futures (`- unawaited_futures`)
- Use `unawaited()` for intentionally skipped futures
- Use `ValueNotifier<T>` for reactive state

### JavaScript/TypeScript (Backend)
- Config: `.eslintrc.cjs` extends `eslint:recommended` + `prettier`
- Use `const`/`let`; never `var`
- Prefer arrow functions for callbacks
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Prefer `async/await` over raw promises
- Type: `module` for ES modules (use `--experimental-vm-modules` for Jest)
- Winston for logging, Sentry for error tracking

---

## Non-Obvious Code Patterns

### Flutter DI (GetIt - Two Phase)

The app uses GetIt service locator with two-phase initialization:

- **File**: `lib/di/locator.dart`
- `setupCoreServices()`: Services available before authentication
  - Settings, Auth, Theme, TokenStorage, LocalBrain, BrainSync, FullContextIndexer
  - RouterServer, RateLimitManager, ProviderDiscovery
  - AuthProvider (platform-specific: Auth0AuthProvider)
- `setupAuthenticatedServices()`: Services requiring authentication
  - TunnelService, LLMProviderManager, StreamingChatService
  - Agent monitoring services, GoogleWorkspaceService
- **CRITICAL**: Must register services in correct phase
- All services are registered as singletons via `registerSingleton<T>()`

**Example:**
```dart
// In setupCoreServices
final settingsPreferenceService = SettingsPreferenceService();
serviceLocator.registerSingleton<SettingsPreferenceService>(settingsPreferenceService);

// In setupAuthenticatedServices (called after user logs in)
final tunnelService = TunnelService();
serviceLocator.registerSingleton<TunnelService>(tunnelService);
```

### Platform Detection & Conditional Imports

- Use `kIsWeb` from `package:flutter/foundation.dart` for web detection
- Desktop vs web: conditional imports with `*_stub.dart` files
- Never use `dart:html` directly; use conditional imports

**Pattern:**
```dart
import 'package:cloudtolocalllm/services/langchain_rag_service.dart'
    if (dart.library.html) 'package:cloudtolocalllm/services/langchain_rag_service_stub.dart';
```

### Auth0 Integration

**Desktop:**
- Native Auth0 flow with `auth0_flutter` package
- Encrypted token storage via `flutter_secure_storage` (SQLite)
- `TokenStorageService` handles persistence

**Web:**
- **MUST** use JavaScript bridge — native SDK fails in webview
- Bridge file: `web/auth0-bridge.js` (injected into HTML)
- Tokens stored in `sessionStorage`, not `localStorage`
- Use `dart:js_interop` for web-native communication

**Common pattern:**
```dart
if (kIsWeb) {
  // Use web-specific auth via JS bridge
  authProvider = Auth0AuthProvider();
} else {
  // Use native Auth0 flow
  authProvider = Auth0AuthProvider();
}
```

### LLM Router System

The Flutter app exposes an OpenAI-compatible HTTP server (port 1337):

**Architecture:**
- `RouterServer` (`lib/services/router_server.dart`): Embedded shelf HTTP server
- `RateLimitManager`: Tracks concurrent requests per model with tier-based fallback
- Provider adapters in `lib/services/providers/`:
  - `zhipu_adapter.dart` - Zhipu AI (GLM models)
  - `google_adapter.dart` - Google (Gemini models)
  - `moonshot_adapter.dart` - Moonshot AI
- `ModelRegistry` (`lib/services/model_tiers.dart`): Model capacity tiers
  - Tier 1: Primary models (claude-3-opus, gpt-4-turbo, gemini-1.5-pro)
  - Tier 2: Fast/efficient models (claude-3-haiku, gpt-3.5-turbo)
  - Tier 3: Fallback models
  - Critical/High/Medium/Unlimited capacity levels

**Fallback logic:**
- Automatically switches to fallback models when rate limits reached
- Returns `X-Actual-Model` and `X-Switched-Reason` headers
- Database tracking via `ModelCapacity` and `LlmRequests` tables

**Endpoints:**
- `GET /v1/models` - List available models
- `POST /v1/chat/completions` - Chat completion (streaming supported)
- `GET /health` - Health check

### Provider Adapter Pattern

New LLM providers must:
1. Implement adapter in `lib/services/providers/` (e.g., `zhipu_adapter.dart`)
2. Inherit from base patterns in `lib/services/providers/base_provider.dart`
3. Implement OpenAI-compatible interface (`CompletionRequest`, `CompletionResponse`)
4. Assign model tier in `lib/services/model_tiers.dart`
5. Register in `RouterServer` in `lib/di/locator.dart`

**Example adapter structure:**
```dart
class MyProviderAdapter extends LlmProvider {
  final String apiKey;

  MyProviderAdapter({required this.apiKey});

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    // Implement OpenAI-compatible completion
  }

  @override
  Stream<String> streamComplete(CompletionRequest request) async* {
    // Implement streaming
  }
}
```

### Database (Drift/SQLite)

**Schema definition:**
- Tables defined in `lib/database/drift_local_brain.dart`
- Use code generation via `drift_dev` package
- Run `dart run build_runner build` after schema changes
- Queries MUST use generated code — raw SQL fails type checking

**Table patterns:**
```dart
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Generated files:**
- `lib/database/drift_local_brain.g.dart` - Auto-generated (DO NOT EDIT)
- `lib/database/connection/native.dart` - Native SQLite connection
- `lib/database/connection/web.dart` - Web IndexedDB connection

**Key tables:**
- `Users` - Local user identities
- `Conversations` - Conversation threads
- `Messages` - Chat messages
- `ModelCapacity` - LLM rate limit tracking
- `LlmRequests` - Request history
- `Agents` - Remote agent cache
- `AgentEvents` - Agent event log
- `SyncQueue` - Pending cloud sync operations

### SSH Tunnel Code

- Use `dartssh2` package only — other SSH libraries incompatible
- Service: `TunnelService` with WebSocket connections
- Connection state tracking, health monitoring, automatic reconnection
- Configuration: `TunnelConfigManager` for managing tunnel configs
- Metrics collection via Prometheus integration
- Error handling in `lib/services/tunnel/` subdirectory

**Key files:**
- `lib/services/tunnel/tunnel_service_impl.dart` - Main implementation
- `lib/services/ssh/ssh_tunnel_client.dart` - SSH client wrapper
- `lib/services/tunnel/connection_state_tracker.dart` - State management

### Property-Based Testing

The project uses extensive property-based testing patterns for UI components:
- Located in `test/widgets/` and `test/integration/`
- Tests verify properties (invariants) across many random inputs
- Examples: `account_settings_category_test.dart`, `theme_extensions_test.dart`
- Focuses on: theme consistency, responsiveness, accessibility, persistence
- Use `flutter test` to run property-based tests

**Example property test pattern:**
```dart
testWidgets('should handle various theme combinations',
  (WidgetTester tester) async {
    // Test property across multiple theme configurations
    for (final brightness in Brightness.values) {
      // Verify invariant holds
    }
  });
```

### Streaming Proxy Architecture

The streaming proxy (`services/streaming-proxy/`) is a TypeScript service with:
- **Circuit Breaker**: Automatic failure detection and recovery
- **Connection Pool**: SSH connection pooling with health monitoring
- **Rate Limiting**: Per-IP and per-user rate limiting
- **WebSocket Handler**: Real-time LLM communication
- **Metrics Collection**: Prometheus integration for observability
- **Tracing**: OpenTelemetry integration for distributed tracing

**Key directories:**
- `src/circuit-breaker/` - Circuit breaker implementation
- `src/connection-pool/` - SSH connection pooling
- `src/rate-limiter/` - Token bucket rate limiting
- `src/websocket/` - WebSocket handling with compression
- `src/metrics/` - Prometheus metrics collection

---

## Architecture Overview

### Service Layer Pattern (Flutter)

The Flutter app uses a layered service architecture:

**Service Categories:**
- **Core Services**: `SettingsPreferenceService`, `AuthService`, `ThemeProvider`, `TokenStorageService`
- **Authenticated Services**: `TunnelService`, `LLMProviderManager`, `StreamingChatService`
- **Router Services**: `RouterServer`, `RateLimitManager`, provider adapters
- **Monitoring Services**: `BehaviorWarningsService`, `SubagentRegistryService`, `AgentStatusService`
- **Integration Services**: `GoogleWorkspaceService`, `AdminService`
- **Platform Services**: Uses conditional imports for desktop vs web

**Platform Abstraction:**
- Web-specific code uses `dart:js_interop` and `dart:html`
- Conditional imports with stub implementations for desktop
- Example: `*_stub.dart` files for platform-specific functionality

### Backend Services Architecture

**api-backend** (Express.js):
- Auth0 JWT authentication via `express-oauth2-jwt-bearer`
- PostgreSQL for user sessions, cloud storage, tunnel configs
- Rate limiting via `express-rate-limit` with Redis
- OpenTelemetry tracing for observability
- Sentry for error tracking
- Routes organized by feature (admin, auth, tunnels, conversations, agent events)
- WebSocket support for real-time communication

**Streaming Proxy** (TypeScript/Express):
- WebSocket proxy for real-time LLM communication
- Circuit breaker pattern for fault tolerance
- Connection pooling with health monitoring
- Per-IP and per-user rate limiting
- Prometheus metrics collection
- OpenTelemetry tracing

**SDK** (TypeScript):
- Official JavaScript/TypeScript SDK for third-party integrations
- Exports: main client, types, and utilities
- Built with TypeScript (tsc)
- Published to npm as `@zoidbot/sdk`

---

## MCP (Model Context Protocol) Integration

### Available MCP Tools

The project uses MCP servers for enhanced capabilities:

**Core Tools (configured in `.claude/settings.json`):**
- **context7**: Library documentation and knowledge base retrieval — look up package docs, API patterns, best practices
- **sequentialthinking**: Multi-step problem-solving tool — plan complex implementations, validate solutions
- **memory**: Persistent knowledge store — track project decisions, architectural notes, and ongoing work across sessions
- **fetch**: HTTP requests for APIs, web content, and external services
- **filesystem**: Structured file system operations for reading, writing, and searching files
- **shell**: Command execution with structured interface and output capture
- **git**: Git operations for version control, commits, branches, and history
- **github**: GitHub API operations for PRs, issues, workflows, and releases
- **postgres**: PostgreSQL database operations for migrations, queries, and schema management
- **sentry**: Sentry error tracking and issue analysis with OAuth authentication (via mcp-remote wrapper)
- **brave-search**: Web search for documentation lookup, troubleshooting, and research
- **puppeteer**: Browser automation for end-to-end testing and web scraping

**MCP Remote Usage:**
For OAuth-enabled MCP servers (like Sentry), use the `mcp-remote` wrapper:
```json
{
  "sentry": {
    "command": "npx",
    "args": ["-y", "mcp-remote@latest", "https://mcp.sentry.dev/mcp"]
  }
}
```

**Troubleshooting MCP Remote:**
- If you see `Unexpected end of JSON input`, the bridge started but no local client connected to STDIO
- Ensure your MCP-capable client is configured to use the local proxy
- Alternative: Use direct `url` entry for clients that support OAuth natively

### Claude Code Hooks

The project uses Claude Code automations (`.claude/`):

**Auto-format Hooks:**
- Flutter files: `flutter format` automatically runs on edit/write
- JavaScript files: `npm run format` automatically runs on edit/write
- Background execution to avoid blocking

**Security Blocks:**
- Pre-tool-use hook runs `block-sensitive-files.sh`
- Blocks edits to: `*.secret.yaml`, `*/.env.production`, `*/.env`, `*/secrets/**`, `*.key`
- Exits with code 2 to indicate blocking error

**Skills and Subagents:**
- `.claude/skills/` contains invocable skills (e.g., `/flutter-service`, `/api-endpoint`)
- `.claude/agents/` contains auto-invoked subagents:
  - `security-reviewer`: Reviews Auth0, Stripe, SSH, and database security
  - `integration-tester`: Generates tests for services and endpoints

---

## Critical Requirements

### Engine Versions
- **Flutter**: 3.5+
- **Dart SDK**: >=3.5.0 <4.0.0
- **Node.js**: >=22.0.0 <25.0.0 (API backend and streaming proxy — NOT latest)
- **PostgreSQL**: 16+ (for backend database)

### Container Security
- Run containers as non-root: `USER 1000:1000` in Dockerfiles
- Minimal base images: `postgres:16-alpine`, `node:22-alpine`
- No exposed ports for internal services (use Docker networks)
- Health checks configured for all containers

### Free Tier Policy (Azure)
- B-series VMs only (B1s/B2s) for Docker Swarm
- Never create: Standard SKU Load Balancers, Application Gateway, Premium SSDs
- Use Basic SKU for all Azure resources when possible

---

## Integration Points

| Service | Address | Notes |
|---------|---------|-------|
| OpenClaw Gateway | localhost:18789 | Local LLM gateway |
| LM Studio | localhost:1234 | Alternative local model server |
| LLM Router | localhost:1337 | Embedded Flutter shelf server |
| API Backend | localhost:3000 | Express server (development) |
| Streaming Proxy | localhost:8080 | WebSocket proxy (development) |

### Tunnel Architecture
- SSH tunneling for secure remote access to local models
- WebSocket connections for real-time communication
- Connection state tracking and health monitoring
- Automatic reconnection with exponential backoff
- Metrics collection via Prometheus

### MCP Integration
- Workspace MCP config in `.claude/settings.json`
- User MCP config at `%APPDATA%/Code/User/mcp.json` (Windows)
- Available MCP tools: context7, sequentialthinking, memory, Sentry
- Remote MCP servers use OAuth via `mcp-remote` wrapper

### Third-Party Integrations
- **Auth0**: Authentication (JWT tokens, JWKS validation)
- **Google Workspace**: Calendar, Docs, Drive integration
- **Stripe**: Payment processing (via API backend)
- **Sentry**: Error tracking and monitoring
- **PostgreSQL**: Primary database for server-side data
- **Redis**: Caching and rate limiting (optional)

---

## Testing

### Flutter Tests

**Unit Tests:**
```bash
flutter test test/widgets/          # Widget tests
flutter test test/services/         # Service tests
flutter test test/utils/           # Utility tests
```

**Integration Tests:**
```bash
flutter test integration_test/       # Integration tests
flutter test test/integration/     # Platform integration tests
```

**Property Tests:**
- Located in `test/widgets/`, `test/integration/`
- Use property-based testing for UI components
- Test theme consistency, responsiveness, accessibility

### Backend Tests

**Jest Configuration:**
- Must use `--experimental-vm-modules` flag for ES modules
- Located in `test/api-backend/` organized by feature
- Use `--forceExit` flag for clean exit
- Coverage thresholds: 70% locally, 0% in CI (for stability)

**Test Categories:**
```bash
# Unit tests
npm run test:unit

# Security tests
npm run test:security
npm run test:tunnel:security

# Integration tests
npm run test:integration

# Feature-specific tests
npm run test:auth
npm run test:tunnel
npm run test:user-isolation
```

**End-to-End Tests:**
- Located in `test/e2e/` (Playwright)
- Located in `test/k6/` (K6 performance tests)
- PowerShell integration tests in `test/powershell/`

---

## Environment Configuration

### Environment Variables

**Required for API Backend:**
- `NODE_ENV` - Environment (development/production)
- `DB_TYPE` - Database type (postgresql)
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` - PostgreSQL connection
- `AUTH0_DOMAIN` - Auth0 tenant domain
- `AUTH0_CLIENT_ID` - Auth0 client ID
- `AUTH0_AUDIENCE` - Auth0 API identifier
- `JWT_SECRET` - JWT signing secret

**Optional:**
- `SENTRY_DSN` - Sentry error tracking
- `LOG_LEVEL` - Logging level (info/debug/error)

**Flutter Environment Variables:**
- `GLM_API_KEY` - Zhipu AI API key
- `GEMINI_API_KEY` - Google Gemini API key
- `KIMI_API_KEY` - Moonshot AI API key

**Configuration Files:**
- `config/env.template` - Template for environment variables
- `config/.env.production` - Production environment (DO NOT COMMIT)
- `config/cluster-config.json` - Kubernetes cluster configuration

### Docker Compose

The `docker-compose.production.yml` file defines:
- Two PostgreSQL instances (main and auth databases)
- API backend service
- Streaming proxy service
- Redis for caching
- Monitoring stack (Prometheus, Grafana)

**Networks and volumes:**
- All services on `zoidbot` Docker network
- Named volumes for persistent data
- Health checks for all services

---

## Deployment

### CI/CD Pipelines

**GitHub Workflows** (`.github/workflows/`):
- `app-builds.yml` - Build Linux and Windows desktop apps
- `deployment.yml` - Deploy to Kubernetes with AI change analysis
- `ai-triage.yml` - Automated issue triage
- `aur-push.yml` - Update AUR package

**Build Artifacts:**
- Linux: `build/linux/x64/release/bundle/`
- Windows: `build/windows/x64/runner/Release/`
- Web: `build/web/`

### Kubernetes Deployment

**Directory**: `k8s/`

**Base resources** (`k8s/base/`):
- Deployments for API, streaming proxy, web, PostgreSQL
- Services and networking
- ConfigMaps and Secrets
- RBAC for service accounts

**Overlays** (`k8s/overlays/`):
- `production/` - Production environment
- `staging/` - Staging environment
- `development/` - Development environment
- `local/` - Local development
- `managed/` - Managed cloud environments

**Deployment script:**
```bash
cd k8s/
./deploy.sh                    # Deploy current overlay
kubectl apply -f overlays/production/  # Manual apply
```

### Docker Deployment

**Build images:**
```bash
docker build -f Dockerfile/api -t zoidbot-api:latest .
docker build -f Dockerfile/streaming -t zoidbot-streaming:latest .
docker build -f web/Dockerfile -t zoidbot-web:latest .
```

**Run with Compose:**
```bash
docker-compose -f docker-compose.production.yml up -d
docker-compose -f docker-compose.production.yml logs -f
docker-compose -f docker-compose.production.yml down
```

### Release Process

**Versioning:**
- Bump version in `pubspec.yaml` and `assets/version.json`
- Update CHANGELOG.md
- Create GitHub release with release notes

**Platforms supported:**
- Linux (AppImage, DEB)
- Windows (MSI installer)
- Android (APK via Google Play)
- Web (PWA)
- macOS (DMG)

---

## Project Conventions

### File Naming

- **Dart**: `snake_case.dart` for files, `PascalCase` for classes
- **TypeScript/JavaScript**: `kebab-case.js` for files, `PascalCase` for classes
- **Constants**: `UPPER_SNAKE_CASE`
- **Directories**: `snake_case/`

### Commit Message Format

Use conventional commits with agent prefix for automated commits:
```
ai(AgentName): description
ai: fix memory leak in tunnel service
feat(router): add fallback model support
fix(auth): resolve token refresh issue
docs(readme): update setup instructions
```

### Directory Structure

```
lib/
├── main.dart                      # App entry point
├── auth/                          # Authentication
│   ├── auth_provider.dart         # Auth provider interface
│   └── providers/                # Platform-specific providers
├── config/                        # App configuration
│   ├── theme.dart                # Theme configuration
│   └── router.dart              # Navigation routes
├── database/                      # Database layer (Drift)
│   ├── drift_local_brain.dart    # Schema definition
│   └── connection/               # Platform connections
├── di/                           # Dependency injection
│   └── locator.dart              # GetIt service locator
├── models/                        # Data models
│   ├── user_model.dart
│   └── conversation.dart
├── services/                      # Business logic
│   ├── auth_service.dart         # Auth orchestration
│   ├── tunnel_service.dart       # Tunnel management
│   ├── providers/               # LLM provider adapters
│   └── tunnel/                  # Tunnel subsystem
├── widgets/                       # UI components
│   ├── settings/                 # Settings widgets
│   └── admin/                   # Admin widgets
└── screens/                       # Screen pages
    ├── home_screen.dart
    └── settings_screen.dart
```

---

## Troubleshooting

### Common Issues

**Flutter tests failing:**
- Run `flutter pub get` to ensure dependencies are current
- Run `flutter clean` to clear cache
- Check Dart SDK version (>=3.5.0 <4.0.0)

**Backend tests failing:**
- Ensure Node.js version is >=22.0.0 <25.0.0
- Run `npm install` to update dependencies
- Check PostgreSQL connection string

**Router server not responding:**
- Check port 1337 is not already in use
- Ensure Flutter app is running
- Check firewall settings

**Auth0 authentication failing:**
- Verify `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE` are correct
- Check JWKS URI is accessible
- For web: Ensure `auth0-bridge.js` is loaded

**Docker containers not starting:**
- Check Docker is running: `docker ps`
- Check logs: `docker-compose logs`
- Verify environment variables are set

**SSH tunnel connection issues:**
- Check SSH credentials in `TunnelConfigManager`
- Verify target server is accessible
- Check firewall rules on both ends
- Review logs in `TunnelService`

**MCP connection issues:**
- For `mcp-remote`: Ensure OAuth browser window completes authentication
- Check that MCP client is running and configured correctly
- Verify environment variables for MCP servers (e.g., `BRAVE_API_KEY`, `GITHUB_TOKEN`)
- Check logs for specific error messages

### Debugging

**Flutter:**
- Use `debugPrint()` for logging
- Check `flutter analyze` output for warnings
- Use Flutter DevTools for profiling

**Backend:**
- Check Winston logs in console/output files
- Use `LOG_LEVEL=debug` for verbose logging
- Check Sentry for error traces

---

## Additional Resources

### Documentation
- `docs/` - Comprehensive documentation
- `docs/development/` - Developer guides
- `docs/api/` - API documentation
- `docs/deployment/` - Deployment guides
- `.github/copilot-instructions.md` - Concise AI agent instructions
- `.claude/SETUP_SUMMARY.md` - Claude Code automations documentation

### Scripts
- `scripts/` - Utility scripts for deployment, testing, setup
- `scripts/setup-*.sh` - Infrastructure setup scripts
- `scripts/test-*.sh` - Test automation scripts

### Configuration
- `.claude/` - Claude Code automations and skills
- `.github/workflows/` - CI/CD pipeline definitions
- `k8s/` - Kubernetes manifests and overlays

### External Links
- GitHub: https://github.com/CloudToLocalLLM-online/CloudToLocalLLM
- Website: https://cloudtolocalllm.online
- Auth0 Dashboard: https://manage.auth0.com/
