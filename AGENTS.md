# AGENTS.md - CloudToLocalLLM Agent Guide

Repository-specific instructions for agentic coding tools.

## Scope

- **Product**: `CloudToLocalLLM` (OpenClaw Agent Manager)
- **Stack**: Flutter frontend (Windows, Linux, Web) + Node.js backend services
- **Five Pillars**: Chat, Gateway Management, Evolving Avatar, Desktop Control, Vision

## Rule Files

Apply guidance in this order:

1. `AGENTS.md` (this file)
2. `.github/copilot-instructions.md`
3. `.kilocode/rules-code/AGENTS.md` (coding-specific rules)
4. `.kilocode/rules/Development_guidelines.md` (general guidelines)

Rule discovery in this repo:

- Copilot rules: `.github/copilot-instructions.md` (present)
- Cursor rules: `.cursor/rules/` (missing)
- Kilocode rules: `.kilocode/rules*/` (present)

## Runtime Requirements

| Component | Version |
|-----------|---------|
| Dart SDK | `>=3.5.0 <4.0.0` |
| Node.js (api-backend) | `>=22.0.0 <25.0.0` |
| Node.js (sdk) | `>=18.0.0` |
| Flutter | Stable channel |
| PostgreSQL | For backend database |
| Redis | Optional (rate limiting cache) |

## Build / Lint / Test Commands

Run from repo root unless noted.

### Flutter (`/`)

```bash
# Dependencies
flutter pub get

# Development
flutter run -d linux
flutter run -d windows
flutter run -d chrome
flutter run -d edge

# Code Quality
flutter analyze               # Static analysis - MUST PASS
flutter format .              # Format code
flutter test                  # Run all tests
flutter test test/widget_test.dart
flutter test test/services/auth_test.dart
flutter test --plain-name "AuthService"

# Build
flutter build linux --release
flutter build windows --release
flutter build web --release

# Database code generation (after schema changes)
dart run build_runner build
```

### API Backend (`services/api-backend/`)

```bash
npm install
npm run dev                    # Development with nodemon
npm test                       # Run all tests
npm run test:unit              # Unit tests only
npm run test:integration       # Integration tests
npm run test:auth              # Authentication tests
npm run test:security          # Security tests
npm run test:security:verbose  # Verbose security output
npm run test:tunnel            # Tunnel tests (all)
npm run test:tunnel:unit       # Tunnel unit tests
npm run test:tunnel:integration # Tunnel integration tests
npm run test:tunnel:security   # Tunnel security tests
npm run test:user-isolation    # User isolation tests

# Single test file
npm test -- ../../test/api-backend/security/authentication-authorization.test.js

# Single test name
npm test -- --testNamePattern="should reject invalid token"

npm run lint                   # ESLint
npm run format                 # Prettier

# Database
npm run db:migrate             # Run PostgreSQL migrations
npm run db:validate            # Validate schema
npm run db:stats               # Database statistics
```

### Streaming Proxy (`services/streaming-proxy/`)

```bash
npm install
npm run dev                    # Development with --inspect
npm run health                 # Health check
npm test
npm test -- test/some-file.test.js
npm run lint
npm run build                  # TypeScript compilation
```

### SDK (`services/sdk/`)

```bash
npm install
npm run build                  # TypeScript compilation
npm run dev                    # Watch mode
npm test
npm run lint
npm run format
```

### Tailscale Relay (`services/tailscale-relay/`)

```bash
npm install
npm run dev                    # Development with nodemon
npm start
```

## Code Organization

### Flutter Frontend (`lib/`)

```
lib/
├── main.dart                  # App entry point
├── di/locator.dart            # GetIt service locator (CRITICAL)
├── config/                    # App config, routing, theme
├── screens/                   # UI screens by feature
├── widgets/                   # Reusable widgets
├── components/                # Smaller UI components
├── services/                  # Business logic services
│   ├── providers/             # LLM provider adapters
│   ├── tunnel/                # Tunnel infrastructure
│   ├── avatar/                # Avatar personality/evolution
│   ├── openclaw_manager/      # Gateway control
│   └── desktop_control/       # Clipboard, system control
├── models/                    # Data models
├── database/                  # Drift/SQLite database
├── auth/                      # Authentication providers
├── bootstrap/                 # App initialization
└── utils/                     # Utilities
```

### Backend Services (`services/`)

```
services/
├── api-backend/               # Main Express.js server
│   ├── server.js              # Entry point
│   ├── routes/                # API routes
│   ├── middleware/            # Auth, rate limiting, etc.
│   ├── services/              # Business logic
│   ├── database/              # PostgreSQL migrations
│   └── tunnel/                # SSH tunnel handling
├── streaming-proxy/           # WebSocket proxy for LLM
├── sdk/                       # TypeScript SDK
└── tailscale-relay/           # Tailscale tunnel relay
```

## Critical Patterns

### Service Registration (Flutter)

Services are registered in `lib/di/locator.dart` in two phases:

1. **Core Services** (`setupCoreServices()`): Available before authentication
   - `SettingsPreferenceService`, `AuthService`, `ThemeProvider`
   - `LocalBrain`, `TokenStorageService`, `RouterServer`
   - `ProviderDiscoveryService`, `PersonalityEngine`, `EvolutionTracker`

2. **Authenticated Services** (`setupAuthenticatedServices()`): Require auth tokens
   - `TunnelService`, `StreamingChatService`, `ConnectionManagerService`
   - `LLMProviderManager`, `AgentStatusService`, `AdminService`

**Gotcha**: Adding services to wrong phase causes runtime errors. Core services won't have auth tokens; authenticated services won't be available at login.

### Platform Detection

```dart
import 'package:flutter/foundation.dart';

if (kIsWeb) {
  // Web-specific code
} else {
  // Desktop code (Windows, Linux)
}
```

**Never use `dart:html` directly** - use conditional imports with `*_stub.dart` pattern:

```dart
import 'package:cloudtolocalllm/services/some_service.dart'
    if (dart.library.html) 'package:cloudtolocalllm/services/some_service_web.dart';
```

### Provider Adapter Pattern

New LLM providers must:

1. Implement adapter in `lib/services/providers/` following existing patterns (see `zhipu_adapter.dart`)
2. Adapters must implement OpenAI-compatible interface for router
3. Register in `RouterServer` constructor in `lib/di/locator.dart`
4. Add model tier assignment in `lib/services/model_tiers.dart` for rate limiting

### Database (Drift/SQLite)

- Tables defined in `lib/database/` with code generation
- Run `dart run build_runner build` after schema changes
- Queries MUST use generated code - raw SQL will fail type checking

### Auth0 Token Storage

- **Desktop**: Tokens stored in encrypted SQLite via `flutter_secure_storage`
- **Web**: MUST use `auth0-bridge.js` - native SDK will fail in webview
- Bridge stores tokens in sessionStorage, not localStorage

## Code Style Guidelines

### Dart / Flutter

Source of truth: `analysis_options.yaml`, `pubspec.yaml`.

**Formatting**:
- Run `flutter format .` before commits
- Prefer single quotes (`prefer_single_quotes`)
- Keep diffs minimal; avoid unrelated reformatting

**Types**:
- Always declare return types (`always_declare_return_types`)
- No implicit casts or implicit dynamic
- Prefer `final` by default and `const` where possible
- Avoid `dynamic` except for strict boundary/interoperability cases

**Naming**:
- Types/classes/enums: `UpperCamelCase`
- Variables/methods/params: `lowerCamelCase`
- Private members: leading underscore
- Files/folders: `snake_case`
- Constants: `kPrefix` where used (e.g., `kIsWeb`)

**Error handling and async**:
- Never use empty `catch` blocks
- Catch specific exceptions when practical
- Use `rethrow` when preserving stack context
- Prefer `async/await` over chained futures
- Avoid `print`; use `debugPrint` or structured logs

**Common lint-sensitive rules**:
- `use_build_context_synchronously`
- `unawaited_futures`
- `curly_braces_in_flow_control_structures`
- `avoid_print`

### JavaScript / TypeScript

Source of truth: `.eslintrc.cjs`, service `package.json` scripts.

**Conventions**:
- Use `const` by default, `let` only when needed, never `var`
- Prefer `async/await` and explicit error paths
- Use optional chaining (`?.`) and nullish coalescing (`??`) where appropriate
- Preserve ESM compatibility where `"type": "module"` is set

**Lint/format**:
- ESLint extends `eslint:recommended` and `prettier`
- `prettier/prettier` is enforced as an error
- Run lint/format scripts for each touched service

**Testing**:
- Backend tests use Jest with `--forceExit` flag
- During iteration, run single test file/name first
- Before handoff, run relevant full suites

## Testing Approach

### Flutter Tests

- Located in `test/` directory mirroring `lib/` structure
- Widget tests: `test/widgets/`
- Service tests: `test/services/`
- Integration tests: `test/integration/`
- Use `mockito` for mocking (see `pubspec.yaml`)

### Backend Tests

- Located in `test/api-backend/` organized by feature
- Categories: unit, integration, security, tunnel
- Use `supertest` for API testing
- Use `fast-check` for property-based testing

## Important Gotchas

### SSH Tunnel Code
- Use `dartssh2` package only - other SSH libraries incompatible with tunnel architecture
- Connection health monitoring required - tunnel service tracks connection state

### LLM Router
- Router runs on port 1337 automatically on app start
- Health check: `curl http://localhost:1337/health`
- Models list: `curl http://localhost:1337/v1/models`

### CI/CD (GitHub Actions)
- Workflows in `.github/workflows/`
- `app-builds.yml`: Flutter builds for Linux/Windows
- `deployment.yml`: Deployment pipeline
- Version bumps update both `pubspec.yaml` and `assets/version.json`

### Root Directory Protocol
- DO NOT create new files/directories in repository root
- Permitted root files: `.gitignore`, `LICENSE`, `package.json`, `pubspec.yaml`, `README.md`, `CHANGELOG.md`, config directories
- Redirect outputs: `docs/` for docs, `config/` for configs, `scripts/` for scripts

## Required Checks Before Commit

```bash
# Flutter
flutter analyze   # Must pass with no errors
flutter format .  # Must pass
flutter test      # Run relevant tests

# Node.js (for each touched service)
npm run lint
npm run format
npm test
```
