# CloudToLocalLLM Documentation Index

**OpenClaw Agent Manager** — A privacy-first desktop AI companion.

> **Documentation Philosophy**: Focus on local-first, privacy-first features. Cloud/tunnel features are optional and secondary.

---

## Quick Start

| Document | Description |
|----------|-------------|
| [README.md](../README.md) | Project overview, badges, quick links |
| [SPEC.md](../SPEC.md) | Master specification — vision, Five Pillars, features |
| [CLAUDE.md](../CLAUDE.md) | Development guidelines for Claude Code |

---

## User Guides

| Document | Description |
|----------|-------------|
| [SETUP_GUIDE.md](user-guide/SETUP_GUIDE.md) | Installation and initial setup |
| [USER_GUIDE.md](user-guide/USER_GUIDE.md) | Using all Five Core Pillars |
| [FEATURES_GUIDE.md](user-guide/FEATURES_GUIDE.md) | Deep dive into features |
| [TROUBLESHOOTING.md](user-guide/TROUBLESHOOTING.md) | Common issues and solutions |

---

## Architecture

| Document | Description | Status |
|----------|-------------|--------|
| [SYSTEM_ARCHITECTURE.md](architecture/SYSTEM_ARCHITECTURE.md) | Technical architecture overview | ✅ Current |
| [Avatar System](architecture/AVATAR_SYSTEM.md) | Evolving avatar architecture | ✅ Created |
| [Desktop Control](architecture/DESKTOP_CONTROL.md) | GUI automation and system integration | ✅ Created |
| [Vision System](architecture/VISION_SYSTEM.md) | Screen and camera capabilities | ✅ Created |
| [Service Lifecycle](architecture/service_lifecycle.md) | Service initialization and DI | ✅ Current |

---

## Implementation

| Document | Description | Status |
|----------|-------------|--------|
| [IMPLEMENTATION_PLAN.md](development/IMPLEMENTATION_PLAN.md) | Five Pillars + Setup Wizard roadmap with detailed tasks | ✅ Current (Consolidated) |
| [BUILDING_GUIDE.md](development/BUILDING_GUIDE.md) | Build from source | ✅ Current |
| [DEVELOPER_ONBOARDING.md](development/DEVELOPER_ONBOARDING.md) | New developer setup | ✅ Current |

---

## Development Reference

| Category | Document | Description |
|----------|----------|-------------|
| **CI/CD** | [CI_CONFIGURATION.md](development/CI_CONFIGURATION.md) | GitHub Actions setup |
| **MCP** | [MCP_TOOLS_SETUP.md](development/MCP_TOOLS_SETUP.md) | MCP server configuration |
| **Auth** | [AUTHENTICATION_QUICK_REFERENCE.md](development/AUTHENTICATION_QUICK_REFERENCE.md) | Auth0 integration |
| **Building** | [LINUX_BUILD_GUIDE.md](development/LINUX_BUILD_GUIDE.md) | Linux-specific builds |
| **Building** | [WINDOWS_BUILD_GUIDE.md](development/WINDOWS_BUILD_GUIDE.md) | Windows-specific builds |

---

## Backend Services (Optional Cloud Features)

> **Note**: These are optional cloud/SaaS features. The core app runs entirely local.

### API Backend
| Document | Description |
|----------|-------------|
| [README.md](backend/services/README.md) | API backend overview |
| [QUICK_START.md](backend/services/QUICK_START.md) | Backend quick start |

### Streaming Proxy
| Document | Description |
|----------|-------------|
| [WebSocket](backend/streaming-proxy/websocket/README.md) | WebSocket layer |
| [Rate Limiter](backend/streaming-proxy/rate-limiter/README.md) | Rate limiting |
| [Circuit Breaker](backend/streaming-proxy/circuit-breaker/README.md) | Fault tolerance |

### Tunnels (Optional Remote Access)
| Document | Description |
|----------|-------------|
| [Tunnel System](architecture/TUNNEL_SYSTEM.md) | Tunnel architecture |
| [Tunnel Feature Analysis](architecture/TUNNEL_FEATURE_ANALYSIS.md) | Feature breakdown |

---

## Deployment

| Document | Description |
|----------|-------------|
| [Self-Hosting Guide](deployment/SELF_HOSTING.md) | Deploy your own instance | 🔲 To Create |
| [Docker Deployment](deployment/DOCKER.md) | Docker compose setup | 🔲 To Create |

---

## API Reference

| Document | Description |
|----------|-------------|
| [API Policies](api/policies/README.md) | API policies overview |
| [API Documentation](development/API_DOCUMENTATION.md) | Complete API reference |

---

## Deprecated/Archived (Removed)

| Document | Reason | Action |
|----------|--------|--------|
| `DETAILED_IMPLEMENTATION_PLAN.md` | Consolidated into IMPLEMENTATION_PLAN.md | ✅ Removed |
| `IMPLEMENTATION_SUMMARY.md` | Consolidated into IMPLEMENTATION_PLAN.md | ✅ Removed |
| `BRANDING_PLAN.md` | Outdated branding info | 🗑️ To Remove |
| `ROUTER_PLAN.md` | Integrated into IMPLEMENTATION_PLAN.md | 🗑️ To Remove |
| `DISCUSSION_SUMMARY.md` | Historical discussion notes | 🗑️ To Remove |

---

## Documentation TODO

### P0 (Critical)
- [x] Fix "CloudToLocalLLM" branding in SYSTEM_ARCHITECTURE.md
- [x] Update all docs to use "CloudToLocalLLM" consistently
- [x] Create Avatar System architecture doc
- [x] Create Desktop Control architecture doc
- [x] Create Vision System architecture doc

### P1 (High)
- [x] Consolidate duplicate implementation plans
- [ ] Create self-hosting deployment guide
- [ ] Update USER_GUIDE.md for Five Pillars
- [ ] Add privacy/security documentation

### P2 (Medium)
- [ ] Review and archive cloud-focused backend docs
- [ ] Create Docker deployment guide
- [ ] Add local model provider setup guide (LM Studio, Ollama)
- [ ] Create OpenClaw Gateway management guide

---

## Contributing to Documentation

When updating documentation:
1. Use "CloudToLocalLLM - OpenClaw Agent Manager" branding
2. Emphasize privacy-first, local-first features
3. Keep cloud/tunnel features as optional/add-ons
4. Link to related documents from this index
5. Update this index when adding/removing documents
