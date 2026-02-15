# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Non-Obvious Build/Lint/Test Commands

### Flutter (Frontend)
```bash
flutter test test/widget_test.dart  # Single test file requires specific path
flutter build linux --release         # Linux release build (distinct from web)
```

### API Backend (`services/api-backend/`)
```bash
# Jest with ES modules requires experimental flag
node --experimental-vm-modules node_modules/jest/bin/jest.js path/to/test.test.js

# Database operations
npm run db:migrate    # Run PostgreSQL migrations
npm run db:validate   # Validate schema
```

### LLM Router (Flutter - runs on port 1337)
```bash
curl http://localhost:1337/health           # Health check
curl http://localhost:1337/v1/models        # List models
```

## Non-Obvious Code Patterns

### Flutter DI (GetIt - Two Phase)
- [`lib/di/locator.dart`](lib/di/locator.dart): `setupCoreServices()` → `setupAuthenticatedServices()`
- Core services available pre-auth: Settings, Auth, Theme, TokenStorage
- Auth services available post-auth: Tunnel, LLM providers, Streaming

### Platform Detection
- Use `kIsWeb` from `package:flutter/foundation.dart` for web detection
- Desktop vs web: conditional imports with `*_stub.dart` files

### Auth0 Integration
- Desktop: Native Auth0 flow with encrypted SQLite token storage
- Web: Uses `auth0-bridge.js` for session-based storage (NOT native)

### LLM Router System
- Embedded shelf HTTP server at port 1337
- Provider adapters in [`lib/services/providers/`](lib/services/providers/)
- Model tiers: critical/high/medium/unlimited in [`lib/services/model_tiers.dart`](lib/services/model_tiers.dart)
- Rate limiting via `RateLimitManager`

## Non-Obvious Architecture

### Data Storage
- Server: PostgreSQL for sessions, cloud storage, tunnel configs
- Desktop Client: SQLite with encryption (LocalBrain), Drift for router tables
- Web Client: IndexedDB, no local persistence for sensitive data

### Claude Code Automations (from `.claude/`)
- **Skills** (user-invocable with `/skill-name`):
  - `/api-endpoint` - Generate Express.js endpoints with Auth0 JWT middleware
  - `/flutter-service` - Generate Flutter services with Provider pattern
- **Hooks**: Auto-format on edit, security blocks for `.env`, `.env.production`, `secrets/`
- **Subagents**: `security-reviewer`, `integration-tester`

## Critical Requirements

### Engine Versions (non-standard)
- Node.js: **>=22.0.0 <25.0.0** (API backend - NOT latest)
- Dart SDK: **>=3.5.0 <4.0.0**
- Node.js: >=18.0.0 (SDK)

### Container Security
- Run containers as non-root: `USER 1000:1000` in Dockerfiles

### Free Tier Policy
- Azure: B-series VMs only (B1s/B2s) for Docker Swarm
- Never create: Standard SKU Load Balancers, Application Gateway, Premium SSDs
- Use: ghcr.io instead of ACR, Cloudflare Tunnel for ingress

## Key Integration Points

- **Local Models**: OpenClaw Gateway (localhost:18789), LM Studio (localhost:1234)
- **Tunnel**: SSH tunneling with WebSocket connections, health monitoring
- **MCP**: Workspace MCP in `.vscode/settings.json`, user MCP at `%APPDATA%/Code/User/mcp.json`
