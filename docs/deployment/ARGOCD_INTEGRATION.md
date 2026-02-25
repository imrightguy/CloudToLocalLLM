# Argo CD Integration & GitOps Workflow

This document describes the modernized CI/CD pipeline using GitHub Actions for Continuous Integration (CI) and Argo CD for Continuous Deployment (CD) on Azure AKS.

## Overview

The pipeline has been optimized to leverage GitOps principles:

1. **GitHub Actions**: Builds Docker images, tests code, and "promotes" the release by updating the Kubernetes manifests in the Git repository.
2. **Argo CD**: Detects changes in the Git repository and synchronizes the Kubernetes cluster to the desired state.

## Architecture

### CI (GitHub Actions)

Located in `.github/workflows/ci-cd.yml`.

- **Trigger**: Push to `main`.
- **Registry**: Azure Container Registry (ACR) - `ghcr.io/cloudtolocalllm-online/CloudToLocalLLM`
- **Steps**:
    1. **Build**: Creates Docker images for `api-backend` and `web-frontend`.
    2. **Push**: Uploads images to ACR.
    3. **Promote**: Uses `kustomize` to update the `images` tag in `k8s/apps/managed/<app>/kustomization.yaml` with the new commit SHA.
    4. **Commit**: Pushes the updated manifests back to the `main` branch.

### CD (Argo CD)

Located in `k8s/apps/managed/argo-apps.yaml` (ApplicationSet).

- **Pattern**: App of Apps / ApplicationSet.
- **Source**: Watches `k8s/apps/managed/*`.
- **Sync Policy**: Automated (Self-Heal enabled).
- **Drift Detection**: Argo CD automatically corrects any manual changes in the cluster that deviate from Git.

## RBAC Configuration

To secure Argo CD, we use a declarative RBAC configuration.

**File**: `k8s/argocd-rbac/argocd-rbac-cm.yaml`

### Applying RBAC

Since Argo CD manages its own configuration in the `argocd` namespace, you must apply this manually or via a separate administrative Argo app.

```bash
kubectl apply -f k8s/argocd-rbac/argocd-rbac-cm.yaml
```

### Roles

- **admin**: Full access.
- **developer**: Can view and sync applications in the `CloudToLocalLLM` project/namespace, and view logs.

## Deployment Strategy

The applications use a **RollingUpdate** strategy with `maxUnavailable: 0` to ensure zero downtime.

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

## How to Deploy

1. Make code changes.
2. Push to `main`.
3. **GitHub Actions** will automatically build and update the `kustomization.yaml` files.
4. **Argo CD** will detect the change (within ~3 minutes) and roll out the new version.

### Manual Sync

If you need immediate synchronization:

```bash
argocd app sync CloudToLocalLLM-services
```
