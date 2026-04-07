---
name: senior-fullstack
description: Fullstack development for CloudToLocalLLM — Flutter frontend + Node.js backend services. Use when scaffolding features that span frontend and backend, setting up API endpoints with Flutter integration, or implementing cross-cutting concerns.
---

# Fullstack Development (Flutter + Node.js)

Patterns for building features that span the Flutter app and Node.js backend services.

## Architecture Overview

**Frontend**: Flutter 3.5+ (Dart, Linux/Windows/Web)
**Backend**: Node.js 22+ (ESM, Express 5 at `services/api-backend/`, Express 4 at `backend/auth/`)
**Database**: SQLite via Drift (Flutter local), PostgreSQL (backend)
**Auth**: Auth0 JWT (RS256)
**Router**: Embedded shelf HTTP server in Flutter on port 1337

## Adding a Full-Stack Feature

### 1. Backend API Endpoint

Add route in `services/api-backend/routes/` following the pattern in `api-endpoint` skill:
- Auth0 JWT middleware via `requireAuth`
- Zod request validation
- Winston logging
- Swagger/OpenAPI docs comment

### 2. Frontend Service

Add service in `lib/services/` following the `flutter-service` skill pattern:
- `ChangeNotifier` for reactive state
- Register in `lib/di/locator.dart` (core or auth phase)
- Use `debugPrint` for logging, never `print()`

### 3. Connect Frontend → Backend

The Flutter app talks to the backend via:
- **Direct HTTP**: `http` or `dio` packages to `localhost:8080` (API Backend)
- **Router**: Embedded shelf server on `localhost:1337` for LLM routing
- **WebSocket**: Streaming proxy on `localhost:3001` for real-time data
- **SSH Tunnel**: `lib/services/tunnel/` for remote connections

### 4. Database Considerations

- **Local state**: Add tables to `lib/database/drift_local_brain.dart`, then run `dart run build_runner build --delete-conflicting-outputs`
- **Server state**: Add migrations to `services/api-backend/database/migrate-pg.js`

## Service Boundaries

| What | Where | Port |
|------|-------|------|
| REST API | `services/api-backend/` | 8080 |
| WebSocket proxy | `services/streaming-proxy/` | 3001 |
| LLM Router | `lib/services/router_server.dart` | 1337 |
| Auth validation | `backend/auth/` | — |
| SDK | `services/sdk/` | — |

## Key Conventions

- **ESM everywhere** in backend: `import`/`export`, not `require()`
- **Express 5** in api-backend, **Express 4** in auth backend — different middleware APIs
- **No `dart:io`** in shared Flutter code — use conditional imports
- **GetIt DI** — always `di.serviceLocator<T>()`, never instantiate services directly
- **Tests**: `*_test.dart` in `test/` (Flutter), `*.test.js` in `test/api-backend/` (Jest)
- **Node tests need** `--experimental-vm-modules` (already in npm scripts)

## Verification

```
# Frontend
flutter format .
flutter analyze
flutter test

# Backend
cd services/api-backend && npm run lint && npm test
```
