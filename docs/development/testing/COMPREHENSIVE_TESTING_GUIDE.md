# Comprehensive Testing Guide

This guide describes the current test entry points for CloudToLocalLLM.

## Test Layout

| Path | Purpose |
| --- | --- |
| `test/` | Flutter tests, integration tests, E2E specs, root API backend Jest tests |
| `test/api-backend/` | API backend Jest tests |
| `test/services/` | Flutter service tests |
| `test/widgets/` | Flutter widget tests |
| `test/integration/` | Flutter integration/property tests and selected JS integration tests |
| `test/e2e/` | Playwright-style E2E specs |
| `test/powershell/` | PowerShell test scripts |
| `services/sdk/tests/` | SDK Jest tests |
| `services/streaming-proxy/src/` | Streaming proxy TypeScript unit tests |

## Flutter Tests

Run from the repository root:

```bash
flutter analyze
flutter test
flutter test test/services/avatar_state_service_test.dart
flutter test --coverage
```

Use Flutter tests for app services, widgets, platform abstraction, settings, onboarding, avatar, vision, and desktop-control behavior.

## Root Node Tests

Run from the repository root:

```bash
npm test
```

Root Jest uses `jest.config.js` and matches `**/test/**/*.test.js`. The config intentionally ignores several tests that require live infrastructure.

## API Backend Tests

Run from `services/api-backend/`:

```bash
npm test
npm run test:unit
npm run test:integration
npm run test:auth
npm run test:security
npm run test:tunnel
npm run test:user-isolation
```

API backend tests live in `test/api-backend/` at the repository root.

Single test example:

```bash
cd services/api-backend
npm test ../../test/api-backend/security/authentication-authorization.test.js
```

## Streaming Proxy Tests

Run from `services/streaming-proxy/`:

```bash
npm test
npm run build
npm run lint
```

The streaming proxy uses Node `>=22 <25`, ESM, TypeScript, and `ts-jest`.

## SDK Tests

Run from `services/sdk/`:

```bash
npm run build
npm test
npm run lint
```

The SDK supports Node `>=18`.

## PowerShell Tests

PowerShell tests live under `test/powershell/`.

```powershell
pwsh test/powershell/CI-TestRunner.ps1
```

## Documentation Tests

Canonical docs:

```bash
npm run docs:links
```

Full markdown tree:

```bash
npm run docs:links:all
```

The full-tree command currently covers historical docs as well. It is useful during cleanup, but the canonical command is the quality gate for current docs.

## Environment Notes

- API backend and streaming proxy require Node `>=22 <25`.
- SDK requires Node `>=18`.
- Backend database/integration tests may require PostgreSQL, Redis, Auth0-like JWT configuration, or other live services.
- Flutter web/native tests must respect conditional imports and platform stubs.

## Related Documentation

- [Developer Onboarding](../DEVELOPER_ONBOARDING.md)
- [Development Workflow](../DEVELOPMENT_WORKFLOW.md)
- [System Architecture](../../architecture/SYSTEM_ARCHITECTURE.md)
