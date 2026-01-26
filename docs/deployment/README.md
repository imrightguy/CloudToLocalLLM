# CloudToLocalLLM Deployment Documentation

## 📚 Documentation Overview

This directory contains deployment documentation for CloudToLocalLLM. The project uses **Dockerfile-based builds** and deploys to **Kubernetes** (managed or self-hosted).

## 🎯 Primary Documentation (Start Here)

### **[DEPLOYMENT_OVERVIEW.md](./DEPLOYMENT_OVERVIEW.md)** ⭐ **PRIMARY**

**Complete deployment overview** - All deployment options and strategies.

- **Purpose**: Understand all deployment methods
- **Audience**: All developers and deployment operators
- **Content**: Kubernetes deployment, Dockerfiles, platform options
- **When to use**: For understanding deployment architecture

### **[COMPLETE_DEPLOYMENT_WORKFLOW.md](./COMPLETE_DEPLOYMENT_WORKFLOW.md)** ⭐ **ESSENTIAL**

**Step-by-step deployment guide** - Complete deployment process.

- **Purpose**: Execute deployments
- **Audience**: Developers, DevOps engineers, deployment operators
- **Content**: Detailed procedures, commands, verification steps
- **When to use**: For executing actual deployments

### **[VERSIONING_STRATEGY.md](./VERSIONING_STRATEGY.md)**

**Version management strategy** - How to manage versions.

- **Purpose**: Version increment decisions
- **Audience**: Release managers, developers
- **Content**: Version format, increment guidelines
- **When to use**: Before starting deployments

## 🔧 Specialized Documentation

### **[STRICT_DEPLOYMENT_POLICY.md](./STRICT_DEPLOYMENT_POLICY.md)**

**Quality standards** - Deployment quality requirements.

- **Purpose**: Understand quality gates
- **Audience**: DevOps engineers
- **Content**: Quality standards, rollback procedures

### **[AUR_STATUS.md](./AUR_STATUS.md)**

**AUR package status** - Temporarily removed, reintegration planned.

- **Status**: AUR support temporarily removed
- **Alternative**: Use AppImage for Linux

## 📋 Quick Reference

### **For New Deployments**

1. Read [`DEPLOYMENT_OVERVIEW.md`](./DEPLOYMENT_OVERVIEW.md) → Understand deployment options
2. Read [`COMPLETE_DEPLOYMENT_WORKFLOW.md`](./COMPLETE_DEPLOYMENT_WORKFLOW.md) → Execute deployment
3. Reference [`KUBERNETES_QUICKSTART.md`](../../k8s/README.md) → DigitalOcean example
4. See [`k8s/README.md`](../../k8s/README.md) → Complete Kubernetes guide

### **For Kubernetes Deployment**

- **Managed Kubernetes**: See [`KUBERNETES_QUICKSTART.md`](../../k8s/README.md) for DigitalOcean example
- **Self-Hosted Kubernetes**: See [`KUBERNETES_SELF_HOSTED_GUIDE.md`](../../KUBERNETES_SELF_HOSTED_GUIDE.md) for on-premises deployment
- **Any Kubernetes**: See [`k8s/README.md`](../../k8s/README.md) for platform-agnostic guide

## ✅ Current Deployment Method

**CloudToLocalLLM uses:**

- **Dockerfiles** for building container images
- **Kubernetes** for orchestration (any cluster: managed or self-hosted)
- **kubectl apply** for deployment

**No longer used:**

- Deployment scripts in `scripts/deploy/` folder (for cloud deployment)
- VPS deployment scripts
- Docker Compose for production (use Kubernetes instead)

---

*For questions about deployment, see [COMPLETE_DEPLOYMENT_WORKFLOW.md](./COMPLETE_DEPLOYMENT_WORKFLOW.md) or [open an issue](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues).*
