# Docker Image Versioning System

## Overview

The CloudToLocalLLM project uses semantic versioning for all Docker images. The **web deployment is the source of truth** for the application version.

## Version Format

```
<major>.<minor>.<patch>
```

Example: `5.0.1`

### Service-Specific Tags

Each service gets tagged with both the app version and a service identifier:

- **Web**: `5.0.1`
- **API**: `5.0.1-api`
- **Streaming Proxy**: `5.0.1-proxy`
- **Postgres**: `5.0.1-postgres`
- **Base**: `5.0.1-base`

### Additional Tags

Every image also gets tagged with:

- **Git SHA**: `abc123def456...` (for traceability)
- **Latest**: `latest` (for convenience)

## Version File

Version information is stored in `assets/version.json`:

```json
{
  "version": "5.0.1",
  "build_number": "202512031420",
  "build_date": "2025-12-03T14:20:00Z",
  "git_commit": "b61da9d3",
  "buildTimestamp": "2025-12-03 14:20:00"
}
```

## Automatic Version Bumping

### During Web Builds

When `lib/**`, `web/**`, or `pubspec.**` files change:

1. **Version is auto-bumped** (patch by default)
2. **version.json is updated**
3. **Change is committed** with `[skip ci]`
4. **Docker image is tagged** with new version

### Bump Types

- **Patch** (5.0.1 → 5.0.1): Bug fixes, minor changes
- **Minor** (5.0.1 → 5.0.1): New features, backwards compatible
- **Major** (5.0.1 → 5.0.0): Breaking changes

## Manual Version Bumping

To manually bump the version:

```bash
# Bump patch (default)
./scripts/bump-version.sh patch

# Bump minor
./scripts/bump-version.sh minor

# Bump major
./scripts/bump-version.sh major
```

The script will:

1. Read current version from `assets/version.json`
2. Increment the appropriate component
3. Update version.json with new version, build number, and git commit
4. Display the new version

**Note**: You still need to commit and push the changes manually when using the script locally.

## Deployment Behavior

### When Services are Built

If a service's source files changed:

- ✅ **Uses semantic version tag** (e.g., `5.0.1-api`)
- ✅ Image is freshly built and tagged
- ✅ Version is tracked and traceable

### When Services are NOT Built

If a service's source files didn't change:

- ✅ **Uses `:latest` tag**
- ✅ Reuses existing image (faster deployment)
- ✅ No unnecessary rebuilds

## Version Tracking

### In Kubernetes

Deployments get annotated with versions:

```yaml
metadata:
  annotations:
    kubernetes.io/revision: "5.0.1"
    deployment.kubernetes.io/timestamp: "2025-12-03T14:20:00Z"
```

### In ACR (Azure Container Registry)

Images are stored with multiple tags:

```
ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest
ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest
ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest
```

## Release Process

### For New Releases

1. **Web build automatically bumps version**
2. **Version.json is committed** (shows in git history)
3. **All services use the same base version** (with service suffixes)
4. **Tagged images are immutable** (can always rollback)

### Rollback

To rollback to a previous version:

```bash
# List available versions
az acr repository show-tags --name imrightguycloudtolocalllm --repository web --orderby time_desc

# Update deployment to use specific version
kubectl set image deployment/web web=ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest -n CloudToLocalLLM
```

## Benefits

1. **Clear Version History**: Every deployment has a semantic version
2. **Easy Rollbacks**: All versions are tagged and immutable
3. **Traceable**: Git commit SHA is included in every image
4. **Efficient**: Only changed services are rebuilt
5. **Consistent**: Web version is the source of truth for the entire app

## Example Deployment Scenario

### Scenario: Fix Bug in API Backend

```
Changes detected: services/api-backend/**
Current version: 5.0.1

Build Process:
├─ Web: SKIP (no changes) → use 5.0.1 (latest)
├─ API: BUILD → tag as 5.0.1-api
├─ Proxy: SKIP (no changes) → use latest
└─ Postgres: SKIP (no changes) → use latest

Deployment:
├─ Web: 5.0.1 (cached)
├─ API: 5.0.1-api (new)
├─ Proxy: latest (cached)
└─ Postgres: latest (cached)
```

### Scenario: New Feature in Web

```
Changes detected: lib/**, web/**
Current version: 5.0.1

Versioning:
└─ Bump to: 5.0.1 (patch bump)

Build Process:
├─ Web: BUILD → tag as 5.0.1, 5.0.1-api, etc.
├─ API: SKIP → use latest
├─ Proxy: SKIP → use latest
└─ Postgres: SKIP → use latest

Deployment:
├─ Web: 5.0.1 (new version!)
├─ API: latest (cached)
├─ Proxy: latest (cached)
└─ Postgres: latest (cached)
```

## CI/CD Integration

The versioning system is fully integrated into `.github/workflows/deploy-aks.yml`:

- **Automatic detection** of file changes
- **Automatic version bumping** for web builds
- **Automatic tagging** of all Docker images
- **Automatic commit** of version.json
- **Deployment with correct versions**

## Security Note

- ✅ Scoped Cloudflare API token for cache purging
- ✅ No Global API Key in CI/CD
- ✅ Semantic versions for all services
- ✅ Immutable tags for rollback safety
