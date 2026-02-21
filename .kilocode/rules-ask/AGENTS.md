# AGENTS.md - Ask Mode

This file provides guidance for answering questions about this codebase.

## Project Context

- **Project Name**: CloudToLocalLLM (codename: Zoidbot)
- **Vision**: OpenClaw Agent Manager with evolving avatar, desktop control, and vision

> See [SPEC.md](../../SPEC.md) for the complete specification.

## Non-Obvious Documentation Context

### Counterintuitive Structure

- `lib/services/` contains LLM providers and auth - not just services
- `services/api-backend/` is the main Express server, not `backend/`
- `services/streaming-proxy/` handles WebSocket proxying for LLM streams

### Hidden Documentation

- LLM Router: [`lib/services/router_server.dart`](lib/services/router_server.dart) - embedded shelf server at port 1337
- Provider configs: [`lib/services/providers/`](lib/services/providers/) - adapter patterns for each LLM
- Model tiers: [`lib/services/model_tiers.dart`](lib/services/model_tiers.dart) - rate limit tiers
- Drift database: [`lib/database/`](lib/database/) - generated code in `.g.dart` files

### Key Architecture Context

- Two-phase service initialization: `setupCoreServices()` → `setupAuthenticatedServices()`
- Auth: Auth0 with different implementations per platform (web uses bridge)
- Local models: OpenClaw Gateway (localhost:18789), LM Studio (localhost:1234)
- Cloud relay: SSH tunneling via WebSocket connections

### Version Requirements (Non-Standard)

- Node.js: >=22.0.0 <25.0.0 (NOT latest)
- Dart SDK: >=3.5.0 <4.0.0

### Where to Find Answers

- Authentication: `lib/services/auth/` and `docs/development/AUTHENTICATION_*.md`
- Tunnel: `docs/architecture/TUNNEL_SYSTEM.md`
- Deployment: `docs/deployment/`
- API: `docs/api/`
- MCP tools: `docs/development/MCP_TOOLS_SETUP.md`
