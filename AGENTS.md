# CloudToLocalLLM - Agent Instructions

This file provides guidance for AI coding agents working in this repository.

## Build/Lint/Test Commands

### Flutter (Frontend)
```bash
# Install dependencies
flutter pub get

# Run app (Linux desktop)
flutter run -d linux

# Run app (Web)
flutter run -d chrome

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
flutter format .

# Build release
flutter build web --release
```

### Node.js (Backend Services)

#### Root/Backend
```bash
npm install           # Development (updates package.json)
npm ci                # Production builds (faster, more reliable)
npm run dev           # Development with nodemon
npm run test          # Run all tests
npm run test:unit     # Unit tests only
npm run test:integration  # Integration tests
npm run lint          # ESLint
npm run format        # Prettier
```

#### API Backend (`services/api-backend/`)
```bash
cd services/api-backend
npm install
npm run dev
npm run test
npm run test:unit             # Test/api-backend/
npm run test:integration      # Test/api-backend/
npm run test:security         # Security tests
npm run test:tunnel           # Tunnel tests
npm run test:user-isolation   # User isolation tests
npm run test:auth             # Auth tests
npm run db:migrate            # Database migrations
npm run db:validate           # Validate migrations
npm run db:stats              # Migration stats
```

#### Streaming Proxy (`services/streaming-proxy/`)
```bash
cd services/streaming-proxy
npm install && npm run dev
```

#### Auth Backend (`backend/auth/`)
```bash
cd backend/auth
npm install && npm run dev
```

### Single Test Execution
```bash
# Run specific test file
node --experimental-vm-modules ./node_modules/jest/bin/jest.js path/to/test.test.js

# Run with verbose output
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --verbose

# Run with coverage
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --coverage
```

## CLI Tools Available

### Flutter CLI
- `flutter pub get` - Install Flutter dependencies
- `flutter run -d linux` - Run on Linux desktop
- `flutter run -d chrome` - Run on Chrome (Web)
- `flutter test` - Run Flutter tests
- `flutter analyze` - Analyze code for issues
- `flutter format .` - Format code
- `flutter build web --release` - Build web release

### Node.js/npm
- `npm install` - Install dependencies (dev mode)
- `npm ci` - Clean install (production mode)
- `npm run dev` - Start development server
- `npm test` - Run all tests
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier

### API Backend (`services/api-backend/`)
- `npm run start` - Start API backend server
- `npm run dev` - Start with nodemon for development
- `npm test` - Run all tests
- `npm run test:unit` - Run unit tests
- `npm run test:integration` - Run integration tests
- `npm run test:security` - Run security tests
- `npm run test:tunnel` - Run tunnel tests
- `npm run test:tunnel:unit` - Run tunnel unit tests
- `npm run test:tunnel:integration` - Run tunnel integration tests
- `npm run test:tunnel:security` - Run tunnel security tests
- `npm run test:user-isolation` - Run user isolation tests
- `npm run test:auth` - Run authentication tests
- `npm run test:security:verbose` - Run security tests with verbose output
- `npm run db:migrate` - Run database migrations
- `npm run db:validate` - Validate database migrations
- `npm run db:stats` - Show migration statistics
- `npm run db:test` - Test database connection
- `npm run db:setup-cloud-sql` - Setup Google Cloud SQL
- `npm run deploy:cloud-run` - Deploy to Google Cloud Run
- `npm run test:auth-flow` - Test authentication flow
- `npm run deploy:after-auth` - Deploy after auth setup
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier

### Streaming Proxy (`services/streaming-proxy/`)
- `npm run start` - Start proxy server
- `npm run health` - Run health check
- `npm run test-tunnel` - Test tunnel connection
- `npm run dev` - Start with inspect mode for debugging
- `npm test` - Run tests
- `npm run lint` - Run ESLint
- `npm run format` - Run ESLint with auto-fix

### SDK (`services/sdk/`)
- `npm run build` - Build TypeScript to JavaScript
- `npm run dev` - Build with watch mode
- `npm test` - Run Jest tests
- `npm run test:watch` - Run tests in watch mode
- `npm run lint` - Run ESLint on src/
- `npm run format` - Format source with Prettier
- `npm run prepublishOnly` - Build before publishing

### Auth Backend (`backend/auth/`)
- `npm run start` - Start auth handlers
- `npm run dev` - Start auth handlers with nodemon

### Single Test Execution (Jest)
```bash
# Run specific test file
node --experimental-vm-modules ./node_modules/jest/bin/jest.js path/to/test.test.js

# Run with verbose output
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --verbose

# Run with coverage
node --experimental-vm-modules ./node_modules/jest/bin/jest.js --coverage
```

### Git
- `git status` - Show working tree status
- `git diff` - Show unstaged changes
- `git log` - Show commit history
- `git add .` - Stage all changes
- `git commit -m "message"` - Create commit

### Docker
- `docker build` - Build Docker image
- `docker run` - Run Docker container
- `docker-compose up` - Start services with docker-compose
- `docker-compose down` - Stop services

### GitHub CLI (gh)
- `gh auth login` - Authenticate with GitHub
- `gh pr create` - Create pull request
- `gh pr view` - View pull request details
- `gh pr list` - List pull requests
- `gh issue create` - Create issue
- `gh issue list` - List issues
- `gh repo view` - View repository information
- `gh release create` - Create release
- `gh workflow run` - Run GitHub Actions workflow

### Azure CLI (az)
- `az login` - Log in to Azure
- `az aks get-credentials --resource-group rg --name cluster` - Get kubeconfig
- `az group create` - Create resource group
- `az aks create` - Create AKS cluster
- `az acr list` - List container registries
- `az vm list-sizes` - List VM sizes

### kubectl
- `kubectl get pods` - List pods
- `kubectl get services` - List services
- `kubectl get deployments` - List deployments
- `kubectl apply -f file.yaml` - Apply configuration
- `kubectl delete -f file.yaml` - Delete resources
- `kubectl logs pod-name` - View pod logs
- `kubectl exec -it pod-name -- sh` - Execute command in pod
- `kubectl describe pod pod-name` - Describe pod details

### Helm
- `helm install release-name chart-path` - Install chart
- `helm upgrade release-name chart-path` - Upgrade release
- `helm uninstall release-name` - Uninstall release
- `helm list` - List releases
- `helm repo add repo-name url` - Add repository
- `helm search repo keyword` - Search repository
- `helm status release-name` - Show release status

### Cloudflare (cloudflare)
- `cloudflare zone list` - List zones
- `cloudflare dns record list` - List DNS records
- `cloudflare dns record create` - Create DNS record
- `cloudflare cache purge` - Purge cache

### MCP Tools
- `mcp-sequentialthinking` - Structured problem-solving
- `mcp-context7` - Library documentation lookup
- `mcp-memory` - Knowledge graph storage

## MCP Tools Installation

### Required MCP Tools for Agents
```bash
# Run the setup script
./setup-opencode-mcp.sh

# Or install manually
cd ~/.config/opencode
npm install @modelcontextprotocol/server-sequential-thinking @upstash/context7-mcp @modelcontextprotocol/server-memory

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Available MCP Tools
- **sequentialthinking**: Dynamic problem-solving through structured thinking process
- **context7**: Retrieve up-to-date library documentation and code examples
- **memory**: Persistent knowledge graph for storing information across sessions

## Code Style Guidelines

### Node.js (Express.js)

#### Imports & Dependencies
- Use ES modules (`"type": "module"` in package.json)
- Group imports: built-ins, third-party, local
- Use named imports for clarity

#### Error Handling Pattern
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
- Use `winston` for structured logging
- Include correlation IDs for request tracking
- Log levels: ERROR, WARN, INFO, DEBUG
- Never log secrets or user credentials (hash user IDs)

#### API Development
- Use Express middleware for authentication (`express-oauth2-jwt-bearer`)
- Implement proper CORS configuration
- Use Zod for input validation
- Return consistent error responses

#### Naming Conventions
- Files: `kebab-case.js`
- Classes: `PascalCase`
- Functions/variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- Async functions: suffix with `Async` when ambiguous

### Flutter/Dart

#### Dependency Injection
- Use `GetIt` for service locator pattern
- Register services in `lib/di/locator.dart`
- Setup functions: `setupCoreServices()`, `setupAuthenticatedServices()`

#### State Management
- Use `provider` for simple state
- Complex state: consider other patterns

#### Web-Specific
- Use `dart:js_interop` (replaces deprecated `js` package)
- Platform detection: `kIsWeb` from `package:flutter/foundation.dart`
- Handle OAuth redirects properly

#### Code Quality
- Run `flutter analyze` before committing
- Use `flutter format` for consistent formatting
- Prefer `debugPrint()` over `print()` for logging

### Docker Container Security
- **NEVER run Flutter/Node.js as root**
- Use `USER 1000:1000` or container default UID before any application commands
- Multi-stage builds: build as root, run as non-root
- Layer caching: copy package files first, install deps, then copy source

### Free Tier Only Policy
 
**STRICTLY ENFORCED**: All cloud resources must stay within free tier limits. Non-compliance is not acceptable.
 
### Azure Free Tier Limits (Must Respect)
- **Compute**: Azure B-series VMs (B1s/B2s) within free monthly limits.
- **Kubernetes**: AKS Free Tier (Cluster management is free).
- **Databases**: Azure Database for PostgreSQL Flexible Server (Free Tier B1ms for 12 months).
- **Storage**: Managed Disks (P6 or smaller within free limits), Blob Storage.
- **Bandwidth**: First 100GB/month outbound is free.

### Prohibited Resources (Will Cause Charges)
- **NEVER create**: Standard SKU Load Balancers (Basic is free, or use NodePort/Ingress/Tunnel).
- **NEVER create**: Application Gateway or Azure Front Door (unless within credits).
- **NEVER create**: Azure Container Registry (ACR) unless Basic SKU and necessary (use GHCR).
- **NEVER create**: Premium SSDs or large Managed Disks.

### Required Pre-Creation Checks
Before creating any Azure resource:
1. Verify it has a free tier option.
2. Check current usage: `az consumption usage list`.
3. Use Azure Pricing Calculator.

### Post-Creation Validation
After any `az` command that creates resources:
```bash
# Verify no paid resources were created
az resource list --output table
```

### Free Tier Alternatives
| Paid Resource Type | Free Tier Alternative |
|-------------------|---------------------|
| AKS Standard LB | AKS Basic LB or Cloudflare Tunnel |
| ACR (Paid) | ghcr.io or Docker Hub |
| Large VMs | Standard_B2s / B1s |


### Violation Response
If charges are detected:
1. Immediately identify resource: `az consumption usage list --query "[?pretaxCost > '0']"`
2. Delete resource: `az resource delete --id <resource-id>`
3. Report violation and remediation

## Security Best Practices
- Never hardcode secrets, API keys, or credentials
- Use environment variables or secret management systems
- Validate and sanitize all user inputs
- Run containers as non-root users
- Use connection pooling for databases
- Implement request rate limiting

## Project Structure

```
CloudToLocalLLM/
├── lib/                  # Flutter app
│   ├── services/         # LLM providers, auth, tunnel services
│   ├── widgets/          # UI components
│   ├── di/               # Dependency injection (GetIt)
│   └── utils/            # Utilities
├── services/
│   ├── api-backend/      # Main API server
│   ├── streaming-proxy/  # WebSocket proxy
│   └── sdk/              # Client SDK
├── backend/
│   └── auth/             # Auth0 JWT validation
├── config/
│   └── mcp/              # MCP server configurations
├── docs/                 # Documentation
└── test/                 # Test files
```

## Git Workflow

- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- Keep commits focused and atomic
- Use agent prefix for automated commits: `ai(OpenCode): description`

## Key Files & Locations

- Flutter app: `lib/`, `pubspec.yaml`
- Node services: `services/api-backend/`, `backend/auth/`
- MCP configs: `config/mcp/`, `.vscode/settings.json`
- Auth: Auth0 (web uses JS bridge, desktop uses native flows)
- Local models: Ollama/LM Studio via OpenAI-compatible APIs

## Developer Tips

1. **Sequential Thinking**: Use for complex problem-solving, debugging, architectural tasks
2. **Context7**: Look up package docs, API patterns, best practices
3. **Memory**: Store project decisions and architectural notes
4. **Documentation-First**: Review relevant docs before coding
5. **Linting**: Always fix linter errors before committing
6. **Testing**: Fix failing tests before committing

## Additional Resources

- See `.cursor/rules/` for framework-specific guidelines
- See `.github/copilot-instructions.md` for AI agent operational rules
- See `docs/development/` for detailed development documentation
