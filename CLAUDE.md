# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloudToLocalLLM is an OpenClaw Agent Manager — a privacy-first desktop AI companion organized around **Five Core Pillars**:

1. **Chat**: Unified chat interface with streaming responses, conversation persistence, multi-model support
2. **OpenClaw Gateway Management**: Start, stop, monitor OpenClaw Gateway (localhost:18789), health monitoring
3. **Evolving Avatar**: Visual character (CloudToLocalLLM) with personality engine, evolution tracker, memory system
4. **Desktop Control**: GUI automation, window management, file operations, clipboard, command execution
5. **Vision**: Screen capture/analysis, camera input, OCR, continuous monitoring

Architecture: Flutter frontend (Windows, Linux, Web) + Node.js backend services.

**See**: `docs/development/IMPLEMENTATION_PLAN.md` for detailed implementation status.

## Commands

### Flutter (Frontend)

```bash
# Install dependencies
flutter pub get

# Run applications
flutter run -d linux          # Linux desktop
flutter run -d windows        # Windows desktop
flutter run -d chrome         # Web (Chrome)
flutter run -d edge           # Web (Edge)

# Code quality
flutter analyze               # Static analysis
flutter test                  # Run all tests
flutter format .              # Format code

# Run specific test
flutter test test/services/avatar_state_service_test.dart

# Build
flutter build web --release   # Web release build
flutter build linux --release # Linux release build
```

### Backend Services

All backend services are in `services/`:

```bash
# API Backend (Express.js)
cd services/api-backend
npm install
npm run dev                   # Development with nodemon
npm test                      # Run all tests
npm run test:unit             # Unit tests only
npm run test:auth             # Authentication tests
npm run test:security         # Security tests
npm run test:tunnel           # Tunnel tests (all)
npm run test:tunnel:unit      # Tunnel unit tests
npm run test:tunnel:security  # Tunnel security tests
npm run lint                  # ESLint
npm run format                # Prettier

# Database migrations
npm run db:migrate            # Run PostgreSQL migrations
npm run db:validate           # Validate schema
npm run db:stats              # Database statistics

# SDK (TypeScript)
cd services/sdk
npm install
npm run build                 # TypeScript compilation
npm run dev                   # Watch mode
npm test

# Streaming Proxy
cd services/streaming-proxy
npm install
npm run dev                   # Development with inspect
npm run lint                  # ESLint
npm run health                # Health check

# Tailscale Relay
cd services/tailscale-relay
npm install
npm run dev                   # Development with nodemon
```

### LLM Router (Flutter)

The Flutter app runs an embedded HTTP server (port 1337) that provides OpenAI-compatible endpoints:

```bash
# Router runs automatically on app start (port 1337)

# Health check
curl http://localhost:1337/health

# List available models
curl http://localhost:1337/v1/models

# Chat completion (OpenAI-compatible)
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"glm-4","messages":[{"role":"user","content":"Hello"}]}'

# Avatar state management
curl http://localhost:1337/avatar/state
curl -X POST http://localhost:1337/avatar/traits \
  -H "Content-Type: application/json" \
  -d '{"traits": {"formality": 0.7, "humor": 0.6}}'
```

## Architecture

### Five Core Pillars Overview

| Pillar | Status | Key Files |
|--------|--------|-----------|
| 1. Chat | ✅ Core existing | `streaming_chat_service.dart`, `home_layout.dart` |
| 2. OpenClaw Manager | ✅ Core existing | `connection_manager_service.dart`, `agent_status_service.dart` |
| 3. Evolving Avatar | ✅ Phase 1 Complete | `avatar_widget.dart`, `personality_engine.dart`, `evolution_tracker.dart` |
| 4. Desktop Control | 🔲 Partial | `gui_automation_service.dart` (planned: window management, clipboard) |
| 5. Vision | 🔲 Partial | `gui_automation_service.dart` (planned: camera, OCR) |

**Implementation phases** (see `docs/development/IMPLEMENTATION_PLAN.md`):
- **Phase 0**: Setup Wizard (✅ Complete)
- **Phase 1**: Multi-model selector, gateway start/stop control, gateway dashboard (✅ Complete)
- **Phase 2**: Personality engine, evolution tracker, window/clipboard management (🟡 In Progress ~55%)
- **Phase 3**: Camera/OCR, avatar memory system, achievements (🔲 Pending)

### Service Layer Pattern (Flutter)

The Flutter app uses a **two-phase dependency injection** pattern via GetIt service locator:

**`lib/di/locator.dart`** - Core DI orchestrator:
- **`setupCoreServices()`**: Registers pre-authentication services (settings, auth, detection, local brain, token storage)
- **`setupAuthenticatedServices()`**: Entry point that calls `setupCoreServices()` first, then registers auth-dependent services
- **Desktop platforms**: Auto-bootstrap authenticated services on startup
- **Web platform**: Requires explicit authentication before accessing authenticated services

**Service Categories**:
- **Core Services** (pre-auth): `SettingsPreferenceService`, `AuthService`, `ThemeProvider`, `TokenStorageService`, `PlatformDetectionService`, `PlatformAdapter`
- **Data Services**: `LocalBrain` (SQLite), `BrainSyncService`, `FullContextIndexer`, `ConversationStorageService`
- **Router Services**: `RouterServer` (port 1337), `RateLimitManager`, provider adapters in `lib/services/providers/`
- **Authenticated Services**: `TunnelService`, `LLMProviderManager`, `StreamingChatService`, `ConnectionManagerService`
- **Monitoring Services**: `BehaviorWarningsService`, `SubagentRegistryService`, `AgentStatusService`, `AgentLifecycleService`
- **OpenClaw Manager**: `GatewayControlService` in `lib/services/openclaw_manager/`
- **Platform Services**: Conditional imports for desktop vs web (`*_stub.dart` files)

**Key Pattern**: Always use `di.serviceLocator<T>()` to access services, never instantiate directly. This ensures singleton behavior and proper initialization order.

### LLM Router System

**Architecture**: The Flutter app embeds a shelf HTTP server (port 1337) that provides OpenAI-compatible endpoints for routing LLM requests to multiple cloud providers.

**Components**:
- **`RouterServer`** (`lib/services/router_server.dart`): Embedded shelf HTTP server
- **Provider Adapters** (`lib/services/providers/`):
  - `base_provider.dart` - Shared OpenAI-compatible request/response models
  - `zhipu_adapter.dart` - Zhipu AI (GLM models)
  - `google_adapter.dart` - Google (Gemini models)
  - `moonshot_adapter.dart` - Moonshot AI
- **`RateLimitManager`**: Tracks concurrent requests per model, enforces tier limits
- **`ModelCapacity` Database**: Tracks rate limit state in Drift/SQLite
- **Fallback Logic**: Automatically switches to fallback models when rate limits reached

**Model Tiers** (`lib/services/model_tiers.dart`):
- **Critical**: 1 concurrent request, high-priority models
- **High**: 3 concurrent requests
- **Medium**: 10 concurrent requests
- **Unlimited**: No rate limiting

**Router Endpoints**:
- `GET /health` - Health check
- `GET /v1/models` - List available models
- `POST /v1/chat/completions` - OpenAI-compatible chat completions

**Avatar Evolution Endpoints**:
- `GET /avatar/state` - Get current avatar personality state
- `POST /avatar/traits` - Update personality traits
- `POST /avatar/evolution/request` - Request avatar evolution

### LLM Provider System

**Discovery & Configuration**:
- **Provider Auto-Discovery**: Scans for OpenClaw Gateway (localhost:18789), LM Studio (localhost:1234), Ollama (localhost:11434) on startup
- **`ProviderDiscoveryService`**: Auto-scans and configures discovered providers with periodic rescanning
- **`ProviderConfigurationManager`**: Manages provider configurations with persistence
- **`LLMProviderManager`**: Orchestrates provider selection and switching
- **`LLMErrorHandler`**: Centralized error handling with provider-aware recovery

**LangChain Integration**:
- **`LangChainIntegrationService`**: Provider initialization for LangChain workflows
- **`LangChainPromptService`**: Prompt template management
- **`LangChainRAGService`**: RAG (Retrieval Augmented Generation) capabilities

### Backend Services

| Service | Port | Purpose |
|---------|------|---------|
| API Backend | 8080 | Express.js REST API with Auth0 JWT, PostgreSQL, rate limiting, OpenTelemetry |
| Streaming Proxy | 3001 | WebSocket proxy for real-time LLM streaming |
| OpenClaw Gateway | 18789 | Primary LLM/Vision engine (managed by app) |

**API Backend Routes**:
- Admin, auth, tunnels, conversations, bridge polling, agent events
- Additional: `behavior-warnings-routes.js`, `context-usage-routes.js`, `models-routes.js`, `subagent-registry-routes.js`

### Avatar System (Pillar 3)

**Evolution Stages**:
1. **curious_explorer** (initial) - Default stage for new avatars
2. **knowledge_seeker** - Unlocked after 5+ deep conversations with avg novelty > 0.5
3. **wise_companion** - Further evolution stages
4. **enlightened_guide** - Highest evolution stage

**Personality Traits** (0.0-1.0):
- **formality**: How formal the avatar communicates
- **humor**: Frequency and intensity of humor
- **enthusiasm**: Energy and excitement levels
- **empathy**: Emotional understanding and support

**Evolution Criteria**:
- At least 5 deep conversations (complexity score > 0.7)
- Average novelty score > 0.5 across all conversations
- Collaborative approval between user and AI

**Key Files**:
- **`AvatarWidget`** (`lib/features/avatar/avatar_widget.dart`): Visual renderer with state-based reactions
- **`PersonalityEngine`** (`lib/services/avatar/personality_engine.dart`): Trait management and evolution validation
- **`EvolutionTracker`** (`lib/services/avatar/evolution_tracker.dart`): Conversation depth analysis and evolution pattern detection

**Planned Services**:
- `memory_service.dart` - Conversation embeddings for semantic search
- `achievement_service.dart` - Unlockables and milestones

### Tunnel/Cloud Architecture

**SSH Tunneling**: Secure tunneling via `ssh2` library with key-based authentication
**WebSocket Connection**: Real-time bidirectional communication with heartbeat monitoring
**Connection Resilience**:
- **`ConnectionStateTracker`**: Tracks connection state transitions
- **`ConnectionRecovery`**: Automatic reconnection with exponential backoff
- **`ReconnectionManager`**: Orchestrates reconnection attempts
- **`BackpressureManager`**: Handles flow control for streaming data

**Diagnostics Suite** (`lib/services/tunnel/diagnostics/`):
- **`DiagnosticTestSuite`**: Comprehensive diagnostic tests
- **`DiagnosticReportGenerator`**: Generates diagnostic reports
- Health checks and connection quality metrics

**Request Management**:
- **`PersistentRequestQueue`**: Queues requests during disconnection
- **`RequestPersistenceManager`**: Manages request persistence
- **`RequestTimeoutHandler`**: Handles request timeouts

### Conscience System (Multi-Agent Cross-Checking)

**Status**: 🟡 Phase 1 Complete - Storage Layer Implemented

A multi-agent system inspired by Grok 4.20 that cross-checks decisions before acting:

| Component | Role |
|-----------|------|
| **Coordinator** | Supervisor cron in OpenClaw, reads/writes storage, spawns agents, decides verdicts |
| **Zoidbot** | Front agent, talks to user, executes, posts intentions |
| **Benjamin** | Reviewer, validates, checks past failures, returns APPROVED/QUESTION/HOLD |
| **Harper** | Researcher, gathers context, searches, summarizes |

**Storage Strategy**:
- **App available** → Drift/SQLite via CloudToLocalLLM API (fast, indexed queries)
- **App down** → Files (`AGENT-THOUGHTS.md`, `CONSCIENCE.md`) - always works
- **Sync** → Files sync to DB when app comes back online

**Risk Categories**:
| Action | Review Required |
|--------|-----------------|
| Config edits | ✅ Yes - post to CONSCIENCE.md, wait |
| External sends | ✅ Yes |
| Deletions | ✅ Yes |
| Reading files | ❌ No |
| Git commits | ❌ No |

**Key Files**:
- `AGENT-THOUGHTS.md` - shared board where all agents post thoughts
- `CONSCIENCE.md` - risky action tracking with APPROVED/QUESTION/HOLD
- `memory/openclaw-app-architecture.md` - philosophy doc

### Data Storage

- **Server**: PostgreSQL for user sessions, cloud storage, tunnel configs
- **Desktop (Client)**:
  - SQLite with encryption for conversation history (`LocalBrain`)
  - Router tables: `ModelCapacity` (rate limit tracking), `LlmRequests` (request history)
- **Web**: IndexedDB for conversations, zero local persistence for sensitive data

### Observability Stack

**OpenTelemetry Tracing**: Distributed tracing across all backend services with OTLP HTTP exporter
**Prometheus Metrics**: HTTP requests, tunnel health, rate limiting, database performance, connection pool monitoring
**Winston Logging**: Structured logging with console and file transports (error, warn, info, debug)
**Sentry Error Tracking**: Production error monitoring with stack trace aggregation and release tracking

### Security Architecture

**Authentication**: Auth0 JWT with RS256 signing, JWKS public key verification via `jwks-rsa`, token refresh flow
**API Security**: `express-oauth2-jwt-bearer` middleware, `express-rate-limit` with Redis backend, Helmet HTTP headers, CORS, Zod input validation
**Tunnel Security**: SSH key-based authentication, WebSocket heartbeat, connection state tracking
**Secrets Management**: Environment variables, Claude Code hooks prevent editing `.env`, `.env.production`, secret files

## Project Conventions

### File Naming

- **Dart**: `snake_case.dart` for files, `PascalCase` for classes
- **TypeScript/JavaScript**: `kebab-case.js` for files, `PascalCase` for classes
- **Tests**: `*_test.dart` for Flutter tests, `*.test.js` or `*.unit.test.js` for Jest tests
- **Constants**: `UPPER_SNAKE_CASE`

### Commit Messages

Conventional commits with agent prefix for automated commits:
```bash
ai(AgentName): description
# Example: ai(Claude): add provider auto-discovery feature
```

### Platform Detection

Use `kIsWeb` from Flutter Foundation to detect web platform. For desktop-specific code, use conditional imports:

```dart
import 'package:CloudToLocalLLM/services/some_service.dart'
    if (dart.library.html) 'package:CloudToLocalLLM/services/some_service_web.dart';
```

### Error Handling

- **Backend**: Winston logging with Sentry integration
- **Frontend**: `debugPrint` for development, Sentry for error tracking
- **Service initialization**: Uses timeouts and graceful degradation

### Testing

**Backend Tests** (Jest):
- Tests located in `test/api-backend/` organized by feature
- Use `--forceExit` flag for Jest to ensure clean exit
- Test categories:
  - **Unit tests**: Feature-specific logic (e.g., `alerting-service.unit.test.js`)
  - **Integration tests**: End-to-end workflows (e.g., `backup-recovery-integration.test.js`)
  - **Security tests**: `test/api-backend/security/` directory
  - **Property-based tests**: Use `fast-check` for invariant verification

```bash
cd services/api-backend
npm run test:unit              # Unit tests only
npm run test:integration       # Integration tests
npm run test:auth              # Authentication tests
npm run test:security          # Security tests
npm run test:security:verbose  # Verbose security output
npm run test:tunnel            # Tunnel tests (all)
npm run test:user-isolation    # User isolation tests

# Run specific test file
npm test ../../test/api-backend/security/authentication-authorization.test.js
```

**Frontend Tests** (Flutter):
- Tests located in `test/` directory with subdirectories for services, widgets, integration
- Widget tests use `flutter_test` framework
- Integration tests use `flutter_driver` or `integration_test` package

```bash
flutter test                                    # Run all tests
flutter test test/services/avatar_state_service_test.dart  # Specific test
flutter test --coverage                         # With coverage
```

## Environment Requirements

- **Flutter**: 3.5+
- **Dart SDK**: >=3.5.0 <4.0.0
- **Node.js**: >=22.0.0 <25.0.0 (exact version enforced in package.json)
- **PostgreSQL**: For backend database (Cloud SQL or local)
- **Redis**: For rate limiting cache (optional, can use in-memory)
- **LLM Providers**:
  - Local: OpenClaw Gateway (localhost:18789), LM Studio (localhost:1234), Ollama (localhost:11434)
  - Cloud: Zhipu AI, Google Gemini, Moonshot (configured via router)
- **Router Port**: 1337 (embedded Flutter HTTP server)
- **NVIDIA Drivers**: Required for GPU acceleration (RTX 30/40 series recommended)
- **Tailscale** (optional): For tailscale-relay service
- **Auth0**: Required for authentication (configure in `config/.env.production`)

## Key Configuration Files

- `pubspec.yaml` - Flutter dependencies and project config
- `analysis_options.yaml` - Dart lint rules (strong mode enabled, no implicit casts)
- `lib/di/locator.dart` - Service registration and dependency injection (two-phase)
- `lib/services/router_server.dart` - LLM router HTTP server (port 1337)
- `lib/services/model_tiers.dart` - Model capacity tier definitions
- `lib/services/providers/base_provider.dart` - OpenAI-compatible request/response models
- `services/api-backend/package.json` - Node.js dependencies and scripts
- `services/api-backend/database/migrate-pg.js` - PostgreSQL migrations
- `config/.env.production.template` - Environment variable template
- `SPEC.md` - Master specification with project vision
- `docs/development/IMPLEMENTATION_PLAN.md` - Five pillars implementation status

## MCP Integration

**Workspace MCP Servers** (`.claude/settings.json`):
- **context7** - Library documentation for Flutter, Node.js, Auth0
- **sequentialthinking** - Multi-step problem-solving and planning
- **memory** - Persistent knowledge store for project decisions
- **Sentry** - Error tracking with OAuth authentication (via mcp-remote wrapper)
- **puppeteer** - Browser automation for testing and web scraping

**MCP Remote Pattern**:
```bash
# Direct OAuth-enabled clients
{ "Sentry": { "url": "https://mcp.sentry.dev/mcp" } }

# Legacy/wrapper for clients needing STDIO
npx -y mcp-remote@latest https://mcp.sentry.dev/mcp
```

**Troubleshooting MCP**: If you see `Unexpected end of JSON input` with mcp-remote, it means the bridge started but no local client connected — ensure your MCP client is configured.

### Claude Code Automations

The repository includes configured automations in `.claude/`:

**Skills** (user-invocable with `/skill-name`):
- `/api-endpoint` - Generate Express.js endpoints with Auth0 JWT middleware
- `/flutter-service` - Generate Flutter services with Provider pattern
- `/provider-setup` - Add new LLM providers with adapter templates
- `/avatar-evolution` - Avatar evolution development workflow
- `/desktop-control` - Desktop automation development patterns
- `/vision-automation` - Vision system development templates
- `/tailscale-relay` - Tailscale relay service management
- `/proxmox-admin` - Proxmox VE day-2 operations
- `/proxmox-upgrade` - Proxmox VE upgrade runbook
- Senior specialist skills: `senior-architect`, `senior-backend`, `senior-frontend`, `senior-devops`, `senior-qa`, `senior-fullstack`

**Hooks** (automatic):
- **PostToolUse**: Auto-format Flutter (dartfmt) and Node.js (prettier) on edit; auto-analyze Flutter code; run Flutter tests
- **PreToolUse**: Block edits to `.env`, `.env.production`, secret files; warn on git commits with security-sensitive changes

**Subagents** (auto-invoked):
- **avatar-specialist** - Avatar system features and evolution
- **integration-tester** - Generates tests for services and endpoints
- **performance-analyzer** - Bottleneck detection and optimization
- **security-reviewer** - Reviews Auth0, Stripe, SSH, database security

See `.claude/SETUP_SUMMARY.md` for complete automation documentation.

## Development Notes

- **Privacy-first**: The app supports both local-only mode and cloud-relay mode
- **Naming**: "CloudToLocalLLM" is the avatar/bot character name; the application is "CloudToLocalLLM"
- **Docker deployment**: Options available in `docker-compose.yml`
- **CI/CD**: GitHub Actions in `.github/workflows/`

### Debugging

**Flutter Development**:
```bash
flutter run -d linux --verbose    # Verbose logging
flutter attach                    # Attach to running app
flutter run -d chrome --device-timeout=60  # Inspect widget tree
```

**Backend Development**:
```bash
cd services/api-backend
node --inspect server.js          # API backend with inspect
cd services/streaming-proxy
npm run dev                       # Streaming proxy with inspect
```

### Troubleshooting

**Service Registration Issues**:
- Check debug logs for `[ServiceLocator]` prefixes
- Verify `setupCoreServices()` completes before `setupAuthenticatedServices()`
- Desktop platforms auto-bootstrap authenticated services; web requires explicit authentication

**Provider Discovery**:
- Providers auto-scan on startup and periodically
- Check `ProviderDiscoveryService` logs for discovery results
- Manual configuration via `ProviderConfigurationManager` if auto-discovery fails

**Tunnel Connection Issues**:
- Run diagnostics via `TunnelService.getDiagnostics()`
- Check SSH key configuration in `TunnelConfigManager`
- Review connection state in `ConnectionStateTracker`
- Verify WebSocket heartbeat is active

### Key Documentation

- `SPEC.md` - Master specification with project vision
- `docs/development/IMPLEMENTATION_PLAN.md` - Five pillars implementation status
- `docs/architecture/SYSTEM_ARCHITECTURE.md` - Technical deep dive
- `docs/FUTURE_ENHANCEMENTS.md` - Self-hosting and enhancement ideas
- `README.md` - User-facing overview and setup

# currentDate
Today's date is 2026-03-04.
