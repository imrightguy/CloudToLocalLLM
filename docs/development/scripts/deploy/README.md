# CloudToLocalLLM Deployment Scripts

**⚠️ DEPRECATED DIRECTORY**: All VPS deployment scripts have been moved to `scripts/archive/`.

CloudToLocalLLM now uses **Kubernetes** for production deployment. VPS deployment scripts are deprecated.

## Current Deployment Methods

### 🚀 Production Deployment (Recommended)

- **[Kubernetes Deployment](../../docs/DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)**
- Works with any Kubernetes cluster (managed or self-hosted)
- Use: `kubectl apply -f k8s/`

### 🧪 Development/Testing Deployment

- **[Docker Compose](../../DOCKER_DEPLOYMENT.md)**
- Suitable for local development and testing
- Use: `docker-compose up`

## Archived Scripts

All VPS deployment scripts have been moved to `scripts/archive/` with detailed migration guides:

- `Deploy-CloudToLocalLLM.ps1` → Replaced by Kubernetes deployment
- `BuildEnvironmentUtilities.ps1` → Replaced by GitHub Actions CI/CD
- `sync_versions.sh` → Replaced by automated CI/CD versioning
- `verify_deployment.sh` → Replaced by Kubernetes health checks
- `version_manager.ps1` → Replaced by automated CI/CD versioning

See `scripts/archive/README.md` for complete migration information.
