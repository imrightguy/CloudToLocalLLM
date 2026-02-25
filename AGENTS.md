# AGENTS.md — CloudToLocalLLM Agent Guidelines

This file provides guidance for AI coding agents working on **CloudToLocalLLM** — OpenClaw Agent Manager.

## Project Vision

CloudToLocalLLM is an **OpenClaw Agent Manager** with five core pillars: Chat, OpenClaw Gateway Management, Evolving Avatar, Desktop Control, and Vision.

---

## Build / Lint / Test Commands

### Flutter (Frontend)

```bash
# Install dependencies
flutter pub get

# Run application
flutter run -d linux          # Linux desktop
flutter run -d windows       # Windows desktop
flutter run -d chrome        # Web (Chrome)

# Run tests
flutter test                              # All tests
flutter test test/widget_test.dart       # Single test file (Recommended)
flutter test test/services/auth_test.dart # Specific test

# Code quality (REQUIRED before commit)
flutter analyze              # Must pass with no errors
flutter format .             # Must pass

# Build
flutter build linux --release
flutter build web --release
flutter build windows --release
```

### Backend Services

#### API Backend (`services/api-backend/`)

```bash
npm install
npm run dev                     # Development
npm test                        # All tests
npm run test:unit               # Unit tests
npm run test:auth               # Auth tests
npm run test:security          # Security tests
npm run test:tunnel            # Tunnel tests
npm run lint; npm run format   # Code quality
```

#### Streaming Proxy (`services/streaming-proxy/`)

```bash
npm install
npm run dev; npm test; npm run build; npm run lint
```

---

## Code Style Guidelines

### Flutter / Dart

**Imports:**

- Relative imports within `lib/`: `import '../services/foo.dart'`
- Package imports for external: `import 'package:provider/provider.dart'`
- Conditional imports for platform-specific: `if (dart.library.html)`

**Formatting:**

- Use `flutter format .` (wraps Prettier)
- Prefer single quotes, `const` where possible, spread operators

**Types:**

- Always declare return types (`always_declare_return_types`)
- No implicit casts/dynamic (`implicit-casts: false`)
- Use `late` for late-initialized fields
- Avoid `var`; prefer explicit types or `final`

**Naming:**

- Classes: `CamelCase` | Methods/variables: `camelCase`
- Constants: `CamelCase` with `k` prefix (`kMaxRetries`)
- Private members: underscore prefix (`_internalMethod`)
- Files: `snake_case.dart` | Directories: `snake_case/`

**Error Handling:**

- Use `try-catch` with specific exception types
- Never use empty catch blocks
- Prefer rethrowing with `rethrow`
- Use `Result` types or sealed classes for error states

**Async/Await:**

- Prefer `async/await` over `.then()` chains
- Mark async functions with `Future<ReturnType>`
- Use `ValueNotifier<T>` for reactive state

### JavaScript/TypeScript (Backend)

- Use `const`/`let`; never `var`
- Prefer arrow functions, optional chaining (`?.`), nullish coalescing (`??`)
- Prefer `async/await` over raw promises
- Config: `.eslintrc.cjs` extends `eslint:recommended` + `prettier`

---

## Key Architecture Patterns

### Flutter DI (Two-Phase)

- File: `lib/di/locator.dart`
- `setupCoreServices()`: Services before auth (Settings, Auth, Theme)
- `setupAuthenticatedServices()`: Services requiring auth (Tunnel, LLM providers)
- Register as singletons via `registerSingleton<T>()`

### Platform Detection & Conditional Imports

- Use `kIsWeb` from `package:flutter/foundation.dart`
- Conditional imports with `*_stub.dart` files for desktop/web

### Auth0 Integration

- Desktop: Native `auth0_flutter` with encrypted storage
- Web: JavaScript bridge (`web/auth0-bridge.js`) with `sessionStorage`

### Database (Drift/SQLite)

- Schema in `lib/database/drift_local_brain.dart`
- Run `dart run build_runner build` after schema changes

### LLM Router System

- Embedded server on port 1337 (OpenAI-compatible)
- Provider adapters in `lib/services/providers/`
- Model tiers in `lib/services/model_tiers.dart`

---

## Commit Format

```
ai(AgentName): description
feat(router): add fallback model support
fix(auth): resolve token refresh issue
```

---

## Critical Requirements

### Engine Versions

- Flutter: 3.5+ | Dart SDK: >=3.5.0 <4.0.0
- Node.js: >=22.0.0 <25.0.0 (NOT latest)

### Required Checks Before Commit

```bash
flutter analyze   # Must pass
flutter format .  # Must pass
```

---

## MCP Tools (Configured)

- **context7**: Library documentation lookup
- **sequentialthinking**: Multi-step problem solving
- **memory**: Persistent knowledge store
- **fetch**: HTTP requests

### MCP Remote (OAuth)

```json
{
  "Sentry": {
    "command": "npx",
    "args": ["-y", "mcp-remote@latest", "https://mcp.sentry.dev/mcp"]
  }
}
```

---

## Non-Obvious Patterns

1. **Two-Phase DI**: Register services in correct phase — core services won't have auth tokens, auth services unavailable at login
2. **Web Auth**: MUST use `auth0-bridge.js` — native SDK fails in webview
3. **Provider Adapters**: Must implement OpenAI-compatible interface in `lib/services/providers/`
4. **SSH Tunnel**: Use `dartssh2` package only

---

## Integration Points

| Service          | Address         |
| ---------------- | --------------- |
| OpenClaw Gateway | localhost:18789 |
| LM Studio        | localhost:1234  |
| LLM Router       | localhost:1337  |
| API Backend      | localhost:3000  |
| Streaming Proxy  | localhost:8080  |

---

## References

- Full docs: `docs/`
- Copilot context: `.github/copilot-instructions.md`
- Claude Code hooks: `.claude/` (auto-format, security blocks)
- Skills: `/flutter-service`, `/api-endpoint`, `/flutter-database-schema`
