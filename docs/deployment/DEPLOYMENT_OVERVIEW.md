# Zoidbot Deployment Overview

This document provides a comprehensive overview of deployment options and strategies for Zoidbot.

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

Deploy the full Zoidbot stack to **Kubernetes** using Dockerfiles and Kubernetes manifests. Works with:

- **Managed Kubernetes**: DigitalOcean Kubernetes (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises or your own infrastructure

```bash
# Build and push Docker images to your container registry
docker build -f config/docker/Dockerfile.web \
  -t your-registry.com/ghcr.io/zoidbot-online/zoidbot/web:latest .
docker push your-registry.com/ghcr.io/zoidbot-online/zoidbot/web:latest

docker build -f services/api-backend/Dockerfile.prod \
  -t your-registry.com/zoidbot/api:latest .
docker push your-registry.com/zoidbot/api:latest

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

### 🏠 Self-Hosting Options

For self-hosted Kubernetes deployments (on-premises or private cloud):

- [Self-Hosted Kubernetes Guide](../../KUBERNETES_SELF_HOSTED_GUIDE.md) - Complete guide for businesses
- [Self-Hosting Guide](../OPERATIONS/SELF_HOSTING.md) - General self-hosting information
- [Infrastructure Guide](../OPERATIONS/INFRASTRUCTURE_GUIDE.md) - Server requirements

### ⚠️ Legacy Single Container (Deprecated)

The legacy single-container deployment is deprecated and no longer supported. Please migrate to the multi-container architecture.

---

## Multi-Container Architecture

Zoidbot features a modern multi-container architecture that provides:

### 🏗️ **Architecture Benefits**

- **Scalability**: Easily handle multiple users and connections
- **Resilience**: Isolated services prevent cascading failures
- **Maintainability**: Clear separation of concerns simplifies development and updates
- **Security**: Enhanced network policies and container isolation

### 🔧 **Key Containers**

- `nginx-proxy`: SSL termination and request routing
- `flutter-app`: The unified Flutter web application (UI, chat, marketing pages)
- `api-backend`: Core API, authentication, and streaming proxy management
- `streaming-proxy` (ephemeral): Lightweight proxies for user-to-local-LLM communication
- `certbot`: Automated SSL certificate management

For detailed information, see [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md).

---

## Dockerfile-Based Deployment

Zoidbot uses **Dockerfiles** for building container images, which are then deployed to **Kubernetes** (managed or self-hosted).

### 🐳 **Dockerfiles**

#### `config/docker/Dockerfile.web`

Builds the Flutter web application as a static site served by Nginx.

```bash
docker build -f config/docker/Dockerfile.web -t zoidbot-web:latest .
```

#### `services/api-backend/Dockerfile.prod`

Builds the Node.js API backend service.

```bash
docker build -f services/api-backend/Dockerfile.prod -t zoidbot-api:latest .
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

- [Kubernetes Quick Start](../../k8s/README.md) - DigitalOcean example
- [Kubernetes README](../../k8s/README.md) - Complete Kubernetes deployment guide (platform-agnostic)
- [Self-Hosted Kubernetes Guide](../../KUBERNETES_SELF_HOSTED_GUIDE.md) - For businesses deploying on-premises

---

## Quality Standards

### 🎯 Strict Deployment Policy

Zoidbot enforces a **zero-tolerance deployment policy** for production:

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

Zoidbot uses a granular build numbering system:

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
- [VPS Quality Gates Specification](VPS_QUALITY_GATES_SPECIFICATION.md)
- [Deployment Testing Guide](DEPLOYMENT_TESTING_GUIDE.md)

### 🔧 **Operations**

- [Self-Hosting Guide](../OPERATIONS/SELF_HOSTING.md)
- [Infrastructure Guide](../OPERATIONS/INFRASTRUCTURE_GUIDE.md)
-

### ☸️ **Kubernetes Deployment**

- [Kubernetes Quick Start](../../k8s/README.md) - DigitalOcean Kubernetes example
- [Kubernetes README](../../k8s/README.md) - Complete Kubernetes deployment guide (works with any cluster)

### 🏗️ **Architecture**

- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
- [Multi-Container Architecture](../ARCHITECTURE/MULTI_CONTAINER_ARCHITECTURE.md)
- [Streaming Proxy Architecture](../ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)

### 👨‍💻 **Development**

- [Developer Onboarding](../DEVELOPMENT/DEVELOPER_ONBOARDING.md)
- [API Documentation](../DEVELOPMENT/API_DOCUMENTATION.md)

---

*For questions about deployment, please see our [troubleshooting guide](deployment-troubleshooting.md) or [open an issue](https://github.com/Zoidbot-online/Zoidbot/issues).*
