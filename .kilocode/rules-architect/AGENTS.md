# AGENTS.md - Architect Mode

This file provides architectural guidance for AI agents working in this repository.

## Non-Obvious Architectural Constraints

### Service Layer Architecture (Flutter)
- **Two-Phase Initialization**: [`lib/di/locator.dart`](lib/di/locator.dart) uses `setupCoreServices()` then `setupAuthenticatedServices()`
- Core services (pre-auth): Settings, Auth, Theme, TokenStorage
- Authenticated services (post-auth): Tunnel, LLM providers, Streaming
- Adding services to wrong phase causes runtime failures

### Platform-Specific Constraints
- **Web**: Cannot use `dart:html` directly - must use `dart:js_interop` with stub files for desktop
- **Web Auth**: Must use `auth0-bridge.js` - native SDK fails in webview, tokens in sessionStorage
- **Desktop**: Encrypted SQLite for tokens via `flutter_secure_storage`
- Use `kIsWeb` from `flutter/foundation.dart` for platform detection (NOT platform packages)

### LLM Router Architecture
- Embedded shelf HTTP server at port 1337 (not separate service)
- Provider adapters in [`lib/services/providers/`](lib/services/providers/) implement OpenAI-compatible interface
- Model tiers in [`lib/services/model_tiers.dart`](lib/services/model_tiers.dart) control rate limiting
- RateLimitManager tracks concurrent requests, auto-fallbacks on limits
- Database tables: `ModelCapacity`, `LlmRequests` (Drift/SQLite)

### Tunnel Architecture
- SSH tunneling with WebSocket connections
- Connection health monitoring required
- Uses `dartssh2` package only (incompatible with other SSH libraries)

### Data Architecture
- **Server**: PostgreSQL for sessions, cloud storage, tunnel configs
- **Desktop Client**: SQLite with encryption (LocalBrain)
- **Web Client**: IndexedDB, NO local persistence for sensitive data

### Backend Services
- `services/api-backend/`: Express 5 with Auth0 JWT, PostgreSQL, rate limiting
- `services/streaming-proxy/`: WebSocket proxy for LLM streaming
- `services/sdk/`: TypeScript client SDK

## Critical Requirements
- Node.js: >=22.0.0 <25.0.0 (API backend - NOT latest)
- Dart SDK: >=3.5.0 <4.0.0
- Containers: Run as non-root (`USER 1000:1000`)
- Free tier: Azure B-series only, no Standard Load Balancers

## Integration Points
- Local models: OpenClaw Gateway (localhost:18789), LM Studio (localhost:1234)
- MCP: Workspace config in `.vscode/settings.json`, user config at `%APPDATA%/Code/User/mcp.json`
