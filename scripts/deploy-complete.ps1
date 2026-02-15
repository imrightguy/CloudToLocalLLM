# ============================================================================
# Complete Deployment Script for DigitalOcean Kubernetes
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║     Zoidbot - Complete Deployment to DO K8s           ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Add doctl to PATH
$env:Path = "$env:Path;$env:LOCALAPPDATA\doctl"

# Variables
$registry = "registry.digitalocean.com/zoidbot"
$clusterName = "zoidbot"
$namespace = "zoidbot"

Write-Host "Step 1: Logging in to DigitalOcean Container Registry..." -ForegroundColor Yellow
doctl registry login

Write-Host "`nStep 2: Building Docker images..." -ForegroundColor Yellow
Write-Host "Building web image..." -ForegroundColor Cyan
docker build -f config/docker/Dockerfile.web -t ${registry}/web:latest .

Write-Host "Building API image..." -ForegroundColor Cyan
docker build -f services/api-backend/Dockerfile.prod -t ${registry}/api:latest .

Write-Host "`nStep 3: Pushing images to registry..." -ForegroundColor Yellow
docker push ${registry}/web:latest
docker push ${registry}/api:latest

Write-Host "`nStep 4: Connecting to Kubernetes cluster..." -ForegroundColor Yellow
doctl kubernetes cluster kubeconfig save $clusterName

Write-Host "`nStep 5: Applying Kubernetes manifests..." -ForegroundColor Yellow
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l app=postgres --namespace=$namespace --timeout=300s

kubectl apply -f k8s/api-backend-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml
kubectl apply -f k8s/cert-manager.yaml
kubectl apply -f k8s/ingress-nginx.yaml

Write-Host "`nStep 6: Waiting for deployments..." -ForegroundColor Yellow
kubectl rollout status deployment/api-backend --namespace=$namespace --timeout=300s
kubectl rollout status deployment/web --namespace=$namespace --timeout=300s

Write-Host "`nStep 7: Getting deployment status..." -ForegroundColor Yellow
Write-Host "`n=== Pods ===" -ForegroundColor Cyan
kubectl get pods -n $namespace

Write-Host "`n=== Services ===" -ForegroundColor Cyan
kubectl get svc -n $namespace

Write-Host "`n=== Ingress ===" -ForegroundColor Cyan
kubectl get ingress -n $namespace

Write-Host "`n=== Load Balancer ===" -ForegroundColor Cyan
$lbIP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Load Balancer IP: $lbIP" -ForegroundColor Green

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                   Deployment Complete!                         ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Configure DNS A records to point to: $lbIP" -ForegroundColor White
Write-Host "   yourdomain.com     -> $lbIP" -ForegroundColor Gray
Write-Host "   app.yourdomain.com -> $lbIP" -ForegroundColor Gray
Write-Host "   api.yourdomain.com -> $lbIP" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Wait for SSL certificates (5-15 minutes after DNS propagation)" -ForegroundColor White
Write-Host ""
Write-Host "3. Test your deployment:" -ForegroundColor White
Write-Host "   curl https://yourdomain.com/health" -ForegroundColor Gray
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  kubectl logs -n $namespace -l app=api-backend -f" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $namespace" -ForegroundColor Gray
Write-Host "  kubectl describe ingress -n $namespace" -ForegroundColor Gray
Write-Host ""

