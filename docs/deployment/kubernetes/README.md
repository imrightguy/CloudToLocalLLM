# CloudToLocalLLM - Kubernetes Deployment

## Overview

Deploy CloudToLocalLLM to any Kubernetes cluster (managed or self-hosted) with automatic SSL certificates, load balancing, and auto-scaling.

**Supported Platforms:**
- **Managed Kubernetes**: DigitalOcean Kubernetes (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises clusters, bare metal, or private cloud (ideal for businesses with security/compliance requirements)

## Architecture

```
Internet
   ↓
DigitalOcean Load Balancer (nginx-ingress)
   ↓
┌──────────────────────────────────────┐
│     Kubernetes Cluster (DOKS)        │
│                                      │
│  ┌────────────┐    ┌──────────────┐ │
│  │    Web     │    │ API Backend  │ │
│  │ (2 pods)   │    │  (2 pods)    │ │
│  └────────────┘    └──────────────┘ │
│                           │          │
│                    ┌──────▼───────┐  │
│                    │  PostgreSQL  │  │
│                    │(StatefulSet) │  │
│                    └──────────────┘  │
└──────────────────────────────────────┘
```

## Prerequisites

### 1. Kubernetes Cluster

**Option A: Managed Kubernetes (DigitalOcean Example)**

```bash
# Using doctl CLI for DigitalOcean Kubernetes
doctl kubernetes cluster create cloudtolocalllm \
  --region nyc1 \
  --version latest \
  --node-pool "name=worker-pool;size=s-2vcpu-4gb;count=3" \
  --auto-upgrade=true \
  --surge-upgrade=true

# Configure kubectl
doctl kubernetes cluster kubeconfig save cloudtolocalllm
```

**Option B: Self-Hosted Kubernetes**

For businesses with on-premises or private cloud requirements:

- Minimum: 3 nodes (control plane + workers)
- Recommended: Separate control plane and worker nodes
- Network: Cluster network access and ingress controller
- Storage: Persistent volume support for PostgreSQL

**Other Managed Options:**
- Google GKE: `gcloud container clusters create ...`
- AWS EKS: `eksctl create cluster ...`
- Azure AKS: `az aks create ...`

### 2. Install kubectl

```bash
# Download kubectl (if not already installed)
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# macOS
brew install kubectl

# Configure kubectl for your cluster (method depends on your platform)
# For DigitalOcean: doctl kubernetes cluster kubeconfig save <cluster-name>
# For GKE: gcloud container clusters get-credentials <cluster-name>
# For self-hosted: Copy kubeconfig file from your cluster admin
```

### 3. Build and Push Docker Images

You need to build and push your Docker images to a container registry:

#### Option A: DigitalOcean Container Registry

```bash
# Create registry
doctl registry create cloudtolocalllm

# Login to registry
doctl registry login

# Build and push images
docker build -f config/docker/Dockerfile.web -t registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest .
docker push registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest

docker build -f services/api-backend/Dockerfile.prod -t registry.digitalocean.com/cloudtolocalllm/api:latest .
docker push registry.digitalocean.com/cloudtolocalllm/api:latest
```

#### Option B: Docker Hub

```bash
# Build and push to Docker Hub
docker build -f config/docker/Dockerfile.web -t yourusername/cloudtolocalllm-web:latest .
docker push yourusername/cloudtolocalllm-web:latest

docker build -f services/api-backend/Dockerfile.prod -t yourusername/cloudtolocalllm-api:latest .
docker push yourusername/cloudtolocalllm-api:latest
```

## Quick Deploy

### 1. Configure Secrets

```bash
cd k8s
cp secrets.yaml.template secrets.yaml
nano secrets.yaml  # Edit with your actual values
```

Required values:
- `postgres-password`: Strong database password
- `jwt-secret`: Generate with `openssl rand -base64 32`
- `auth0-domain`: Your Auth0 tenant domain
- `auth0-audience`: Your Auth0 API audience

### 2. Update ConfigMap

Edit `configmap.yaml` and set your domain:

```yaml
data:
  DOMAIN: "yourdomain.com"
```

### 3. Update Image References

Edit deployment files and replace `YOUR_REGISTRY` with your actual registry:

```bash
# In api-backend-deployment.yaml
image: registry.digitalocean.com/cloudtolocalllm/api:latest

# In web-deployment.yaml
image: registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest
```

### 4. Update Ingress Domains

Edit `ingress-nginx.yaml` and replace `yourdomain.com` with your actual domain:

```yaml
spec:
  tls:
    - hosts:
        - yourdomain.com
        - app.yourdomain.com
        - api.yourdomain.com
```

### 5. Deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Install nginx-ingress controller
2. Install cert-manager
3. Deploy all services
4. Configure SSL certificates
5. Display load balancer IP

### 6. Configure DNS

Point your domain A records to the load balancer IP:

```
yourdomain.com     A  <LOAD_BALANCER_IP>
app.yourdomain.com A  <LOAD_BALANCER_IP>
api.yourdomain.com A  <LOAD_BALANCER_IP>
```

## Manual Deployment

### Step 1: Install nginx-ingress

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/do/deploy.yaml
```

### Step 2: Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Step 3: Deploy Application

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Apply secrets and config
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml

# Deploy database
kubectl apply -f postgres-statefulset.yaml

# Wait for PostgreSQL
kubectl wait --namespace cloudtolocalllm \
  --for=condition=ready pod \
  --selector=app=postgres \
  --timeout=120s

# Deploy application
kubectl apply -f api-backend-deployment.yaml
kubectl apply -f web-deployment.yaml

# Configure SSL
kubectl apply -f cert-manager.yaml

# Configure ingress
kubectl apply -f ingress-nginx.yaml
```

### Step 4: Get Load Balancer IP

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Monitoring & Management

### View Logs

```bash
# API backend logs
kubectl logs -n cloudtolocalllm -l app=api-backend -f

# Web application logs
kubectl logs -n cloudtolocalllm -l app=web -f

# PostgreSQL logs
kubectl logs -n cloudtolocalllm -l app=postgres -f
```

### Check Status

```bash
# All pods
kubectl get pods -n cloudtolocalllm

# Services
kubectl get svc -n cloudtolocalllm

# Ingress
kubectl get ingress -n cloudtolocalllm

# Certificates
kubectl get certificate -n cloudtolocalllm
```

### Scale Deployments

```bash
# Scale API backend
kubectl scale -n cloudtolocalllm deployment/api-backend --replicas=5

# Scale web application
kubectl scale -n cloudtolocalllm deployment/web --replicas=3
```

### Update Deployments

```bash
# Update API backend image
kubectl set image -n cloudtolocalllm deployment/api-backend \
  api-backend=registry.digitalocean.com/cloudtolocalllm/api:v2.0.0

# Update web application image
kubectl set image -n cloudtolocalllm deployment/web \
  web=registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:v2.0.0
```

### Database Backup

```bash
# Backup PostgreSQL
kubectl exec -n cloudtolocalllm -it postgres-0 -- \
  pg_dump -U appuser cloudtolocalllm > backup_$(date +%Y%m%d).sql

# Restore from backup
kubectl exec -n cloudtolocalllm -i postgres-0 -- \
  psql -U appuser cloudtolocalllm < backup_20240101.sql
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n cloudtolocalllm <pod-name>

# Check events
kubectl get events -n cloudtolocalllm --sort-by='.lastTimestamp'
```

### SSL Certificate Issues

```bash
# Check certificate status
kubectl describe certificate -n cloudtolocalllm cloudtolocalllm-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Manually trigger certificate request
kubectl delete certificate -n cloudtolocalllm cloudtolocalllm-tls
kubectl apply -f ingress-nginx.yaml
```

### Database Connection Issues

```bash
# Test database connection
kubectl exec -n cloudtolocalllm -it postgres-0 -- \
  psql -U appuser -d cloudtolocalllm

# Check database logs
kubectl logs -n cloudtolocalllm postgres-0 -f
```

### Load Balancer Issues

```bash
# Check load balancer status
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Check ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

## Cost Optimization

### DigitalOcean Pricing

- **Kubernetes Cluster**: Free (you only pay for nodes)
- **Worker Nodes**: ~$24/month per node (2 vCPU, 4GB RAM)
- **Load Balancer**: ~$12/month
- **Block Storage**: ~$0.10/GB/month
- **Container Registry**: Free for 500MB storage

### Recommended Setup

**Small Deployment** (< 100 users):
- 2 worker nodes (s-2vcpu-4gb)
- ~$60/month

**Medium Deployment** (100-500 users):
- 3 worker nodes (s-4vcpu-8gb)
- ~$144/month

**Large Deployment** (500+ users):
- 5 worker nodes (s-4vcpu-8gb) with auto-scaling
- ~$240/month

## Auto-Scaling

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-backend-hpa
  namespace: cloudtolocalllm
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Apply with:
```bash
kubectl apply -f hpa.yaml
```

### Cluster Autoscaler

Enable in DigitalOcean dashboard or via doctl:

```bash
doctl kubernetes cluster update cloudtolocalllm \
  --auto-upgrade=true \
  --surge-upgrade=true
```

## Security Best Practices

1. **Use Secrets**: Never commit `secrets.yaml` to version control
2. **Enable RBAC**: Configure role-based access control
3. **Network Policies**: Restrict pod-to-pod communication
4. **Resource Limits**: Set CPU/memory limits for all pods
5. **Regular Updates**: Keep Kubernetes and images updated
6. **Monitoring**: Set up Prometheus + Grafana
7. **Backups**: Automate database backups

## Next Steps

1. **Monitoring**: Set up Prometheus and Grafana
2. **Logging**: Configure Loki or ELK stack
3. **CI/CD**: Automate deployments with GitHub Actions
4. **Disaster Recovery**: Implement backup and restore procedures
5. **High Availability**: Configure multi-region deployment

## Support

- **DigitalOcean Kubernetes Docs**: https://docs.digitalocean.com/products/kubernetes/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **nginx-ingress**: https://kubernetes.github.io/ingress-nginx/
- **cert-manager**: https://cert-manager.io/docs/

---

**Ready to deploy to Kubernetes!** 🚀

