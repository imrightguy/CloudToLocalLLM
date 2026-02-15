# Zoidbot Complete Deployment Workflow

This is the **ONE AND ONLY** deployment document for Zoidbot. Follow this exactly to ensure a smooth and successful deployment.

**Estimated Total Time:** 45-90 minutes

**⚠️ IMPORTANT NOTICE**: AUR (Arch User Repository) support has been temporarily removed as of v3.10.3. See [AUR Status Documentation](./AUR_STATUS.md) for complete details and reintegration timeline.

**Related Documentation:**

- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
-
- [Versioning Strategy](./VERSIONING_STRATEGY.md)

---

## 🔍 **Phase 1: Pre-Flight Checks** (5 minutes)

**MANDATORY: Complete ALL checks before starting deployment**

### **Environment Verification**

```bash
# 1. Verify you're in the correct directory
pwd
# Expected: /path/to/Zoidbot

# 2. Check Git status
git status
# Expected: "working tree clean" or only untracked files

# 3. Verify Flutter installation
flutter --version
# Expected: Flutter 3.x.x or higher

# 4. Verify Docker installation
docker --version
# Expected: Docker version 20.10 or higher

# 5. Verify kubectl installation
kubectl version --client
# Expected: kubectl client version

# 6. Verify kubectl is configured for your cluster
kubectl cluster-info
# Expected: Cluster information displayed
```

### **Required Tools Checklist**

- [ ] Docker installed and running
- [ ] kubectl installed and configured for your Kubernetes cluster
- [ ] Container registry access (Docker Hub, DigitalOcean, self-hosted, etc.)
- [ ] Git configured with proper credentials

**Note:** For DigitalOcean Kubernetes, you'll also need `doctl` CLI. For other platforms, use their respective CLI tools.

---

## 📋 **Phase 2: Build Docker Images** (15-20 minutes)

### **Build and Push Images to Container Registry**

Zoidbot uses Dockerfiles for container builds. Build and push images to your registry:

```bash
# Authenticate with your container registry
# Docker Hub: docker login
# DigitalOcean: doctl registry login
# Other registries: Follow your registry's authentication process

# Build and push web application image (update registry as needed)
docker build -f config/docker/Dockerfile.web \
  -t your-registry/zoidbot-web:latest .
docker push your-registry/zoidbot-web:latest

# Build and push API backend image
docker build -f services/api-backend/Dockerfile.prod \
  -t your-registry/zoidbot-api:latest .
docker push your-registry/zoidbot-api:latest
```

**Note:** Update image tags in `k8s/api-backend-deployment.yaml` and `k8s/web-deployment.yaml` if using different tags.

---

## 🚀 **Phase 3: Deploy to Kubernetes** (15-20 minutes)

**Works with any Kubernetes cluster:** managed (DigitalOcean, GKE, EKS, AKS) or self-hosted.

### **Step 3.1: Configure Kubernetes Secrets**

Create secrets for your Kubernetes cluster:

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets (update secrets.yaml with your values first)
kubectl apply -f k8s/secrets.yaml

# Create ConfigMap (update configmap.yaml with your domain)
kubectl apply -f k8s/configmap.yaml
```

### **Step 3.2: Deploy Database**

```bash
# Deploy PostgreSQL StatefulSet
kubectl apply -f k8s/postgres-statefulset.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n zoidbot --timeout=300s
```

### **Step 3.3: Deploy Applications**

```bash
# Deploy API backend
kubectl apply -f k8s/api-backend-deployment.yaml

# Deploy web application
kubectl apply -f k8s/web-deployment.yaml

# Deploy ingress
kubectl apply -f k8s/ingress-nginx.yaml
```

### **Step 3.4: Verify Deployment**

```bash
# Check pod status
kubectl get pods -n zoidbot

# Check services
kubectl get svc -n zoidbot

# Test main application
curl -I https://app.zoidbot.online
# Expected: HTTP/1.1 200 OK

# Check version endpoint
curl -s https://app.zoidbot.online/version.json
```

---

## ✅ **Phase 4: Comprehensive Verification** (10 minutes)

### **Kubernetes Health Checks**

```bash
# Check all pods are running
kubectl get pods -n zoidbot

# View pod logs
kubectl logs -f deployment/api-backend -n zoidbot
kubectl logs -f deployment/web -n zoidbot

# Check ingress status
kubectl get ingress -n zoidbot
```

### **Manual Verification**

- **Web Application:** Loads correctly at https://app.zoidbot.online, authentication works, no console errors
- **API Backend:** Health check endpoint returns 200 OK
- **Database:** PostgreSQL pods are running and accepting connections

---

## 🚫 **Deployment Completion Criteria**

- **Version Consistency:** All components show the identical version number.
- **All Components Deployed:** Git repo updated, Docker images built, Kubernetes cluster deployed.
- **Comprehensive Testing Completed:** All automated and manual tests passed.

---

## 🔧 **Troubleshooting**

- **Pod Not Starting:** Check pod logs with `kubectl logs <pod-name> -n zoidbot`
- **Image Pull Errors:** Verify image registry credentials and image tags
- **Database Connection Issues:** Check PostgreSQL pod logs and verify secrets
- **Ingress Issues:** Check ingress controller and DNS configuration
- **Authentication Errors:** Verify Auth0 environment variables in ConfigMap and Secrets

For more detailed troubleshooting, see [Kubernetes README](../../k8s/README.md).
