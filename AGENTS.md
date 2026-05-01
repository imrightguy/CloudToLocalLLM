# CloudToLocalLLM Agent Guide

## What this is

Flutter desktop/web app plus Node.js backend services. The product is a local-first companion and desktop capability layer for user-selected agent runtimes such as Hermes, OpenClaw, Ollama, LM Studio, and compatible private endpoints.

Core orientation: secure agent channel, avatar/voice companion, desktop control, vision, runtime/agent management, and multi-device sync through a Tailscale-first secure device mesh.

- Do not assume a universal default runtime. The setup wizard decides whether the active runtime is on this device, another private device, a Tailscale device, a manual/private URL, or optional paid CloudToLocalLLM-hosted compute.
- Hermes is the current first test path.
- OpenClaw remains a supported runtime and original integration, but it is not the universal default.
- Desktop control is a core feature and must remain explicit, device-scoped, permissioned, and auditable.
- Voice belongs with the avatar companion. The avatar/voice companion should be able to open as a sidecar window, separate from the main app.
- Agent/runtime management remains important but should not be the first UI surface.
- Prefer Tailscale for secure private connectivity. The cloud connector model is one isolated container per user, joined to that user's tailnet.

## Commands

### Flutter app

Run from the repository root unless noted otherwise.

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/services/some_test.dart
flutter test --coverage
flutter format .
flutter run -d linux
flutter run -d windows
flutter run -d chrome
flutter build linux --release
flutter build web --release
```

- Main app package: `pubspec.yaml`, package name `cloudtolocalllm`, version `10.1.200+4200`.
- Dart SDK constraint: `>=3.5.0 <4.0.0`.
- Lints: `analysis_options.yaml` includes `flutter_lints`, strong mode, `implicit-casts: false`, `implicit-dynamic: false`, `prefer_single_quotes`, and generated-file excludes.
- Shared Flutter package: `lib/shared/pubspec.yaml`, package name `cloudtolocalllm_shared`, Dart SDK `>=3.9.0 <4.0.0`.

### Drift database codegen

The local SQLite database is in `lib/database/drift_local_brain.dart` and has generated part files.

```bash
dart run build_runner build --delete-conflicting-outputs
```

- Run this after changing Drift table definitions or queries.
- Do not edit generated `*.g.dart` or `*.freezed.dart` files.

### Root Node tooling

```bash
npm test
npm run lint
npm run format
```

- Root `package.json` is backend/tooling only; it is not the Flutter app package.
- Root `npm test` uses ESM Jest with `jest.config.js` and matches `**/test/**/*.test.js`.
- Root Jest intentionally ignores several live-infrastructure tests.
- Root lint/format scripts iterate selected services and tests.

### API Backend

Directory: `services/api-backend/`

```bash
npm install
npm run dev
npm test
npm run test:unit
npm run test:integration
npm run test:auth
npm run test:security
npm run test:security:verbose
npm run test:tunnel
npm run test:user-isolation
npm run lint
npm run format
npm run db:migrate
npm run db:validate
npm run db:stats
```

- Node engine: `>=22.0.0 <25.0.0`.
- Module type: ESM (`"type": "module"`).
- Main server: `services/api-backend/server.js`, default port `8080`.
- Tests live at repo root in `test/api-backend/`, not inside the service directory.
- Single backend test example: `npm test ../../test/api-backend/security/authentication-authorization.test.js`.
- Jest runs with `--experimental-vm-modules`; service config is `services/api-backend/jest.config.js`.
- PostgreSQL migrations live in `services/api-backend/database/migrations/`.

### Streaming Proxy

Directory: `services/streaming-proxy/`

```bash
npm install
npm run dev
npm run health
npm test
npm run build
npm run lint
npm run format
```

- Node engine: `>=22.0.0 <25.0.0`.
- Module type: ESM (`"type": "module"`).
- Runtime entry: `proxy-server.js`, default port `3001`.
- TypeScript source and tests live under `services/streaming-proxy/src/`.
- Jest config is `services/streaming-proxy/jest.config.js`.

### SDK

Directory: `services/sdk/`

```bash
npm install
npm run build
npm run dev
npm test
npm run lint
npm run format
```

- Package: `@CloudToLocalLLM/sdk`, version `2.0.0`.
- Node engine: `>=18.0.0`.
- Module type: ESM (`"type": "module"`).
- Source is in `services/sdk/src/`; build output is `services/sdk/dist/`.
- Jest config is `services/sdk/jest.config.js`.

### Tailscale Relay

Directory: `services/tailscale-relay/`

```bash
npm install
npm run dev
npm start
```

- Module type: ESM (`"type": "module"`).
- Entry: `src/server.js`, default port `3002`.
- No engine constraint is declared in this package.
- Uses Express 4, unlike the Express 5 API backend and auth backend.

### Auth Backend

Directory: `backend/auth/`

```bash
npm install
node handlers.js
npm run lint
```

- Module type: CommonJS (`"type": "commonjs"`).
- Entry: `handlers.js`, default port `3000`.
- Uses Express 5 with `express-jwt` and `jwks-rsa`.
- There is no `npm run dev` script in this package.
- The `npm test` script is a placeholder that exits with an error.

### OpenClaw Skills

Directory: `services/openclaw-skills/cloudtolocallm/`

```bash
npm install
npm run build
npm run dev
npm test
```

- Module type: ESM.
- TypeScript skill package for avatar personality and evolution.
- Uses Vitest, not Jest.

## Architecture quick reference

### Flutter app structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry point |
| `lib/bootstrap/` | Startup/bootstrap support |
| `lib/di/locator.dart` | GetIt service locator and two-phase DI |
| `lib/database/` | Drift/SQLite local brain and platform database connections |
| `lib/services/` | Service layer, router, auth, providers, tunnel, admin, platform services |
| `lib/services/providers/` | OpenAI-compatible provider adapters: Zhipu, Google, Moonshot, Hermes |
| `lib/services/avatar/` | Avatar state, personality, memory, evolution, markdown sync |
| `lib/services/voice/` | Avatar companion voice state, Hermes bridge status, TTS foundation |
| `lib/services/openclaw_manager/` | OpenClaw Gateway control |
| `lib/services/hermes_manager/` | Hermes gateway management and streaming |
| `lib/services/desktop_control/` | Clipboard and window management |
| `lib/services/vision/` | Camera, OCR, region capture, vision orchestration |
| `lib/services/tunnel/` | Legacy/fallback tunnel resilience, queueing, diagnostics, metrics, config |
| `lib/features/` | Feature widgets for avatar, browser, system |
| `lib/screens/` | UI screens: admin, agents, dashboard, onboarding, settings, skills, usage, more |
| `lib/widgets/` | Shared widgets, chat widgets, settings widgets, navigation |
| `lib/config/` | App config |
| `lib/shared/` | Separate shared Flutter package |

### Two-phase DI

`lib/di/locator.dart` is the central registration point.

1. `setupCoreServices()` registers pre-auth services such as settings, session storage, auth, local brain, router, provider discovery, platform detection, setup wizard, voice foundation, and tier services.
2. `setupAuthenticatedServices()` calls core setup first, then registers auth-dependent services such as tunnel, streaming proxy, LLM provider manager, LangChain, gateway control, agent lifecycle, admin, desktop control, vision, and popout services.

- Use `di.serviceLocator<T>()` or `serviceLocator.get<T>()`; do not instantiate registered services directly.
- Desktop platforms can bootstrap authenticated services automatically after startup checks.
- Web requires explicit authentication/session bootstrap before auth-dependent services are available.

### Platform splits

The app uses conditional imports for web vs desktop/native behavior.

```dart
import 'thing.dart'
    if (dart.library.io) 'thing_io.dart'
    if (dart.library.html) 'thing_web.dart';
```

- The codebase also uses `dart.library.js_interop` for web interop in newer files.
- Do not import `dart:io` directly in shared code; use existing platform helpers, stubs, or conditional imports.
- Stub files are common for tray, window manager, SSH tunnel, RAG, download prompt, and Auth0 web/native splits.

### Embedded runtime router

- Implemented in `lib/services/router_server.dart`.
- Default port: `1337`.
- OpenAI-compatible endpoints include `/v1/models` and `/v1/chat/completions`.
- Local speech endpoint: `/v1/audio/speech` where the desktop TTS foundation is available.
- Health endpoint: `/health`.
- Avatar endpoints include `/avatar/state`, `/avatar/traits`, and `/avatar/evolution/request`.
- Provider adapters live in `lib/services/providers/`.
- Rate limit tiers live in `lib/services/model_tiers.dart`.
- Provider discovery scans local services including Hermes, OpenClaw Gateway `localhost:18789`, LM Studio `localhost:1234`, and Ollama `localhost:11434` where supported by the current adapters.

### Backend services

| Service | Directory | Default port | Notes |
| --- | --- | --- | --- |
| API Backend | `services/api-backend/` | `8080` | Express 5 REST API, Auth0 JWT, PostgreSQL, rate limiting, Sentry/OpenTelemetry |
| Streaming Proxy | `services/streaming-proxy/` | `3001` | WebSocket/HTTP streaming proxy container; legacy/fallback for tunnel-heavy paths |
| Tailscale Relay | `services/tailscale-relay/` | `3002` | ESM relay service, Express 4 |
| Auth Backend | `backend/auth/` | `3000` | Lightweight CommonJS Auth0 JWT validation |
| SDK | `services/sdk/` | n/a | TypeScript SDK, builds to `dist/` |
| OpenClaw Skills | `services/openclaw-skills/cloudtolocallm/` | n/a | TypeScript/Vitest skill package |

### Data storage

- Flutter local database: encrypted Drift/SQLite local brain in `lib/database/drift_local_brain.dart`.
- Native database connection: `lib/database/connection/native.dart`.
- Web database connection: `lib/database/connection/web.dart`.
- Backend database: PostgreSQL via `services/api-backend/database/`.
- Backend migrations: `services/api-backend/database/migrations/`.
- Web client storage avoids sensitive local file persistence; use web-safe storage services and stubs.

### Secure device mesh and cloud connector

- Tailscale is the preferred private transport for multi-device CloudToLocalLLM.
- The intended cloud connector shape is one isolated CloudToLocalLLM container per user.
- A cloud connector joins only that user's Tailscale tailnet, ideally through a narrow service identity/tag.
- The connector coordinates secure channel sync, device presence, and web/mobile access. It must not bypass local desktop permissions.
- Cloud-hosted runtime is optional paid compute. Most users are expected to run Hermes/OpenClaw/etc. on their own device, server, or tailnet.
- Custom SSH/WebSocket tunnel docs and services should be treated as legacy/fallback unless a task explicitly targets them.

### Deployment and infrastructure

- Root Docker Compose files: `docker-compose.yml`, `docker-compose.prod.yml`, `docker-compose.production.yml`, `docker-compose.multi.yml`.
- Additional Docker configs: `config/docker/`.
- Kubernetes manifests: `k8s/`, `services/*/k8s/`, and `config/kubernetes/`.
- Cloudron deployment: `CloudronManifest.json`.
- Monitoring assets: `docker/`, `config/grafana/`, `config/prometheus/`.
- Deployment scripts live in `scripts/`, including AWS, Cloud Run, Azure, Cloudflare, Proxmox, packaging, release, and runner setup helpers.
- GitHub Actions live in `.github/workflows/`.

## Conventions

- Branding: preserve `CloudToLocalLLM`, `OpenClaw`, `Zoidbot`, and the lobster branding exactly.
- Dart files use `snake_case.dart`; classes use `PascalCase`; prefer single quotes.
- JS/TS files generally use `kebab-case.js` or `kebab-case.ts`; classes use `PascalCase`.
- Flutter tests use `*_test.dart`.
- Jest tests use `*.test.js`, `*.unit.test.js`, or TypeScript equivalents inside service-specific test roots.
- Backend services under `services/` are ESM unless a package says otherwise.
- `backend/auth/` is CommonJS.
- Automated commits should use conventional commits with an agent prefix, for example `ai(Codex): update agent guide`.
- Do not add code comments unless specifically asked or the code is not self-explanatory.

## Key gotchas

- `AGENTS.md` was previously truncated; keep this file complete when editing it.
- Changing Drift schema or queries requires `dart run build_runner build --delete-conflicting-outputs`.
- Generated Dart files are excluded from analysis and should not be edited manually.
- API backend tests live in root `test/api-backend/`, not in `services/api-backend/test/`.
- API backend and streaming proxy enforce Node `>=22 <25`; SDK only requires Node `>=18`; Tailscale Relay has no declared engine.
- Auth backend has no `npm run dev`; use `node handlers.js`.
- Tailscale Relay uses Express 4 while API backend and auth backend use Express 5.
- Root `package.json` is not the frontend package; Flutter metadata is in `pubspec.yaml`.
- Many live-infrastructure tests are intentionally ignored by Jest configs; check config before assuming a test is part of default runs.
- Web/native conditional imports use both `dart.library.html` and `dart.library.js_interop`; match the local pattern in nearby files.
- Avoid direct `dart:io` usage in shared Flutter code.
- Secret-bearing files and environment templates live under `config/` and related deployment directories; avoid printing or committing real secrets.

## Useful documentation

- `SPEC.md` - Product specification and vision.
- `README.md` - User-facing overview.
- `docs/development/IMPLEMENTATION_PLAN.md` - Pillar implementation plan.
- `docs/architecture/SYSTEM_ARCHITECTURE.md` - Architecture deep dive.
- `docs/architecture/AVATAR_SYSTEM.md` - Avatar system.
- `docs/architecture/DESKTOP_CONTROL.md` - Desktop control.
- `docs/architecture/VISION_SYSTEM.md` - Vision system.
- `docs/architecture/SECURE_DEVICE_MESH.md` - Tailscale-first multi-device and cloud connector architecture.
- `docs/architecture/TUNNEL_SYSTEM.md` - Legacy/fallback tunnel system.
- `docs/development/DEVELOPMENT_WORKFLOW.md` - Development workflow.
- `docs/development/testing/COMPREHENSIVE_TESTING_GUIDE.md` - Testing guide.
