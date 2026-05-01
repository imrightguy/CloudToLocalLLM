# CloudToLocalLLM Deployment Overview

This document provides a comprehensive overview of deployment options and strategies for CloudToLocalLLM.

> **Current orientation**: CloudToLocalLLM is agent-runtime-first and Tailscale-first. The setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime. Ollama, LM Studio, and similar model servers are support model providers for app-owned memory/background features, not primary app runtimes. Cloud deployment should focus on account sync, presence, web/mobile access, per-user cloud connectors, and optional per-user hosted agent runtime containers. Legacy streaming-proxy/tunnel components remain fallback architecture unless a deployment specifically depends on them.

## 📋 Table of Contents

- [Deployment Options](#deployment-options)
- [Multi-Container Architecture](#multi-container-architecture)
- [Deployment Scripts](#deployment-scripts)
- [Quality Standards](#quality-standards)
- [Versioning Strategy](#versioning-strategy)
- [Related Documentation](#related-documentation)

---

## Deployment Options

### 🚀 Kubernetes Deployment (Recommended)

Deploy the full CloudToLocalLLM stack to **Kubernetes** using Dockerfiles and Kubernetes manifests. Works with:

- **Managed Kubernetes**: DigitalOcean Kubernetes (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises or your own infrastructure

```bash
# Build and push Docker images to your container registry
docker build -f config/docker/Dockerfile.web \
  -t your-registry.com/ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest .
docker push your-registry.com/ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest

docker build -f services/api-backend/Dockerfile.prod \
  -t your-registry.com/CloudToLocalLLM/api:latest .
docker push your-registry.com/CloudToLocalLLM/api:latest

# Deploy to Kubernetes (any cluster)
kubectl apply -f k8s/
```

**Benefits:**

- Scalable and secure environment for multiple users
- Automated SSL certificate management via cert-manager
- Auto-scaling and high availability
- Platform-agnostic (works with any Kubernetes cluster)
- Self-hosting option for businesses with security/compliance requirements

**Requirements:**

- Kubernetes cluster (managed or self-hosted)
- Container registry (Docker Hub, DigitalOcean Container Registry, self-hosted, etc.)
- Domain name with DNS configuration
- kubectl configured for your cluster

#### Proxmox + k3s path

For Proxmox-hosted Kubernetes with Cloudflare Tunnel-only ingress:

- [k3s on Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md)
- [ArgoCD Proxmox Management VM Runbook](ARGOCD_PROXMOX_MANAGEMENT_VM.md)
- Template automation scripts:
  - `scripts/proxmox/create-k3s-template.sh`
  - `scripts/proxmox/clone-k3s-node.sh`

### 🏠 Self-Hosting Options

For self-hosted Kubernetes deployments (on-premises or private cloud):

- [Self-Hosting Guide](SELF_HOSTING.md) - General self-hosting information
- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md) - Server and provider infrastructure notes

### ⚠️ Legacy Single Container (Deprecated)

The legacy single-container deployment is deprecated and no longer supported. Please migrate to the multi-container architecture.

---

## Multi-Container Architecture

CloudToLocalLLM features a modern multi-container architecture that provides:

### 🏗️ **Architecture Benefits**

- **Scalability**: Easily handle multiple users and connections
- **Resilience**: Isolated services prevent cascading failures
- **Maintainability**: Clear separation of concerns simplifies development and updates
- **Security**: Enhanced network policies and container isolation

### 🔧 **Key Containers**

- `nginx-proxy`: SSL termination and request routing
- `flutter-app`: The unified Flutter web application (UI, chat, marketing pages)
- `api-backend`: Core API, authentication, and streaming proxy management
- `tailscale-relay` / cloud connector: secure device mesh integration
- `streaming-proxy` (ephemeral): legacy/fallback proxies for older user-to-local-provider communication
- `certbot`: Automated SSL certificate management

For detailed information, see [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md).

---

## Dockerfile-Based Deployment

CloudToLocalLLM uses **Dockerfiles** for building container images, which are then deployed to **Kubernetes** (managed or self-hosted).

### 🐳 **Dockerfiles**

#### `config/docker/Dockerfile.web`

Builds the Flutter web application as a static site served by Nginx.

```bash
docker build -f config/docker/Dockerfile.web -t CloudToLocalLLM-web:latest .
```

#### `services/api-backend/Dockerfile.prod`

Builds the Node.js API backend service.

```bash
docker build -f services/api-backend/Dockerfile.prod -t cloudtolocalllm-api:latest .
```

### ☸️ **Kubernetes Deployment**

Deploy to any Kubernetes cluster (managed or self-hosted) using the manifests in the `k8s/` directory:

```bash
# Apply all Kubernetes resources
kubectl apply -f k8s/

# Or apply individually
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/api-backend-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml
kubectl apply -f k8s/ingress-nginx.yaml
```

**Platform Options:**

- **Managed Kubernetes**: DigitalOcean (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises clusters, bare metal, or private cloud

For detailed deployment instructions, see:

- Kubernetes manifests live in `k8s/`
- [Self-Hosting Guide](SELF_HOSTING.md) - For businesses deploying on-premises

---

## Quality Standards

### 🎯 Strict Deployment Policy

CloudToLocalLLM enforces a **zero-tolerance deployment policy** for production:

- ✅ **Success**: Zero warnings AND zero errors required
- ❌ **Failure**: Any warning condition triggers automatic rollback
- 🔄 **Rollback**: Immediate restoration of previous version on any issue
- 🏆 **Quality**: Only perfect deployments reach production

### 📊 **Success Criteria**

- Perfect HTTP 200 responses (no redirects)
- Valid SSL certificates mandatory
- Clean container logs (no errors)
- Optimal system resources (<90% usage)
- Fully functional application health checks

See [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md) for complete details.

---

## Versioning Strategy

CloudToLocalLLM uses a granular build numbering system:

- **Format**: `v<major>.<minor>.<patch>+<build>` (e.g., `v3.13.0+202507262156`)
- **`major.minor.patch`**: Semantic versioning for core application
- **`build`**: Incremental build number based on timestamp (YYYYMMDDHHMM)

This allows for precise tracking of releases and development builds.

For detailed information, see [Versioning Strategy](VERSIONING_STRATEGY.md).

---

## Related Documentation

### 📚 **Deployment Guides**

- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [Deployment Testing Guide](DEPLOYMENT_TESTING_GUIDE.md)
- [k3s on Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md)
- [ArgoCD Proxmox Management VM Runbook](ARGOCD_PROXMOX_MANAGEMENT_VM.md)

### 🔧 **Operations**

- [Self-Hosting Guide](SELF_HOSTING.md)
- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md)

### ☸️ **Kubernetes Deployment**

- Kubernetes manifests live in `k8s/`

### 🏗️ **Architecture**

- [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Secure Device Mesh](../architecture/SECURE_DEVICE_MESH.md)
- [Tunnel System](../architecture/TUNNEL_SYSTEM.md)

### 👨‍💻 **Development**

- [Developer Onboarding](../development/DEVELOPER_ONBOARDING.md)
- [API Documentation](../development/API_DOCUMENTATION.md)

---

_For questions about deployment, please see our [troubleshooting guide](../user-guide/TROUBLESHOOTING.md) or [open an issue](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)._
