# AI-Powered Multi-Platform Versioning System

## Overview

CloudToLocalLLM uses an intelligent, AI-powered versioning system powered by Gemini to analyze commits and automatically determine appropriate version bumps across all platforms.

## Architecture

### 🤖 **Workflow 1: Version Bump (Gemini AI)**

**Trigger**: Push to `main` branch (excludes tags and `[skip ci]` commits)

**Process**:

1. **Gemini AI analyzes** recent commits
2. **Determines bump type**: major, minor, or patch
3. **Updates ALL version references** across project
4. **Commits changes** with `[skip ci]`
5. **Creates platform tags**:
   - `4.5.0-cloud-abc123`
   - `4.5.0-desktop-abc123`
   - `4.5.0-mobile-abc123`
6. **Pushes commit + tags**

### ☁️ **Workflow 2: Cloud Deployment**

**Trigger**: Tag matching `*-cloud-*`

**Process**:

1. **Extracts** version and commit from tag
2. **Detects** which services changed
3. **Builds** only changed services with version tags
4. **Deploys** to Azure AKS

### 🖥️ **Workflow 3: Desktop Build** *(Future)*

**Trigger**: Tag matching `*-desktop-*`

Builds installers for Linux, Windows, macOS

### 📱 **Workflow 4: Mobile Build** *(Future)*

**Trigger**: Tag matching `*-mobile-*`

Builds for Android, iOS

## Version Determination Logic

### Gemini AI Analyzes Commits

```
feat: add new feature       → MINOR bump (4.4.0 → 4.5.0)
fix: resolve bug            → PATCH bump (4.4.0 → 4.4.1)
BREAKING CHANGE: API change → MAJOR bump (4.4.0 → 5.0.0)
chore: update deps          → PATCH bump (4.4.0 → 4.4.1)
docs: update README         → PATCH bump (4.4.0 → 4.4.1)
```

### Priority Rules

- **BREAKING CHANGE** > **feat:** > **fix:** > **chore:**
- Multiple commit types → uses highest priority
- **Refined Rule**: Backend improvements, infrastructure changes, or provider swaps (e.g., changing auth provider) that do not add new user-facing functionality should be **PATCH** bumps, even if labeled as `feat`.
- If Gemini unavailable → defaults to PATCH bump

## Files Updated by Version Bump

The version-bump workflow updates **ALL** version references:

1. **`assets/version.json`** - Main version file
2. **`assets/component-versions.json`** - All service versions
3. **`pubspec.yaml`** - Flutter app version (format: `4.5.0+202512031420`)
4. **`services/api-backend/package.json`** - API backend version
5. **`services/streaming-proxy/package.json`** - Streaming proxy version
6. **`README.md`** - Version badges and links
7. **`docs/**`** - Documentation examples

## Service Versioning Rules

### When Service Changes

- Service gets tagged with: `<version>-<service>`
- Example: `4.5.0-api`, `4.5.0-proxy`
- Image pushed with semantic version tag

### When Service Doesn't Change

- Uses `:latest` tag (existing image)
- No rebuild needed
- Faster deployments

## Platform Tag Format

```
<version>-<platform>-<short-commit>

Examples:
  4.5.0-cloud-a10fae98
  4.5.0-desktop-a10fae98
  4.5.0-mobile-a10fae98
```

### Tag Components

- **Version**: Semantic version (4.5.0)
- **Platform**: Target platform (cloud/desktop/mobile)
- **Commit**: Short SHA for traceability

## Setup Requirements

### Required GitHub Secrets

```bash
# Gemini API Key (for AI-powered version analysis)
gh secret set GEMINI_API_KEY --body 'your_api_key_here'

# Get your key at: https://makersuite.google.com/app/apikey
```

### Existing Secrets (already configured)

- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_EMAIL`
- `POSTGRES_PASSWORD`, `JWT_SECRET`, etc.

## Usage

### Automatic (Recommended)

```bash
# Just push to main - AI handles versioning!
git add .
git commit -m "feat: add user dashboard"
git push origin main

# Gemini analyzes → minor bump → creates tags → deploys
```

### Manual Version Bump

```bash
# Run locally to test
./scripts/analyze-version-bump.sh  # See what Gemini suggests
./scripts/update-all-versions.sh 4.6.0 $(git rev-parse --short HEAD)

# Commit and push
git add -A
git commit -m "chore: bump to 4.6.0"
git push
```

### Manual Deployment

```bash
# Trigger cloud deployment for specific tag
gh workflow run deploy-aks.yml -f version_tag=4.5.0-cloud-abc123
```

## Version Display

### In Web App

- **Settings → About** shows all component versions:
  - Web: 4.5.0
  - API Backend: 4.5.0-api
  - Streaming Proxy: 4.5.0-proxy
  - Database: 4.5.0-postgres
  - Base Image: 4.5.0-base

### In API

```bash
curl https://api.cloudtolocalllm.online/service-version
# Returns: { "service": "api-backend", "version": "4.5.0-api", ... }
```

### In Git

```bash
git tag -l "*-cloud-*"
# Shows all cloud deployment versions
```

## Rollback

### To Previous Version

```bash
# 1. Find version tags
git tag -l "*-cloud-*" | sort -V | tail -5

# 2. Deploy previous version
gh workflow run deploy-aks.yml -f version_tag=4.4.0-cloud-xyz789

# OR manually update Kubernetes
kubectl set image deployment/web web=registry/web:4.4.0 -n cloudtolocalllm
kubectl set image deployment/api-backend api-backend=registry/api-backend:4.4.0-api -n cloudtolocalllm
```

## Benefits

✅ **AI-Powered**: Gemini determines appropriate version bumps  
✅ **Consistent**: All version references updated atomically  
✅ **Platform-Specific**: Separate tags for cloud/desktop/mobile  
✅ **Traceable**: Every version has a git tag with commit SHA  
✅ **Efficient**: Only changed services rebuild  
✅ **Clean**: Simple deployment logic  
✅ **Safe**: Immutable tags enable easy rollbacks  
✅ **Automated**: Zero manual version management  

## Troubleshooting

### Gemini API Key Missing

- Workflow falls back to PATCH bump
- Warning shown in logs
- Add key: `gh secret set GEMINI_API_KEY`

### Wrong Version Bump

- Override with manual commit: `git tag 4.5.1-cloud-$(git rev-parse --short HEAD)`
- Push: `git push origin 4.5.1-cloud-abc123`

### Service Not Rebuilding

- Check if files actually changed since last cloud tag
- Manually trigger: Change any file in that service

## Future Enhancements

1. **Desktop Workflow**: Electron builds for Linux/Windows/macOS
2. **Mobile Workflow**: Flutter builds for Android/iOS
3. **Changelog Generation**: Gemini generates release notes
4. **Release Notes**: Auto-create GitHub releases with AI-generated notes
5. **Version Validation**: Gemini validates version consistency
