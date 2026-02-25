# CloudToLocalLLM Helper

This file provides context and helpers for the CloudToLocalLLM project.

## CLI Tools

The following CLI tools are essential for working on this repository:

### Core

- **`flutter`**: For building and running the Flutter app.
- **`dart`**: For Dart code analysis and running scripts.
- **`node`, `npm`**: For backend services and scripting.

### Containerization & Orchestration

- **`docker`**: For container management.
- **`docker-compose`**: For running multi-container setups (see `docker-compose.yml`).
- **`kubectl`**: For interacting with Kubernetes clusters.
- **`helm`**: For managing Kubernetes charts.

### Cloud & DevOps

- **`az`**: Azure CLI for infrastructure management.
- **`gcloud`**: Google Cloud CLI.
- **`gh`**: GitHub CLI for PRs and issues.
- **`sentry`**: For managing error tracking/releases.

### Testing

- **`jest`**: For backend unit testing.
- **`playwright`**: For end-to-end testing.

### Repo Scripts

(See `scripts/` directory for full list)

- `deploy-*.ps1/sh`: Deployment scripts for various platforms.
- `setup-development-environment.sh`: Major setup script for CachyOS / Manjaro Linux.

## Repository Structure

| Directory | Description |
|-----------|-------------|
| `lib/` | Main Flutter application code. |
| `services/` | Backend services (api-backend, streaming-proxy, sdk). |
| `backend/auth/` | Authentication service. |
| `scripts/` | Deployment, setup, and maintenance scripts. |
| `docs/` | Comprehensive documentation and plans. |
| `assets/` | Application assets (icons, animations, screenshots). |
| `test/` | Frontend and backend tests. |
| `infra/` | Infrastructure as code (Terraform, etc. if applicable). |
| `k8s/` | Kubernetes manifests and Helm charts. |
| `android/`, `ios/`, `linux/`, `windows/`, `web/` | Platform-specific code and configurations. |

## Development Context

- **OpenClaw Gateway**: Runs on `localhost:18789`.
- **LLM Router**: Runs on `localhost:1337` (OpenAI-compatible).
- **Architecture**: Privacy-first routing between local and cloud models.
- **Status**: Phase 0 (Setup) and Phase 1 (Foundation) are complete. Currently working on Phase 2 (Core Features).

## Antigravity Integrations

The following MCP servers are configured in `~/.gemini/antigravity/mcp_config.json` and are available out of the box after running the setup script:

- **Context7** (`@upstash/context7-mcp`): Retrieves up-to-date documentation and code examples (Flutter, Node.js, Auth0, etc.). Use this tool before implementing new library features.
- **Memory** (`@modelcontextprotocol/server-memory`): A persistent knowledge graph to store architectural decisions, user preferences, and ongoing work context.
- **Sequential Thinking**: A tool for breaking down complex problems through multi-step reasoning.
- **Dart MCP Server**: Deep integration tools for the Flutter and Dart layers of the application.
