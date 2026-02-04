# Zoidbot - Agent Instructions

This file provides guidance for AI coding agents working in this repository.

## Build/Lint/Test Commands

### Flutter (Frontend)
```bash
flutter pub get              # Install dependencies
flutter run -d linux         # Run on Linux desktop
flutter run -d chrome        # Run on Chrome (Web)
flutter test                 # Run all tests
flutter test test/widget_test.dart  # Run single test file
flutter analyze              # Analyze code for issues
flutter format .             # Format code
flutter build web --release  # Build web release
```

### API Backend (`services/api-backend/`)
```bash
npm install && npm run dev   # Start development server
npm test                     # Run all tests
npm run test:unit            # Unit tests only
npm run test:auth            # Authentication tests
npm run test:user-isolation  # User isolation tests
npm run test:security        # Security tests
npm run lint                 # ESLint
npm run format               # Prettier

# Run single test file (Jest with ES modules)
node --experimental-vm-modules node_modules/jest/bin/jest.js path/to/test.test.js
node --experimental-vm-modules node_modules/jest/bin/jest.js --verbose  # With verbose output
```

### SDK (`services/sdk/`)
```bash
npm install && npm run build  # Build TypeScript
npm run dev                   # Build with watch mode
npm test                      # Run Jest tests
npm run lint && npm run format
```

### Streaming Proxy (`services/streaming-proxy/`)
```bash
npm install && npm run dev    # Start development
npm test && npm run lint
```

## Project Structure
```
Zoidbot/
├── lib/                      # Flutter app (Dart)
│   ├── services/             # LLM providers, auth, tunnel services
│   ├── widgets/              # UI components
│   ├── di/                   # Dependency injection (GetIt)
│   └── utils/                # Utilities
├── services/
│   ├── api-backend/          # Main API server (Express.js)
│   ├── streaming-proxy/      # WebSocket proxy
│   └── sdk/                  # TypeScript client SDK
├── backend/auth/             # Auth0 JWT validation
├── test/                     # Test files
└── docs/                     # Documentation
```

## Code Style Guidelines

### Node.js / TypeScript
- **ES Modules**: Use `"type": "module"` in package.json
- **Imports**: Group by built-ins, third-party, local; use named imports
- **Files**: `kebab-case.js` for files
- **Naming**: `PascalCase` for classes, `camelCase` for functions/variables, `UPPER_SNAKE_CASE` for constants
- **Async**: Suffix with `Async` when ambiguous

#### Error Handling
```javascript
try {
  const result = await someAsyncOperation();
  return result;
} catch (error) {
  logger.error('Operation failed', { error, context });
  throw new Error('User-friendly error message');
}
```

#### Logging
- Use `winston` for structured logging with correlation IDs
- Log levels: ERROR, WARN, INFO, DEBUG
- **Never** log secrets or credentials

### Flutter / Dart
- **DI**: Use `GetIt` via `lib/di/locator.dart` (`setupCoreServices()`, `setupAuthenticatedServices()`)
- **State**: Use `provider` for state management
- **Web**: Use `dart:js_interop` (not deprecated `js` package), detect platform with `kIsWeb`
- **Logging**: Prefer `debugPrint()` over `print()`
- **Pre-commit**: Always run `flutter analyze` and `flutter format` before committing

### TypeScript Configuration (SDK)
- Target: ES2020, Module: ESNext, Strict mode enabled
- Generate declaration files and source maps

## Security Requirements
- **Never** hardcode secrets, API keys, or credentials
- Use environment variables or secret management
- Validate and sanitize all user inputs
- Run containers as non-root users (`USER 1000:1000`)
- Implement request rate limiting

## Git Workflow
- **Conventional commits**: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- **Agent prefix**: `ai(AgentName): description` for automated commits
- Keep commits focused and atomic
- Run linter and fix errors before committing

## Key Integration Notes
- **Auth**: Auth0 - web uses `auth0-bridge.js`, desktop uses native flows
- **Local models**: Ollama/LM Studio via OpenAI-compatible APIs in `lib/services/`
- **Database**: PostgreSQL for server sessions, local SQLite/IndexedDB for client

## AI Agent Operational Rules
1. **Minimal changes**: Keep edits scoped to the issue; don't change unrelated files
2. **Feature branches**: If multiple agents may touch a file, create a branch and PR
3. **TodoWrite tool**: Use to track multi-step work; update as you progress
4. **Root directory**: Do NOT create new files in repo root (use docs/, config/, scripts/)
5. **Linting first**: Fix all linter errors before committing

## Engine Requirements
- **Node.js**: >=22.0.0 <25.0.0 (API backend)
- **Node.js**: >=18.0.0 (SDK)
- **Dart SDK**: >=3.5.0 <4.0.0

## Free Tier Policy
All cloud resources must stay within free tier limits:
- **Azure**: B-series VMs (B1s/B2s) for Docker Swarm
- **Never create**: Standard SKU Load Balancers, Application Gateway, Premium SSDs
- **Use**: ghcr.io instead of ACR, Cloudflare Tunnel for ingress

## Key Dependencies
| Component | Key Libraries |
|-----------|--------------|
| API Backend | Express 5, Zod, Winston, JWT, PostgreSQL |
| Flutter | provider, GetIt, auth0_flutter, langchain |
| SDK | TypeScript, Axios, Zod |

## Additional Resources
- `.github/copilot-instructions.md` - Copilot/AI agent operational rules
- `docs/development/` - Detailed development documentation
- `config/mcp/` - MCP server configurations
