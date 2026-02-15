# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zoidbot is a privacy-first platform for running Large Language Models locally with optional cloud relay for remote access. The architecture consists of a Flutter frontend (Windows, Linux, Web) and Node.js backend services.

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

# Build
flutter build web --release   # Web release build
flutter build linux --release  # Linux release build
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
npm run test:tunnel          # Tunnel tests
npm run test:tunnel:unit     # Tunnel unit tests
npm run test:tunnel:security # Tunnel security tests
npm run lint                  # ESLint
npm run format                # Prettier

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
```

### Database Operations

```bash
cd services/api-backend
npm run db:migrate            # Run PostgreSQL migrations
npm run db:validate           # Validate schema
npm run db:stats              # Database statistics
```

### LLM Router (Flutter)

The Flutter app runs an embedded HTTP server that routes LLM requests:

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
```

## Architecture

### Service Layer Pattern (Flutter)

The Flutter app uses a layered service architecture with dependency injection:

- **lib/di/locator.dart**: GetIt service locator with two-phase initialization
  - `setupAuthenticatedServices()`: Entry point that delegates to `setupCoreServices()` first, then registers auth-dependent services
  - `setupCoreServices()`: Services available before authentication (settings, auth, detection, local brain, token storage)

- **Service Categories**:
  - Core Services: `SettingsPreferenceService`, `AuthService`, `ThemeProvider`, `TokenStorageService`
  - Authenticated Services: `TunnelService`, `LLMProviderManager`, `StreamingChatService`
  - Router Services: `RouterServer`, `RateLimitManager`, provider adapters in `lib/services/providers/`
  - Monitoring Services: `BehaviorWarningsService`, `SubagentRegistryService`, `AgentStatusService`
  - Integration Services: `GoogleWorkspaceService`
  - Platform Services: Uses conditional imports for desktop vs web (e.g., `*_stub.dart` files)

- **Platform Abstraction**: Web-specific code uses `dart:js_interop` and `dart:html` conditional imports with stub implementations for desktop

### Backend Services

- **api-backend**: Main Express.js server with Auth0 JWT auth, PostgreSQL, rate limiting, OpenTelemetry tracing
  - **Routes**: Admin, auth, tunnels, conversations, bridge polling, agent events
  - **New Routes**: `behavior-warnings-routes.js`, `context-usage-routes.js`, `models-routes.js`, `subagent-registry-routes.js`
- **postgres**: PostgreSQL database configuration and migrations
- **sdk**: TypeScript SDK for third-party integrations
- **streaming-proxy**: WebSocket proxy for real-time LLM communication
- **backend/**: Docker setup for database deployment (alternative to services/postgres)

### Authentication Flow

- Desktop: Native Auth0 flow with secure token storage (encrypted SQLite)
- Web: Auth0 with JavaScript bridge (`auth0-bridge.js`), session-based storage
- JWT validation via `express-oauth2-jwt-bearer` with JWKS RSA

### LLM Provider System

Supports multiple local LLM providers:
- **OpenClaw Gateway**: Primary local provider, auto-discovery on localhost:18789
- **LM Studio**: Alternative local provider (localhost:1234)
- **OpenAI-compatible**: Generic OpenAI API providers

Providers are configured via `ProviderConfigurationManager` with auto-discovery in `ProviderDiscoveryService`. LangChain integration for advanced workflows.

### LLM Router System

The Flutter app exposes an OpenAI-compatible HTTP server (port 1337) for routing requests to multiple cloud providers:

- **RouterServer** (`lib/services/router_server.dart`): Embedded shelf HTTP server
- **Provider Adapters** (`lib/services/providers/`):
  - `zhipu_adapter.dart` - Zhipu AI (GLM models)
  - `google_adapter.dart` - Google (Gemini models)
  - `moonshot_adapter.dart` - Moonshot AI
- **Rate Limiting**: `RateLimitManager` tracks concurrent requests per model
- **Model Tiers**: `lib/services/model_tiers.dart` defines capacity tiers (critical/high/medium/unlimited)
- **Fallback Logic**: Automatically switches to fallback models when rate limits reached
- **Database**: `ModelCapacity` and `LlmRequests` tables (Drift/SQLite) track usage

Router endpoints: `GET /v1/models`, `POST /v1/chat/completions`, `GET /health`

### Tunnel/Cloud Architecture

- SSH tunneling for secure remote access to local models
- Tunnel service managed via `TunnelService` with WebSocket connections
- Connection state tracking, health monitoring, and automatic reconnection
- Metrics collection via Prometheus

### Data Storage

- **Server**: PostgreSQL for user sessions, cloud storage, tunnel configs
- **Desktop (Client)**:
  - SQLite with encryption for conversation history (`LocalBrain`)
  - Router tables: `ModelCapacity` (rate limit tracking), `LlmRequests` (request history)
- **Web**: IndexedDB for conversations, zero local persistence for sensitive data

## Project Conventions

### File Naming

- **Dart**: `snake_case.dart` for files, `PascalCase` for classes
- **TypeScript/JavaScript**: `kebab-case.js` for files, `PascalCase` for classes
- **Constants**: `UPPER_SNAKE_CASE`

### Commit Messages

- Conventional commits with agent prefix for automated commits: `ai(AgentName): description`
- Example: `ai(Claude): add provider auto-discovery feature`

### Platform Detection

Use `kIsWeb` from Flutter Foundation to detect web platform. For desktop-specific code, use conditional imports:

```dart
import 'package:zoidbot/services/some_service.dart'
    if (dart.library.html) 'package:zoidbot/services/some_service_web.dart';
```

### Error Handling

- Backend: Winston logging with Sentry integration
- Frontend: `debugPrint` for development, Sentry for error tracking
- Service initialization uses timeouts and graceful degradation

### Testing

- Backend: Jest with separate unit/integration/security test suites
- Tests located in `test/api-backend/` organized by feature
- Use `--forceExit` flag for Jest to ensure clean exit

## Environment Requirements

- **Flutter**: 3.5+
- **Dart SDK**: >=3.5.0 <4.0.0
- **Node.js**: >=22.0.0 <25.0.0 (API backend and streaming proxy)
- **PostgreSQL**: For backend database
- **LLM Providers**:
  - Local: OpenClaw Gateway (localhost:18789) or LM Studio (localhost:1234)
  - Cloud: Zhipu AI, Google Gemini, Moonshot (configured via router)
- **Router Port**: 1337 (embedded Flutter HTTP server)
- **NVIDIA Drivers**: Required for GPU acceleration (RTX 30/40 series recommended)

## Key Configuration Files

- `pubspec.yaml`: Flutter dependencies and project config
- `analysis_options.yaml`: Dart lint rules (strong mode enabled, no implicit casts)
- `lib/di/locator.dart`: Service registration and dependency injection
- `lib/services/router_server.dart`: LLM router HTTP server
- `lib/services/model_tiers.dart`: Model capacity tier definitions
- `services/api-backend/package.json`: Node.js dependencies and scripts
- `.github/copilot-instructions.md`: Additional AI agent guidance

## MCP Integration

- Workspace MCP servers configured in `.claude/settings.json`
- Available tools: context7, sequentialthinking, memory, Sentry
- Remote MCP servers use OAuth via `mcp-remote` wrapper

### Claude Code Automations

The repository includes configured Claude Code automations in `.claude/`:

**Skills** (user-invocable with `/skill-name`):
- `/api-endpoint` - Generate Express.js endpoints with Auth0 JWT middleware
- `/flutter-service` - Generate Flutter services with Provider pattern

**Hooks** (automatic):
- Auto-format: Flutter (dartfmt) and Node.js (prettier) on edit
- Security blocks: Prevents edits to `.env`, `.env.production`, `**/*.secret.yaml`, `**/secrets/**`, `**/*.key` files

**Subagents** (auto-invoked):
- `security-reviewer` - Reviews Auth0, Stripe, SSH, and database security
- `integration-tester` - Generates tests for services and endpoints

**MCP Servers**:
- `context7` - Live documentation for Flutter, Node.js, Auth0
- `Sentry` - Error investigation and stack trace analysis

See `.claude/SETUP_SUMMARY.md` for complete automation documentation.

## Development Notes

- The app supports both local-only mode (privacy-first) and cloud-relay mode
- Auth0 configuration requires environment variables (see `config/.env.production.template`)
- Docker deployment options available in `docker-compose.yml`
- CI/CD via GitHub Actions (see `.github/workflows/`)
- Claude Code automations documented in `.claude/SETUP_SUMMARY.md`
