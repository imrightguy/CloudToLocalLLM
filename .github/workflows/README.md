# GitHub Actions Workflows

This directory contains all CI/CD workflows for CloudToLocalLLM.

## Current Workflow Overview

### **Build Pipeline** (`build-pipeline.yml`)
**Unified CI/CD workflow using AI-powered orchestration**

- **Trigger:**
  - Push to `main` branch
  - Manual dispatch via `workflow_dispatch`
  - Repository dispatch with type `orchestrator-build`

- **Jobs:**
   1. **orchestrator_entry** - AI-powered component analysis
      - Uses KiloCode AI to analyze git changes
      - Determines which components need building (api, web, postgres, streaming, linux, windows)
      - Handles automated version bumping when needed
      - Outputs component list and version info

   2. **build_base** - Base Docker images
      - Builds `cloudtolocalllm-base:latest` and `CloudToLocalLLM-build:latest`
      - Provides common build environment

   3. **deploy_secrets** - Cluster secrets management
      - Deploys GitHub secrets to AKS cluster
      - Uses Azure credentials for authentication

   4. **build_api** - API Backend
      - Builds `cloudtolocalllm-api:latest`
      - Runs `npm test` for API validation

   5. **build_web** - Web Frontend
      - Builds web application
      - Runs `npm install` and `npm run build`
      - Executes `npm test` for frontend validation

   6. **build_postgres** - PostgreSQL Service
      - Builds PostgreSQL container image

   7. **build_streaming** - Streaming Proxy
      - Builds streaming proxy service

   8. **build_linux** - Linux Desktop
      - Placeholder for Linux desktop build

   9. **build_windows** - Windows Desktop
      - Placeholder for Windows desktop build (runs on windows-latest)

   10. **promote_to_gitops** - GitOps deployment
       - Updates Kubernetes overlays
       - Executes cluster deployment scripts

   11. **create_github_release** - Release management
       - Creates GitHub releases for version bumps
       - Tags releases with new version numbers

- **AI Integration:** Uses KiloCode (xAI Grok) for intelligent build orchestration
- **Status:** ✅ Active - unified pipeline with AI component detection

---

### **AI Triage** (`ai-triage.yml`)
**Automated issue management and PR handling**

- **Purpose:** AI-powered issue triage and management
- **Status:** ✅ Active for repository automation

---

## Workflow Execution Flow

### For Main Branch (Production)
```
Push to main
     ↓
Build Pipeline triggers
     ├─ Orchestrator analyzes changes with AI
     │  ├─ Determines components to build
     │  └─ Handles version bumping if needed
     ├─ Build Base Images
     ├─ Deploy Secrets to AKS
     ├─ Parallel Component Builds
     │  ├─ API Backend (with tests)
     │  ├─ Web Frontend (with tests)
     │  ├─ PostgreSQL
     │  ├─ Streaming Proxy
     │  ├─ Linux Desktop (placeholder)
     │  └─ Windows Desktop (placeholder)
     ├─ Promote to GitOps
     └─ Create GitHub Release (if version bumped)
```

## Environment Variables

```yaml
KILOCODE_IMAGE: kiloai/cli:latest
KILOCODE_MODEL: x-ai/grok-code-fast-1
```

## Required Secrets

- `KILOCODE_TOKEN` - KiloCode API token for AI orchestration
- `GITHUB_TOKEN` - GitHub token for repository operations
- `AZURE_CREDENTIALS` - Azure service principal credentials
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token

## Troubleshooting

### Workflow Not Triggering
1. Check branch name matches trigger condition (`main`)
2. Verify repository dispatch events use correct type
3. Check KiloCode token is configured
4. Review workflow syntax in GitHub Actions UI

### Build Failures
1. Check Docker Hub credentials
2. Verify KiloCode API token for AI orchestration
3. Review AI analysis output for component detection
4. Check Azure credentials for secret deployment

### Deployment Failures
1. Verify Azure AKS cluster access
2. Check Kubernetes manifests in `k8s/` directory
3. Review GitOps deployment scripts
4. Check cloudflared tunnel connectivity

### AI Orchestration Issues
1. Verify `KILOCODE_TOKEN` is set
2. Check AI model availability (`x-ai/grok-code-fast-1`)
3. Review git diff analysis in orchestrator logs
4. Validate component detection logic

## Best Practices

1. **Use meaningful commit messages** - AI orchestration relies on commit content
2. **Test changes on feature branches** - Avoid direct main pushes for complex changes
3. **Monitor AI decisions** - Review orchestrator output for build decisions
4. **Keep secrets updated** - Regularly rotate API tokens and credentials
5. **Use repository dispatch** - For external trigger of builds when needed

## Current Issues & Improvements Needed

### Critical Issues
- ❌ **No tunnel connectivity testing** - Cloudflared endpoints return 530 errors
- ❌ **Limited testing coverage** - Only basic npm test, no integration tests
- ❌ **No security scanning** - Missing vulnerability checks
- ❌ **No rollback mechanisms** - Failed deployments require manual intervention

### Planned Improvements
- [ ] Add cloudflared tunnel health validation
- [ ] Implement comprehensive testing (unit, integration, e2e)
- [ ] Add security scanning (Trivy, Snyk)
- [ ] Implement automated rollback on deployment failure
- [ ] Add performance benchmarking
- [ ] Add Slack/Teams notifications for deployment status
- [ ] Implement canary deployments
- [ ] Add monitoring and alerting integration
