# Self-Hosted Kubernetes Deployment Guide

This guide covers deploying CloudToLocalLLM to a **self-hosted Kubernetes cluster**, ideal for businesses with security, compliance, or data sovereignty requirements.

## Why Self-Hosted Kubernetes?

**Benefits:**
- **Data Sovereignty**: Keep data within your own infrastructure
- **Security Compliance**: Meet regulatory requirements (HIPAA, GDPR, etc.)
- **Cost Control**: Predictable costs for predictable workloads
- **Full Control**: Complete control over infrastructure and configuration
- **Network Isolation**: Deploy in air-gapped or private network environments

## Prerequisites

### 1. Kubernetes Cluster Requirements

**Minimum Setup:**
- **3 Nodes**: 1 control plane + 2 worker nodes
- **CPU**: 2 vCPU per node minimum
- **RAM**: 4GB per node minimum
- **Storage**: 50GB per node (SSD recommended)
- **Network**: Internal cluster network + ingress connectivity

**Recommended Setup:**
- **Separate Control Plane**: 3 control plane nodes (high availability)
- **Worker Nodes**: 3+ worker nodes
- **CPU**: 4+ vCPU per worker node
- **RAM**: 8GB+ per worker node
- **Storage**: 100GB+ per node with persistent volume support

### 2. Required Kubernetes Components

Your cluster must have:
- **CNI Plugin**: Flannel, Calico, or similar
- **Ingress Controller**: nginx-ingress or Traefik
- **Storage Class**: For PostgreSQL persistent volumes
- **LoadBalancer**: MetalLB for on-premises (or cloud LoadBalancer if hybrid)

### 3. Container Registry

**Options:**
- **Self-Hosted Registry**: Harbor, GitLab Container Registry, or Docker Registry
- **Private Registry**: Quay.io, Nexus Repository
- **Public Registry**: Docker Hub (private repositories)

## Deployment Steps

### Step 1: Configure Container Registry

**For Self-Hosted Registry:**

```bash
# Example: Harbor registry
docker login harbor.yourdomain.com
```

**For Docker Hub:**

```bash
docker login
```

### Step 2: Build and Push Images

```bash
# Build and tag images for your registry
docker build -f config/docker/Dockerfile.web \
  -t your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest .

docker build -f services/api-backend/Dockerfile.prod \
  -t your-registry.com/cloudtolocalllm/api:latest .

# Push to registry
docker push your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest
docker push your-registry.com/cloudtolocalllm/api:latest
```

### Step 3: Update Kubernetes Manifests

**Update image references** in deployment files:

**`k8s/web-deployment.yaml`:**
```yaml
spec:
  containers:
  - name: web
    image: your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest
```

**`k8s/api-backend-deployment.yaml`:**
```yaml
spec:
  containers:
  - name: api-backend
    image: your-registry.com/cloudtolocalllm/api:latest
```

**Update ConfigMap** (`k8s/configmap.yaml`) with your domain:
```yaml
data:
  DOMAIN: "yourdomain.com"
  API_DOMAIN: "api.yourdomain.com"
  WEB_DOMAIN: "app.yourdomain.com"
```

### Step 4: Configure Image Pull Secrets (if private registry)

If using a private registry, create a pull secret:

```bash
# Create secret for Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=your-registry.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email \
  -n cloudtolocalllm
```

Then add to deployments:
```yaml
spec:
  imagePullSecrets:
  - name: regcred
```

### Step 5: Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets (update with your values first)
kubectl apply -f k8s/secrets.yaml

# Create ConfigMap
kubectl apply -f k8s/configmap.yaml

# Deploy PostgreSQL
kubectl apply -f k8s/postgres-statefulset.yaml

# Wait for database
kubectl wait --for=condition=ready pod -l app=postgres -n cloudtolocalllm --timeout=300s

# Deploy applications
kubectl apply -f k8s/api-backend-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml

# Deploy ingress
kubectl apply -f k8s/ingress-nginx.yaml
```

### Step 6: Configure Ingress

**For MetalLB (On-Premises):**

Install MetalLB if not already installed:
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

Configure LoadBalancer IP pool in `metallb-config.yaml`:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: cloudtolocalllm-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.100-192.168.1.200  # Your IP range
```

**For Cloud LoadBalancer:**
- GKE: Automatically provisions LoadBalancer
- EKS: Uses AWS ELB
- AKS: Uses Azure Load Balancer

### Step 7: SSL Certificates

**Option A: cert-manager with Let's Encrypt**

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configure ClusterIssuer for Let's Encrypt
kubectl apply -f k8s/cert-manager.yaml  # Create this file with your Let's Encrypt config
```

**Option B: Self-Signed Certificates (Internal Use)**

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=app.yourdomain.com"

# Create Kubernetes secret
kubectl create secret tls cloudtolocalllm-tls \
  --cert=tls.crt --key=tls.key -n cloudtolocalllm
```

### Step 8: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n cloudtolocalllm

# Check services
kubectl get svc -n cloudtolocalllm

# Check ingress
kubectl get ingress -n cloudtolocalllm

# View logs
kubectl logs -f deployment/api-backend -n cloudtolocalllm
kubectl logs -f deployment/web -n cloudtolocalllm
```

## Network Configuration

### Internal Network Access

For services to communicate internally:
- Ensure cluster DNS (CoreDNS) is functioning
- Verify service discovery works: `kubectl exec -it <pod> -n cloudtolocalllm -- nslookup api-backend`

### External Access

**Ingress Controller:**
- Configure nginx-ingress for external access
- Update DNS records to point to LoadBalancer IP or ingress IP
- Configure firewall rules to allow traffic on ports 80 and 443

**Direct NodePort Access (Alternative):**
If LoadBalancer isn't available:
```yaml
apiVersion: v1
kind: Service
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30080
```

Access via: `http://<node-ip>:30080`

## Storage Configuration

### PostgreSQL Persistent Volume

Ensure your cluster has a StorageClass configured:

```bash
# Check available StorageClasses
kubectl get storageclass

# If none exists, create one for your storage solution
# Example: NFS, Ceph, or local storage
```

Update `k8s/postgres-statefulset.yaml` if needed:
```yaml
spec:
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      storageClassName: your-storage-class
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```

## Security Considerations

### 1. Network Policies

Create network policies to restrict traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cloudtolocalllm-netpol
  namespace: cloudtolocalllm
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

### 2. RBAC

Ensure service accounts have minimal required permissions:
- Review existing RBAC in `k8s/` manifests
- Follow principle of least privilege

### 3. Secrets Management

For production, consider:
- **HashiCorp Vault**: External secrets management
- **Sealed Secrets**: Encrypted secrets for Git
- **External Secrets Operator**: Sync secrets from external systems

### 4. Image Security

- Scan images for vulnerabilities before deployment
- Use image signing (cosign, Notary)
- Implement image pull policies (Always vs IfNotPresent)

## Monitoring and Logging

### Recommended Stack

- **Monitoring**: Prometheus + Grafana
- **Logging**: Loki + Grafana or ELK stack
- **Tracing**: Jaeger (optional)

### Health Checks

Configure health check endpoints:
- Web: `/health`
- API: `/health`
- Database: PostgreSQL readiness probe

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n cloudtolocalllm

# Check events
kubectl get events -n cloudtolocalllm --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n cloudtolocalllm
```

### Image Pull Errors

```bash
# Verify image exists in registry
docker pull your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest

# Check image pull secrets
kubectl get secrets -n cloudtolocalllm

# Verify registry authentication
kubectl describe pod <pod-name> -n cloudtolocalllm | grep -i "image"
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl logs -l app=postgres -n cloudtolocalllm

# Verify database service
kubectl get svc postgres -n cloudtolocalllm

# Test connection from API pod
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- \
  psql -h postgres -U appuser -d cloudtolocalllm
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress -n cloudtolocalllm

# Verify DNS resolution
nslookup app.yourdomain.com
```

## Maintenance

### Updating Images

```bash
# Build new images
docker build -f config/docker/Dockerfile.web -t your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:v2.0.0 .
docker push your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:v2.0.0

# Update deployment
kubectl set image deployment/web web=your-registry.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:v2.0.0 -n cloudtolocalllm

# Or update manifest and apply
kubectl apply -f k8s/web-deployment.yaml
```

### Backing Up PostgreSQL

```bash
# Manual backup
kubectl exec -it postgres-0 -n cloudtolocalllm -- \
  pg_dump -U appuser cloudtolocalllm > backup.sql

# Automated backup (cron job)
kubectl apply -f k8s/utilities/backup-cronjob.yaml
```

## Support

For issues specific to self-hosted Kubernetes:
- Check Kubernetes cluster health: `kubectl get componentstatuses`
- Review cluster logs on control plane nodes
- Verify network connectivity between nodes
- Check resource availability: `kubectl top nodes`

---

**Note**: This guide assumes a basic understanding of Kubernetes operations. For cluster setup, see Kubernetes official documentation or your distribution's guide (kubeadm, k3s, Rancher, etc.).

