# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloudToLocalLLM is a privacy-first platform for running Large Language Models locally with optional cloud relay for remote access. The architecture consists of a Flutter frontend (Windows, Linux, Web) and Node.js backend services.

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

## Architecture

### Service Layer Pattern (Flutter)

The Flutter app uses a layered service architecture with dependency injection:

- **lib/di/locator.dart**: GetIt service locator with two-phase initialization
  - `setupCoreServices()`: Services available before authentication (settings, auth, detection)
  - `setupAuthenticatedServices()`: Services requiring auth tokens (LLM providers, tunnels, containers)

- **Service Categories**:
  - Core Services: `SettingsPreferenceService`, `AuthService`, `ThemeProvider`
  - Authenticated Services: `OllamaService`, `TunnelService`, `LLMProviderManager`
  - Platform Services: Uses conditional imports for desktop vs web (e.g., `*_stub.dart` files)

- **Platform Abstraction**: Web-specific code uses `dart:js_interop` and `dart:html` conditional imports with stub implementations for desktop

### Backend Services

- **api-backend**: Main Express.js server with Auth0 JWT auth, PostgreSQL, rate limiting, OpenTelemetry tracing
- **streaming-proxy**: WebSocket proxy for real-time LLM communication
- **sdk**: TypeScript SDK for third-party integrations

### Authentication Flow

- Desktop: Native Auth0 flow with secure token storage (encrypted SQLite)
- Web: Auth0 with JavaScript bridge (`auth0-bridge.js`), session-based storage
- JWT validation via `express-oauth2-jwt-bearer` with JWKS RSA

### LLM Provider System

Supports multiple local LLM providers:
- **Ollama**: Default local provider, auto-discovery on localhost:11434
- **LM Studio**: Alternative local provider
- **OpenAI-compatible**: Generic OpenAI API providers

Providers are configured via `ProviderConfigurationManager` with auto-discovery in `ProviderDiscoveryService`. LangChain integration for advanced workflows.

### Tunnel/Cloud Architecture

- SSH tunneling for secure remote access to local models
- Tunnel service managed via `TunnelService` with WebSocket connections
- Connection state tracking, health monitoring, and automatic reconnection
- Metrics collection via Prometheus

### Data Storage

- **Server**: PostgreSQL for user sessions, cloud storage, tunnel configs
- **Desktop (Client)**: SQLite with encryption for conversation history
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
import 'package:cloudtolocalllm/services/some_service.dart'
    if (dart.library.html) 'package:cloudtolocalllm/services/some_service_web.dart';
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
- **Ollama**: For local model execution (optional for development)

## Key Configuration Files

- `pubspec.yaml`: Flutter dependencies and project config
- `analysis_options.yaml`: Dart lint rules (strong mode enabled, no implicit casts)
- `lib/di/locator.dart`: Service registration and dependency injection
- `services/api-backend/package.json`: Node.js dependencies and scripts
- `.github/copilot-instructions.md`: Additional AI agent guidance

## MCP Integration

- Workspace MCP servers configured in `.vscode/settings.json`
- Available tools: context7, sequentialthinking, memory, Sentry
- Remote MCP servers use OAuth via `mcp-remote` wrapper

## Development Notes

- The app supports both local-only mode (privacy-first) and cloud-relay mode
- Auth0 configuration requires environment variables (see `.env.example`)
- Docker deployment options available in `docker-compose.yml`
- CI/CD via GitHub Actions (see `.github/workflows/`)
