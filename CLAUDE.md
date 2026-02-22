# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloudToLocalLLM is an OpenClaw Agent Manager — a privacy-first desktop AI companion organized around **Five Core Pillars**:

1. **Chat**: Unified chat interface with streaming responses, conversation persistence, multi-model support
2. **OpenClaw Gateway Management**: Start, stop, monitor OpenClaw Gateway (localhost:18789), health monitoring
3. **Evolving Avatar**: Visual character (Zoidbot) with personality engine, evolution tracker, memory system
4. **Desktop Control**: GUI automation, window management, file operations, clipboard, command execution
5. **Vision**: Screen capture/analysis, camera input, OCR, continuous monitoring

Architecture: Flutter frontend (Windows, Linux, Web) + Node.js backend services.

**See**: `docs/development/IMPLEMENTATION_PLAN.md` for detailed implementation status.

## Commands

### Flutter (Frontend)

```bash
# Install dependencies
flutter pub get

# Run applications
flutter run -d linux          # Linux desktop
flutter run -d windows        # Windows desktop
flutter run -d chrome         # Web (Chrome)
flutter run -d edge           # Web (Edge)

# Code quality
flutter analyze               # Static analysis
flutter test                  # Run all tests
flutter format .              # Format code

# Build
flutter build web --release   # Web release build
flutter build linux --release  # Linux release build

# Run specific test (Flutter test file matching)
flutter test test/path/to/test_file.dart
```

### Backend Services

All backend services are in `services/`:

```bash
# API Backend (Express.js)
cd services/api-backend
npm install
npm run dev                   # Development with nodemon
npm test                      # Run all tests
npm run test:unit             # Unit tests only
npm run test:auth             # Authentication tests
npm run test:security         # Security tests
npm run test:tunnel           # Tunnel tests (all)
npm run test:tunnel:unit      # Tunnel unit tests
npm run test:tunnel:security  # Tunnel security tests
npm run lint                  # ESLint
npm run format                # Prettier

# SDK (TypeScript)
cd services/sdk
npm install
npm run build                 # TypeScript compilation
npm run dev                   # Watch mode
npm test

# Streaming Proxy
cd services/streaming-proxy
npm install
npm run dev                   # Development with inspect
npm run lint                  # ESLint
npm run health                # Health check

# Tailscale Relay
cd services/tailscale-relay
npm install
npm run dev                   # Development with nodemon
```

### Database Operations

```bash
cd services/api-backend
npm run db:migrate            # Run PostgreSQL migrations
npm run db:validate           # Validate schema
npm run db:stats              # Database statistics
```

### LLM Router (Flutter)

The Flutter app runs an embedded HTTP server that routes LLM requests:

```bash
# Router runs automatically on app start (port 1337)
# Health check
curl http://localhost:1337/health

# List available models
curl http://localhost:1337/v1/models

# Chat completion (OpenAI-compatible)
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"glm-4","messages":[{"role":"user","content":"Hello"}]}'
```

## Architecture

### Five Core Pillars Overview

The app is organized around five pillars. See `docs/development/IMPLEMENTATION_PLAN.md` for detailed status.

| Pillar | Status | Key Files |
|--------|--------|-----------|
| 1. Chat | ✅ Core existing | `streaming_chat_service.dart`, `home_layout.dart` |
| 2. OpenClaw Manager | ✅ Core existing | `connection_manager_service.dart`, `agent_status_service.dart` |
| 3. Evolving Avatar | ✅ Phase 1 Complete | `avatar_widget.dart`, `personality_engine.dart`, `evolution_tracker.dart` |
| 4. Desktop Control | 🔲 Partial | `gui_automation_service.dart` (planned: window management, clipboard) |
| 5. Vision | 🔲 Partial | `gui_automation_service.dart` (planned: camera, OCR) |

**Implementation phases** (see `docs/development/IMPLEMENTATION_PLAN.md`):
- Phase 1: Multi-model selector, gateway start/stop control, gateway dashboard
- Phase 2: Personality engine, evolution tracker, window/clipboard management
- Phase 3: Camera/OCR, avatar memory system, achievements

### Service Layer Pattern (Flutter)

The Flutter app uses a layered service architecture with dependency injection:

- **lib/di/locator.dart**: GetIt service locator with two-phase initialization
  - `setupAuthenticatedServices()`: Entry point that delegates to `setupCoreServices()` first, then registers auth-dependent services
  - `setupCoreServices()`: Services available before authentication (settings, auth, detection, local brain, token storage)

- **Service Categories**:
  - **Core Services** (pre-auth): `SettingsPreferenceService`, `AuthService`, `ThemeProvider`, `TokenStorageService`, `SessionStorageService`, `PlatformDetectionService`, `PlatformAdapter`
  - **Data Services**: `LocalBrain` (SQLite), `BrainSyncService`, `FullContextIndexer`, `ConversationStorageService`
  - **Router Services**: `RouterServer`, `RateLimitManager`, provider adapters in `lib/services/providers/`
  - **Authenticated Services**: `TunnelService`, `LLMProviderManager`, `StreamingChatService`, `ConnectionManagerService`, `UnifiedConnectionService`
  - **Monitoring Services**: `BehaviorWarningsService`, `SubagentRegistryService`, `AgentStatusService`, `AgentLifecycleService`, `LLMAuditService`
  - **Integration Services**: `GoogleWorkspaceService`, `LangChainIntegrationService`, `LangChainPromptService`, `LangChainRAGService`
  - **Admin Services**: `AdminService`, `AdminCenterService`, `AdminDataFlushService`, `EnhancedUserTierService`
  - **Setup/Onboarding**: `AppInitializationService`, `SetupStatusService`, `SetupWizardService`, `WebDownloadPromptService`, `DesktopClientDetectionService`
  - **OpenClaw Manager**: `GatewayControlService` in `lib/services/openclaw_manager/`
  - **Platform Services**: Uses conditional imports for desktop vs web (e.g., `*_stub.dart` files)
  - **Utility Services**: `SettingsImportExportService`, `UrlSchemeRegistrationService`, `ProviderConfigurationManager`, `ProviderDiscoveryService`, `LLMErrorHandler`

- **Platform Abstraction**: Web-specific code uses `dart:js_interop` and `dart:html` conditional imports with stub implementations for desktop

### Backend Services

- **api-backend**: Main Express.js server with Auth0 JWT auth, PostgreSQL, rate limiting, OpenTelemetry tracing
  - **Routes**: Admin, auth, tunnels, conversations, bridge polling, agent events
  - Additional routes: `behavior-warnings-routes.js`, `context-usage-routes.js`, `models-routes.js`, `subagent-registry-routes.js`
- **postgres**: PostgreSQL database configuration and migrations
- **sdk**: TypeScript SDK for third-party integrations
- **streaming-proxy**: WebSocket proxy for real-time LLM communication (zoidbot-tunnel-container)
- **tailscale-relay**: Tailscale tunnel relay service for secure remote access

### Chat Interface (Pillar 1)

- **StreamingChatService** (`lib/services/streaming_chat_service.dart`): Real-time token-by-token streaming
- **HomeLayout** (`lib/screens/home/home_layout.dart`): Unified chat UI
- **ConversationStorageService** (or LocalBrain): Persistent conversation history
- Message bubbles with markdown rendering, code highlighting

**Planned**: Multi-model selector UI, advanced search, rich messages (images, code), export/import.

### LLM Provider System

Supports multiple local LLM providers:
- **OpenClaw Gateway**: Primary local provider, auto-discovery on localhost:18789
- **LM Studio**: Alternative local provider (localhost:1234)
- **Ollama**: Alternative local provider (localhost:11434)

**Provider Architecture**:
- `ProviderConfigurationManager`: Manages provider configurations with persistence
- `ProviderDiscoveryService`: Auto-scans and configures discovered providers
- `LLMProviderManager`: Orchestrates provider selection and switching
- `LLMErrorHandler`: Centralized error handling with provider-aware recovery
- Auto-configuration on first discovery with periodic rescanning

**LangChain Integration**:
- `LangChainIntegrationService`: Provider initialization for LangChain workflows
- `LangChainPromptService`: Prompt template management
- `LangChainRAGService`: RAG (Retrieval Augmented Generation) capabilities

### Desktop Control & Vision (Pillars 4 & 5)

**Desktop Control**:
- **GuiAutomationService** (`lib/services/gui_automation_service.dart`): Screenshot capture, vision-powered automation
- **SystemControlService** (`lib/services/system_control_service.dart`): System operations, command execution
- **GuiAutomationScreen** (`lib/screens/gui_automation_screen.dart`): UI for desktop automation

**Vision** (integrated with desktop control):
- Screen capture and analysis via OpenClaw vision models
- OCR capabilities
- **Planned**: Region capture, camera input, continuous monitoring

### OpenClaw Gateway Management (Pillar 2)

The app manages the OpenClaw Gateway service (localhost:18789):
- **GatewayControlService** (`lib/services/openclaw_manager/gateway_control_service.dart`): Start, stop, monitor the gateway
- **ConnectionManagerService** (`lib/services/connection_manager_service.dart`): Connection handling
- **AgentLifecycleService** (`lib/services/agent_lifecycle_service.dart`): Agent lifecycle management
- **AgentStatusService** (`lib/services/agent_status_service.dart`): Status polling
- Health monitoring, configuration management
- Multi-provider support with automatic fallback

### LLM Router System

The Flutter app exposes an OpenAI-compatible HTTP server (port 1337) for routing requests to multiple cloud providers:

- **RouterServer** (`lib/services/router_server.dart`): Embedded shelf HTTP server
- **Provider Adapters** (`lib/services/providers/`):
  - `zhipu_adapter.dart` - Zhipu AI (GLM models)
  - `google_adapter.dart` - Google (Gemini models)
  - `moonshot_adapter.dart` - Moonshot AI
- **Rate Limiting**: `RateLimitManager` tracks concurrent requests per model
- **Model Tiers**: `lib/services/model_tiers.dart` defines capacity tiers (critical/high/medium/unlimited)
- **Fallback Logic**: Automatically switches to fallback models when rate limits reached
- **Database**: `ModelCapacity` and `LlmRequests` tables (Drift/SQLite) track usage

Router endpoints: `GET /v1/models`, `POST /v1/chat/completions`, `GET /health`

### Avatar System (Zoidbot)

The evolving avatar (Pillar 3) is managed through:
- **AvatarWidget** (`lib/features/avatar/avatar_widget.dart`): Visual 2D/3D character renderer with state-based reactions (idle/thinking/working/error/happy)
- **BrainInsightWidget** (`lib/components/brain_insight_widget.dart`): Personality/memory visualization

**Implemented services** (lib/services/avatar/):
- `personality_engine.dart` - Trait management and evolution validation
- `evolution_tracker.dart` - Conversation depth analysis and evolution pattern detection

**Avatar Personality Engine:**
The personality engine manages the avatar's evolving personality based on conversation patterns:

```dart
// Get current avatar state
final profile = await personalityEngine.getPersonality();
print('${profile.agentName} - Stage: ${profile.evolutionStage}');

// Update personality traits
final newTraits = PersonalityTraits(
  formality: 0.7,
  humor: 0.6,
  enthusiasm: 0.8,
  empathy: 0.9,
);
await personalityEngine.updatePersonality(newTraits);

// Request evolution (requires sufficient conversation depth)
final decision = await personalityEngine.validateEvolutionRequest(
  'knowledge_seeker',
  'User has demonstrated consistent deep learning',
);
if (decision.approved) {
  print('Evolved to ${decision.newStage}');
}
```

**Evolution Stages:**
1. **curious_explorer** (initial) - Default stage for new avatars
2. **knowledge_seeker** - Unlocked after 5+ deep conversations with avg novelty > 0.5
3. **wise_companion** - Further evolution stages
4. **enlightened_guide** - Highest evolution stage

**Evolution Criteria:**
- At least 5 deep conversations (complexity score > 0.7)
- Average novelty score > 0.5 across all conversations
- Collaborative approval between user and AI

**Personality Traits:**
- **formality** (0.0-1.0): How formal the avatar communicates
- **humor** (0.0-1.0): Frequency and intensity of humor
- **enthusiasm** (0.0-1.0): Energy and excitement levels
- **empathy** (0.0-1.0): Emotional understanding and support

**Evolution API Endpoints** (Router Server):
```bash
# Get current avatar state
curl http://localhost:1337/avatar/state

# Update personality traits
curl -X POST http://localhost:1337/avatar/traits \
  -H "Content-Type: application/json" \
  -d '{"traits": {"formality": 0.7, "humor": 0.6, "enthusiasm": 0.8, "empathy": 0.9}}'

# Request evolution
curl -X POST http://localhost:1337/avatar/evolution/request \
  -H "Content-Type: application/json" \
  -d '{"stage": "knowledge_seeker", "reason": "User learning journey complete"}'
```

**Planned services** (lib/services/avatar/):
- `memory_service.dart` - Conversation embeddings
- `achievement_service.dart` - Unlockables

See IMPLEMENTATION_PLAN.md for database schema (AvatarProfiles, Achievements tables).

### Additional Services

**Brain & Memory Services**:
- `LocalBrain`: SQLite-based local storage engine with encryption
- `BrainSyncService`: Synchronizes local conversations with cloud backbone
- `FullContextIndexer`: System-wide file indexing in local brain for context retrieval

**User Management & Onboarding**:
- `SetupStatusService`: Tracks first-run and setup completion state
- `SetupWizardService`: Manages the onboarding wizard flow
- `DesktopClientDetectionService`: Detects client type and platform
- `WebDownloadPromptService`: Handles download prompts for web users
- `EnhancedUserTierService`: Advanced subscription tier management
- `UserDataService`: User data management operations

**Admin & Management**:
- `AdminService`: Core admin operations
- `AdminCenterService`: Enhanced admin interface
- `AdminDataFlushService`: Data flush and cleanup operations
- `BehaviorWarningsService`: User behavior warnings and metrics
- `SubagentRegistryService`: Registry for managing AI subagents

**Integration Services**:
- `GoogleWorkspaceService`: Personal Gmail/Calendar integrations with OAuth
- `DiscordService`: Discord bot integration
- `GithubReleaseService`: GitHub release tracking and updates
- `PaymentGatewayService`: Payment processing via Stripe
- `DownloadManagementService`: Download queue and management

**Platform & UI Services**:
- `WindowManagerService`: Window management (desktop only)
- `NativeTrayService`: System tray integration (desktop only)
- `AccessibilityService`: Accessibility features and settings
- `ThemeProvider`: Application theme management

**Utility Services**:
- `VersionService`: Application version tracking
- `SettingsValidator`: Settings validation
- `PrivacyStorageManager`: Privacy-aware storage management
- `LogBufferService`: Log buffering and management
- `DashboardService`: Dashboard data aggregation
- `NavigationService`: Navigation state management
- `SessionBootstrapService`: Session bootstrap operations

### Tunnel/Cloud Architecture

The tunnel system provides secure remote access to local LLM models:

- **SSH Tunneling**: Secure tunneling via `ssh2` library with key-based authentication
- **TunnelService**: Main service managing tunnel lifecycle with WebSocket connections
- **TunnelConfigManager**: Configuration persistence and management
- **Connection Resilience**:
  - `ConnectionStateTracker`: Tracks connection state transitions
  - `ConnectionRecovery`: Automatic reconnection with exponential backoff
  - `ReconnectionManager`: Orchestrates reconnection attempts
  - `BackpressureManager`: Handles flow control for streaming data
- **Diagnostics Suite** (`lib/services/tunnel/diagnostics/`):
  - `DiagnosticTestSuite`: Comprehensive diagnostic tests
  - `DiagnosticReportGenerator`: Generates diagnostic reports
  - Health checks and connection quality metrics
- **Request Management**:
  - `PersistentRequestQueue`: Queues requests during disconnection
  - `RequestPersistenceManager`: Manages request persistence
  - `RequestTimeoutHandler`: Handles request timeouts
- **Metrics**: Prometheus metrics collection via `MetricsCollector` and `MetricsExporter`
- **Error Handling**: `ErrorCategorization` and `ErrorRecoveryStrategy` for resilient error handling

### Data Storage

- **Server**: PostgreSQL for user sessions, cloud storage, tunnel configs
- **Desktop (Client)**:
  - SQLite with encryption for conversation history (`LocalBrain`)
  - Router tables: `ModelCapacity` (rate limit tracking), `LlmRequests` (request history)
- **Web**: IndexedDB for conversations, zero local persistence for sensitive data

### Observability & Monitoring

The application uses comprehensive observability stack:

- **OpenTelemetry Tracing**: Distributed tracing across all backend services
  - Auto-instrumentations via `@opentelemetry/auto-instrumentations-node`
  - OTLP HTTP exporter for trace export
  - Trace context propagation for tunnel and streaming-proxy services

- **Prometheus Metrics**: Custom metrics collection via `prom-client`
  - HTTP request metrics, tunnel health metrics, rate limiting metrics
  - Database performance tracking, connection pool monitoring

- **Winston Logging**: Structured logging with multiple transports
  - Console transport for development
  - File transport for persistent logs
  - Log levels: error, warn, info, debug

- **Sentry Error Tracking**: Production error monitoring
  - Stack trace aggregation
  - Release tracking
  - Performance monitoring
  - User context for errors

- **Health Check Endpoints**:
  - `/health` on router server (port 1337)
  - Health check script in streaming-proxy: `npm run health`

### Security Architecture

**Authentication & Authorization**:
- Auth0 JWT authentication with RS256 signing
- JWKS (JSON Web Key Set) for public key verification via `jwks-rsa`
- Token refresh flow with refresh token management
- Role-based access control (RBAC) for admin operations

**API Security**:
- `express-oauth2-jwt-bearer` middleware for JWT validation
- Rate limiting via `express-rate-limit` with Redis backend
- Helmet middleware for HTTP security headers
- CORS configuration for cross-origin requests
- Input validation via `zod` schemas

**Tunnel Security**:
- SSH tunneling with key-based authentication
- WebSocket heartbeat for connection health monitoring
- Connection state tracking and automatic reconnection
- Error categorization and recovery strategies

**Secrets Management**:
- Environment variables for sensitive configuration
- Claude Code hooks prevent editing of `.env`, `.env.production`, secret files
- Encrypted token storage in SQLite (desktop)

## Project Conventions

### File Naming

- **Dart**: `snake_case.dart` for files, `PascalCase` for classes
- **TypeScript/JavaScript**: `kebab-case.js` for files, `PascalCase` for classes
- **Tests**: `*.test.js` or `*.unit.test.js` for Jest test files
- **Constants**: `UPPER_SNAKE_CASE`

### Commit Messages

- Conventional commits with agent prefix for automated commits: `ai(AgentName): description`
- Example: `ai(Claude): add provider auto-discovery feature`

### Platform Detection

Use `kIsWeb` from Flutter Foundation to detect web platform. For desktop-specific code, use conditional imports:

```dart
import 'package:zoidbot/services/some_service.dart'
    if (dart.library.html) 'package:zoidbot/services/some_service_web.dart';
```

### Error Handling

- Backend: Winston logging with Sentry integration
- Frontend: `debugPrint` for development, Sentry for error tracking
- Service initialization uses timeouts and graceful degradation

### Testing

- Backend: Jest with separate unit/integration/security test suites
- Tests located in `test/api-backend/` organized by feature
- Use `--forceExit` flag for Jest to ensure clean exit
- Test categories:
  - **Unit tests**: Feature-specific logic testing (e.g., `alerting-service.unit.test.js`)
  - **Integration tests**: End-to-end workflows (e.g., `backup-recovery-integration.test.js`)
  - **Security tests**: `test/api-backend/security/` directory
  - **Property-based tests**: Use `fast-check` for invariant verification

Run specific test suites:
```bash
cd services/api-backend
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

# Run specific test file
npm test ../../test/api-backend/security/authentication-authorization.test.js
```

## Environment Requirements

- **Flutter**: 3.5+
- **Dart SDK**: >=3.5.0 <4.0.0
- **Node.js**: >=22.0.0 <25.0.0 (API backend and streaming proxy) - exact version enforced in package.json
- **PostgreSQL**: For backend database (Cloud SQL or local)
- **Redis**: For rate limiting cache (optional, can use in-memory)
- **LLM Providers**:
  - Local: OpenClaw Gateway (localhost:18789), LM Studio (localhost:1234), Ollama (localhost:11434)
  - Cloud: Zhipu AI, Google Gemini, Moonshot (configured via router)
- **Router Port**: 1337 (embedded Flutter HTTP server)
- **NVIDIA Drivers**: Required for GPU acceleration (RTX 30/40 series recommended)
- **Tailscale** (optional): For tailscale-relay service
- **Auth0**: Required for authentication (configure in `config/.env.production`)

## Key Configuration Files

- `pubspec.yaml`: Flutter dependencies and project config
- `analysis_options.yaml`: Dart lint rules (strong mode enabled, no implicit casts)
- `lib/di/locator.dart`: Service registration and dependency injection (core + authenticated phases)
- `lib/services/router_server.dart`: LLM router HTTP server (port 1337)
- `lib/services/model_tiers.dart`: Model capacity tier definitions (critical/high/medium/unlimited)
- `lib/services/openclaw_manager/gateway_control_service.dart`: OpenClaw Gateway management
- `lib/services/tunnel/tunnel_config_manager.dart`: Tunnel configuration management
- `services/api-backend/package.json`: Node.js dependencies and scripts
- `services/streaming-proxy/package.json`: Streaming proxy service
- `services/tailscale-relay/package.json`: Tailscale relay service
- `config/.env.production.template`: Environment variable template
- `SPEC.md`: Master specification with project vision and architecture

## MCP Integration

- Workspace MCP servers configured in `.claude/settings.json`
- Available tools: context7, sequentialthinking, memory, Sentry
- Remote MCP servers use OAuth via `mcp-remote` wrapper

### Claude Code Automations

The repository includes configured Claude Code automations in `.claude/`:

**Skills** (user-invocable with `/skill-name`):
- `/api-endpoint` - Generate Express.js endpoints with Auth0 JWT middleware
- `/flutter-service` - Generate Flutter services with Provider pattern

**Hooks** (automatic):
- Auto-format: Flutter (dartfmt) and Node.js (prettier) on edit
- Security blocks: Prevents edits to `.env`, `.env.production`, `**/*.secret.yaml`, `**/secrets/**`, `**/*.key` files

**Subagents** (auto-invoked):
- `security-reviewer` - Reviews Auth0, Stripe, SSH, and database security
- `integration-tester` - Generates tests for services and endpoints

**MCP Servers**:
- `context7` - Live documentation for Flutter, Node.js, Auth0
- `Sentry` - Error investigation and stack trace analysis

See `.claude/SETUP_SUMMARY.md` for complete automation documentation.

## Development Notes

- The app supports both local-only mode (privacy-first) and cloud-relay mode
- Auth0 configuration requires environment variables (see `config/.env.production.template`)
- Docker deployment options available in `docker-compose.yml`
- CI/CD via GitHub Actions (see `.github/workflows/`)
- Claude Code automations documented in `.claude/SETUP_SUMMARY.md`
- **Note**: "Zoidbot" is the name of the avatar/bot character; the application is "CloudToLocalLLM"

### Debugging

**Flutter Development**:
```bash
# Run with verbose logging
flutter run -d linux --verbose

# Attach to running Flutter app
flutter attach

# Inspect widget tree
flutter run -d chrome --device-timeout=60
```

**Backend Development**:
```bash
# API backend with inspect for debugging
cd services/api-backend
node --inspect server.js

# Streaming proxy with inspect
cd services/streaming-proxy
npm run dev  # Uses --inspect flag
```

### Troubleshooting

**Service Registration Issues**:
- Check debug logs for `[ServiceLocator]` prefixes
- Verify `setupCoreServices()` completes before `setupAuthenticatedServices()`
- Desktop platforms auto-bootstrap authenticated services
- Web requires explicit authentication

**Provider Discovery**:
- Providers auto-scan on startup and periodically thereafter
- Check `ProviderDiscoveryService` logs for discovery results
- Manual configuration via `ProviderConfigurationManager` if auto-discovery fails

**Tunnel Connection Issues**:
- Run diagnostics via `TunnelService.getDiagnostics()`
- Check SSH key configuration in `TunnelConfigManager`
- Review connection state in `ConnectionStateTracker`
- Verify WebSocket heartbeat is active

### Implementation Phases

See `docs/development/IMPLEMENTATION_PLAN.md` for complete status:

**Phase 1: Foundation** (Chat + OpenClaw Manager)
- Multi-model selector UI
- Gateway start/stop control
- Gateway dashboard

**Phase 2: Core Features** (Avatar + Desktop)
- Personality engine + evolution tracker
- Window management, clipboard service
- File operations

**Phase 3: Advanced** (Vision + Avatar)
- Camera input + OCR
- Memory system for avatar
- Achievement system

### Key Documentation

- `SPEC.md` - Master specification with project vision
- `docs/development/IMPLEMENTATION_PLAN.md` - Five pillars implementation status
- `docs/architecture/SYSTEM_ARCHITECTURE.md` - Technical deep dive
- `README.md` - User-facing overview and setup
