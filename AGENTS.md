# CloudToLocalLLM Agent Guide

## What this is

Flutter desktop/web app + Node.js backend services. Privacy-first AI companion and OpenClaw Agent Manager.
Five pillars: Chat, OpenClaw Gateway, Evolving Avatar, Desktop Control, Vision.

## Commands

### Flutter (frontend — root of repo)

```
flutter pub get                              # install deps
flutter analyze                              # lint/static analysis (strict mode)
flutter test                                 # all tests
flutter test test/services/some_test.dart    # single test
flutter format .                             # format
flutter run -d linux | windows | chrome      # run app
flutter build linux --release                # build
```

- SDK: Dart >=3.5.0 <4.0.0, Flutter 3.5+
- `analysis_options.yaml`: strong mode, `implicit-casts: false`, `implicit-dynamic: false`, `prefer_single_quotes`

### Drift database codegen

The local SQLite database (`lib/database/drift_local_brain.dart`) uses Drift with a generated `.g.dart` part file.
After changing table definitions or queries, regenerate:

```
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis. Do not edit them.

### Backend services (Node.js, in `services/`)

All backend services require **Node.js >=22 <25** and use ESM (`"type": "module"`).

**API Backend** (`services/api-backend/`):

```
npm install
npm run dev                     # nodemon dev server
npm test                        # all tests (Jest, --forceExit)
npm run test:unit               # unit tests only
npm run test:security           # security tests
npm run test:tunnel             # tunnel tests
npm run lint                    # ESLint
npm run format                  # Prettier
npm run db:migrate              # PostgreSQL migrations
```

Tests live in `test/api-backend/` (not inside `services/`).
Run a single test: `npm test ../../test/api-backend/some.test.js`
All test commands need `--experimental-vm-modules` (already in the scripts).

**Streaming Proxy** (`services/streaming-proxy/`):

```
npm run dev                     # node --inspect
npm run health                  # health check
npm run lint
```

**SDK** (`services/sdk/`):

```
npm run build                   # TypeScript → dist/
npm test
```

**Tailscale Relay** (`services/tailscale-relay/`):

```
npm run dev                     # nodemon
```

**Auth Backend** (`backend/auth/`):

```
npm run dev                     # nodemon auth/handlers.js
```

Separate from `services/api-backend/` — lightweight Express 4 JWT validation.

### Root-level Node tests

```
npm test                        # uses jest.config.js at root
```

Root `jest.config.js` matches `**/test/**/*.test.js` across the monorepo.

## Architecture quick reference

### Flutter app structure

| Path                              | Purpose                                      |
| --------------------------------- | -------------------------------------------- |
| `lib/main.dart`                   | App entry point                              |
| `lib/di/locator.dart`             | GetIt service locator — **two-phase DI**     |
| `lib/database/`                   | Drift/SQLite (`LocalBrain`) + generated code |
| `lib/services/`                   | All service classes (87+ files)              |
| `lib/services/router_server.dart` | Embedded shelf HTTP server (port 1337)       |
| `lib/services/providers/`         | LLM provider adapters (OpenAI-compatible)    |
| `lib/services/avatar/`            | Personality engine, evolution tracker        |
| `lib/services/tunnel/`            | SSH tunneling, diagnostics, reconnection     |
| `lib/services/openclaw_manager/`  | OpenClaw Gateway control                     |
| `lib/features/`                   | Feature widgets (avatar, browser, system)    |
| `lib/screens/`                    | App screens                                  |
| `lib/config/`                     | App configuration                            |

### Two-phase DI (critical pattern)

`lib/di/locator.dart`:

1. `setupCoreServices()` — pre-auth: settings, auth, detection, local brain, tokens
2. `setupAuthenticatedServices()` — calls core first, then registers auth-dependent services

- **Desktop**: authenticated services auto-bootstrap on startup
- **Web**: requires explicit auth before authenticated services are available
- **Always** use `di.serviceLocator<T>()` — never instantiate services directly

### Platform conditional imports

Web vs desktop code is split via conditional imports with stub files:

```dart
import 'service.dart'
    if (dart.library.io) 'service_stub.dart'
    if (dart.library.js_interop) 'service_web.dart';
```

Files ending in `_stub.dart` are desktop stubs for web-only APIs (and vice versa).

### Node.js backend services

| Service         | Dir                         | Port | Purpose                                                  |
| --------------- | --------------------------- | ---- | -------------------------------------------------------- |
| API Backend     | `services/api-backend/`     | 8080 | Express 5 REST API, Auth0 JWT, PostgreSQL, rate limiting |
| Streaming Proxy | `services/streaming-proxy/` | 3001 | WebSocket proxy for LLM streaming                        |
| Tailscale Relay | `services/tailscale-relay/` | —    | Tailscale tunnel relay                                   |
| Auth Backend    | `backend/auth/`             | —    | Express 4 JWT validation                                 |
| SDK             | `services/sdk/`             | —    | TypeScript SDK (builds to `dist/`)                       |
| OpenClaw Skills | `services/openclaw-skills/` | —    | CloudToLocalLLM skill definitions                        |

### LLM Router (embedded in Flutter)

- Runs on port 1337 via shelf HTTP server
- OpenAI-compatible endpoints: `/v1/models`, `/v1/chat/completions`
- Provider adapters in `lib/services/providers/` (Zhipu, Google, Moonshot)
- Rate limit tiers in `lib/services/model_tiers.dart` (critical/high/medium/unlimited)

### Database

- **Flutter local**: SQLite via Drift (`lib/database/drift_local_brain.dart`) — encrypted conversation storage
- **Backend**: PostgreSQL (migrations via `services/api-backend/database/migrate-pg.js`)
- **Web client**: IndexedDB (no local file persistence for sensitive data)

### Docker / deployment

- `docker-compose.yml` — dev stack (PostgreSQL, Redis, API backend, streaming proxy, Traefik, Prometheus, Grafana)
- `docker-compose.prod.yml`, `docker-compose.production.yml`, `docker-compose.multi.yml` — production variants
- `docker/` — Grafana dashboards, Prometheus config
- `k8s/` — Kubernetes manifests
- `CloudronManifest.json` — Cloudron deployment

## Conventions

- **Branding**: CloudToLocalLLM, OpenClaw, Zoidbot, 🦞 — preserve these names exactly
- **Dart files**: `snake_case.dart`, classes `PascalCase`, `prefer_single_quotes`
- **JS/TS files**: `kebab-case.js`, classes `PascalCase`
- **Tests**: `*_test.dart` (Flutter), `*.test.js` (Jest)
- **Commits**: conventional commits; automated commits use `ai(AgentName): description`
- **No comments** in code unless asked
- **ESM**: All backend services use `"type": "module"` — use `import`/`export`, not `require()`

## Key gotchas

- **Drift generated code**: If you edit table/query definitions in `drift_local_brain.dart`, you MUST run `build_runner` — the `.g.dart` part file won't update itself
- **Express version split**: `services/api-backend/` uses Express 5; `backend/auth/` uses Express 4 — different middleware APIs
- **Test location**: API backend tests live in `test/api-backend/` at repo root, not inside `services/api-backend/`
- **Node version**: `>=22 <25` enforced in `engines` for api-backend and streaming-proxy
- **Web platform**: Many services have web stubs (`*_stub.dart`) — don't call `dart:io` directly in shared service code
- **Root package.json**: Exists but is for backend tooling (Jest, ESLint) — the Flutter app is the primary frontend
- **Two package-lock files**: `package-lock.json` (root) and `pnpm-lock.yaml` coexist — root uses npm

## Verification order

After making changes, verify in this order:

1. **Format** → `flutter format .` or `npm run format`
2. **Lint/Analyze** → `flutter analyze` (Dart) or `npm run lint` (Node)
3. **Test** → `flutter test` or `npm test`
4. If you changed Drift tables/queries → run `build_runner`

## Safety

- Keep changes small and reversible
- Prefer rollback-friendly edits over broad refactors
- Test the touched surface directly
- Don't edit `.env`, `.env.production`, or secret files
