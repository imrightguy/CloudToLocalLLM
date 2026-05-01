# CloudToLocalLLM Documentation

This is the canonical documentation hub for CloudToLocalLLM. Prefer linking here from new docs instead of adding another top-level index.

For project-wide agent instructions, see [AGENTS.md](../AGENTS.md). For the product specification, see [SPEC.md](../SPEC.md).

## Start Here

| Audience | Document |
| --- | --- |
| Users | [User Guide](user-guide/USER_GUIDE.md) |
| New developers | [Developer Onboarding](development/DEVELOPER_ONBOARDING.md) |
| Contributors | [Development Workflow](development/DEVELOPMENT_WORKFLOW.md) |
| Build/release work | [Building Guide](development/BUILDING_GUIDE.md) |
| Tests | [Comprehensive Testing Guide](development/testing/COMPREHENSIVE_TESTING_GUIDE.md) |
| Architecture | [System Architecture](architecture/SYSTEM_ARCHITECTURE.md) |
| Deployment | [Deployment Index](deployment/README.md) |

## Current Architecture

- [System Architecture](architecture/SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](architecture/AGENT_RUNTIME_CONTRACT.md)
- [Secure Device Mesh](architecture/SECURE_DEVICE_MESH.md)
- [Avatar System](architecture/AVATAR_SYSTEM.md)
- [Desktop Control](architecture/DESKTOP_CONTROL.md)
- [Vision System](architecture/VISION_SYSTEM.md)
- [Tunnel System](architecture/TUNNEL_SYSTEM.md) - legacy/fallback tunnel reference
- [Service Lifecycle](architecture/service_lifecycle.md)
- [Architecture Codemap](architecture/architecture-codemap.md)

## Development

- [Developer Onboarding](development/DEVELOPER_ONBOARDING.md)
- [Development Workflow](development/DEVELOPMENT_WORKFLOW.md)
- [Implementation Plan](development/IMPLEMENTATION_PLAN.md)
- [Building Guide](development/BUILDING_GUIDE.md)
- [Build Scripts](development/BUILD_SCRIPTS.md)
- [Testing Guide](development/testing/COMPREHENSIVE_TESTING_GUIDE.md)
- [Documentation Style Guide](development/DOCUMENTATION_STYLE_GUIDE.md)

## API And Backend

- [API Index](api/README.md)
- [Admin API](api/ADMIN_API.md)
- [Tunnel Client API](api/TUNNEL_CLIENT_API.md) - legacy/fallback tunnel reference
- [Tunnel Server API](api/TUNNEL_SERVER_API.md) - legacy/fallback tunnel reference
- [Backend Database](backend/database/README.md)
- [Backend Services](backend/services/README.md)
- [Streaming Proxy Deployment](backend/streaming-proxy/DEPLOYMENT.md) - legacy/fallback proxy service

## Deployment And Operations

- [Deployment Index](deployment/README.md)
- [Self Hosting](deployment/SELF_HOSTING.md)
- [Docker Deployment](deployment/DOCKER_DEPLOYMENT.md)
- [Complete Deployment Workflow](deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Operations Index](operations/README.md)
- [Security Policy](governance/security/SECURITY.md)
- [Secrets Management](deployment/SECRETS_MANAGEMENT.md)

## User Guides

- [Setup Guide](user-guide/SETUP_GUIDE.md)
- [User Guide](user-guide/USER_GUIDE.md)
- [Features Guide](user-guide/FEATURES_GUIDE.md)
- [Troubleshooting](user-guide/TROUBLESHOOTING.md)

## Historical Material

Large implementation notes, one-off plans, and generated summaries should move under [Archive](archive/README.md) when they are no longer current. Current docs should describe the code as it exists now, not preserve task history inline.

## Maintenance Rules

- Keep this file as the single navigation source.
- Keep [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) as a compatibility redirect only.
- Run `npm run docs:links` before changing canonical docs.
- Use `npm run docs:links:all` for full-tree cleanup work; it is expected to fail until the archive is cleaned.
