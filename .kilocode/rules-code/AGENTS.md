# AGENTS.md - Code Mode

This file provides coding-specific guidance for AI agents.

## Non-Obvious Coding Rules

### Flutter Service Registration
- Services MUST be registered in `lib/di/locator.dart` in either `setupCoreServices()` (pre-auth) or `setupAuthenticatedServices()` (post-auth)
- Adding services to wrong phase causes runtime errors - core services won't have auth tokens, auth services won't be available at login

### Provider Adapter Pattern
- New LLM providers must implement adapter in `lib/services/providers/` following existing patterns (e.g., `zhipu_adapter.dart`)
- Adapters must implement OpenAI-compatible interface for router to work
- Model tier assignment in `lib/services/model_tiers.dart` required for rate limiting

### Desktop/Web Conditional Imports
- Never use `dart:html` directly - use conditional imports with `*_stub.dart` pattern
- Web detection: `kIsWeb` from `flutter/foundation.dart` - NOT platform detection packages
- Stub files needed for desktop when using web-only packages

### Auth0 Token Storage
- Desktop: tokens stored in encrypted SQLite via `flutter_secure_storage`
- Web: MUST use `auth0-bridge.js` - native SDK will fail in webview
- Bridge stores tokens in sessionStorage, not localStorage

### Database (Drift)
- Tables defined in `lib/database/` with code generation
- Run `dart run build_runner build` after schema changes
- Queries MUST use generated code - raw SQL will fail type checking

### SSH Tunnel Code
- Use `dartssh2` package only - other SSH libraries incompatible with tunnel architecture
- Connection health monitoring required - tunnel service tracks connection state

## Required Linter Checks Before Commit
```bash
flutter analyze   # Must pass with no errors
flutter format .  # Must pass
```
