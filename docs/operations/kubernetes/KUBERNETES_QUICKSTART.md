# 🚀 Quick Start: Deploy to Kubernetes (DigitalOcean Example)

This guide uses **DigitalOcean Kubernetes (DOKS)** as an example, but the same process works with any Kubernetes cluster (managed or self-hosted). For self-hosted Kubernetes, skip the DigitalOcean-specific steps and use your cluster's kubectl configuration.

## Step 1: Connect to Your Cluster

```bash
# If you haven't already, configure kubectl
doctl auth init
doctl kubernetes cluster kubeconfig save <your-cluster-name>

# Verify connection
kubectl cluster-info
kubectl get nodes
```

## Step 2: Build and Push Docker Images

You need to push your images to a container registry. Choose one:

### Option A: DigitalOcean Container Registry (Recommended)

```bash
# Create registry if you haven't
doctl registry create cloudtolocalllm

# Login
doctl registry login

# Build and push web image
docker build -f config/docker/Dockerfile.web \
  -t registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest .
docker push registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest

# Build and push API image
docker build -f services/api-backend/Dockerfile.prod \
  -t registry.digitalocean.com/cloudtolocalllm/api:latest .
docker push registry.digitalocean.com/cloudtolocalllm/api:latest
```

### Option B: Docker Hub

```bash
# Build and push
docker build -f config/docker/Dockerfile.web -t yourusername/cloudtolocalllm-web:latest .
docker push yourusername/cloudtolocalllm-web:latest

docker build -f services/api-backend/Dockerfile.prod -t yourusername/cloudtolocalllm-api:latest .
docker push yourusername/cloudtolocalllm-api:latest
```

## Step 3: Configure Your Deployment

### 3.1 Create Secrets

```bash
cd k8s
cp secrets.yaml.template secrets.yaml
```

Edit `secrets.yaml`:
```yaml
stringData:
  postgres-password: "YOUR_STRONG_DB_PASSWORD"      # Make it strong!
  jwt-secret: "YOUR_JWT_SECRET"                     # Generate: openssl rand -base64 32
  supabase-auth-domain: "your-tenant.us.supabase-auth.com"          # Your Supabase Auth domain
  supabase-auth-audience: "https://app.yourdomain.com"      # Your Supabase Auth audience
```

### 3.2 Update ConfigMap

Edit `configmap.yaml`:
```yaml
data:
  DOMAIN: "yourdomain.com"  # Replace with your domain
```

### 3.3 Update Image References

Edit `api-backend-deployment.yaml`:
```yaml
containers:
  - name: api-backend
    image: registry.digitalocean.com/cloudtolocalllm/api:latest  # Your registry
```

Edit `web-deployment.yaml`:
```yaml
containers:
  - name: web
    image: registry.digitalocean.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/web:latest  # Your registry
```

### 3.4 Update Ingress Domains

Edit `ingress-nginx.yaml` - replace all instances of `yourdomain.com` with your actual domain.

Also update `cert-manager.yaml`:
```yaml
spec:
  acme:
    email: admin@yourdomain.com  # Your email
```

## Step 4: Deploy!

```bash
cd k8s
chmod +x deploy.sh
./deploy.sh
```

The script will:
- ✅ Install nginx-ingress controller
- ✅ Install cert-manager for SSL
- ✅ Deploy PostgreSQL database
- ✅ Deploy API backend (2 replicas)
- ✅ Deploy web application (2 replicas)
- ✅ Configure SSL certificates
- ✅ Set up ingress routing

## Step 5: Configure DNS

After deployment completes, you'll see:
```
Load Balancer IP: 159.89.123.456
```

Configure your DNS A records:
```
yourdomain.com     A  159.89.123.456
app.yourdomain.com A  159.89.123.456
api.yourdomain.com A  159.89.123.456
```

**DNS Propagation**: Wait 5-15 minutes for DNS to propagate.

## Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n cloudtolocalllm

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# api-backend-xxx-yyy           1/1     Running   0          2m
# api-backend-xxx-zzz           1/1     Running   0          2m
# postgres-0                     1/1     Running   0          3m
# web-xxx-yyy                   1/1     Running   0          2m
# web-xxx-zzz                   1/1     Running   0          2m

# Check SSL certificate
kubectl get certificate -n cloudtolocalllm

# Should show: READY=True

# Check ingress
kubectl get ingress -n cloudtolocalllm
```

## Step 7: Test Your Deployment

```bash
# Test web app
curl -I https://yourdomain.com

# Test API health
curl https://api.yourdomain.com/health

# Should return: HTTP/2 200
```

## Step 8: Launch Desktop App

1. Start your Windows CloudToLocalLLM desktop app
2. Sign in with Supabase Auth
3. Desktop app will connect to `https://api.yourdomain.com/api/bridge/register`
4. Start chatting with your local Ollama!

## Quick Commands Reference

```bash
# View logs
kubectl logs -n cloudtolocalllm -l app=api-backend -f

# Restart deployment
kubectl rollout restart -n cloudtolocalllm deployment/api-backend

# Scale up
kubectl scale -n cloudtolocalllm deployment/api-backend --replicas=5

# Check resource usage
kubectl top pods -n cloudtolocalllm
kubectl top nodes

# Delete everything (careful!)
kubectl delete namespace cloudtolocalllm
```

## Troubleshooting

### Pods Not Starting?

```bash
# Check pod status
kubectl describe pod -n cloudtolocalllm <pod-name>

# Check logs
kubectl logs -n cloudtolocalllm <pod-name>
```

### SSL Certificate Not Ready?

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Check certificate status
kubectl describe certificate -n cloudtolocalllm cloudtolocalllm-tls

# Common issue: DNS not propagated yet (wait 15 minutes)
```

### Database Connection Issues?

```bash
# Test database connection
kubectl exec -n cloudtolocalllm -it postgres-0 -- \
  psql -U appuser -d cloudtolocalllm

# Check database logs
kubectl logs -n cloudtolocalllm postgres-0
```

### Desktop App Can't Connect?

1. **Check API is accessible**: `curl https://api.yourdomain.com/health`
2. **Check Supabase Auth configuration**: Verify domain and audience
3. **Check desktop app logs**: Look for connection errors
4. **Verify DNS**: Make sure DNS points to load balancer IP

## Cost Estimate

**Your DigitalOcean Setup:**
- Kubernetes Cluster: Free
- 3 Worker Nodes (s-2vcpu-4gb): ~$72/month
- Load Balancer: ~$12/month
- Block Storage (30GB): ~$3/month
- **Total: ~$87/month**

**To reduce costs:**
- Use 2 nodes instead of 3: ~$60/month
- Use smaller nodes (s-1vcpu-2gb): ~$36/month

## Next Steps

1. ✅ **Monitor**: Set up Prometheus + Grafana
2. ✅ **Backups**: Automate PostgreSQL backups
3. ✅ **CI/CD**: GitHub Actions for auto-deployment
4. ✅ **Auto-scaling**: Enable HPA for API backend
5. ✅ **Alerts**: Set up Slack/email alerts

## Need Help?

- Full docs: `k8s/README.md`
- Docker docs: `DOCKER_DEPLOYMENT.md`
- Tunnel docs: `TUNNEL_IMPLEMENTATION_STATUS.md`

---

**You're ready to deploy to Kubernetes!** 🚀

Run: `cd k8s && ./deploy.sh`

