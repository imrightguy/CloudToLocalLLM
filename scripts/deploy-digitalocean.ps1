# Zoidbot - DigitalOcean Kubernetes Deployment Script
# Complete automation for deploying to DigitalOcean Kubernetes

param(
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "zoidbot",
    
    [Parameter(Mandatory=$false)]
    [string]$Registry = "zoidbot",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDNS,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   Zoidbot - DigitalOcean Kubernetes Deployment    ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

#######################################################################
# Configuration
#######################################################################

$DOMAIN = "zoidbot.online"
$NAMESPACE = "zoidbot"
$REGISTRY_URL = "registry.digitalocean.com/$Registry"

#######################################################################
# Step 1: Prerequisites Check
#######################################################################

Write-Host "Step 1: Checking prerequisites..." -ForegroundColor Yellow
Write-Host ""

# Check doctl
if (!(Get-Command doctl -ErrorAction SilentlyContinue)) {
    Write-Host "✗ doctl CLI not found" -ForegroundColor Red
    Write-Host "Install from: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
}
Write-Host "✓ doctl CLI found" -ForegroundColor Green

# Check kubectl
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "✗ kubectl not found" -ForegroundColor Red
    Write-Host "Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
}
Write-Host "✓ kubectl found" -ForegroundColor Green

# Check Docker
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "✗ Docker not found" -ForegroundColor Red
    Write-Host "Install from: https://docs.docker.com/get-docker/"
    exit 1
}
Write-Host "✓ Docker found" -ForegroundColor Green

# Check doctl authentication
try {
    doctl account get | Out-Null
    Write-Host "✓ doctl authenticated" -ForegroundColor Green
} catch {
    Write-Host "✗ doctl not authenticated" -ForegroundColor Red
    Write-Host "Run: doctl auth init"
    exit 1
}

Write-Host ""

#######################################################################
# Step 2: Connect to Kubernetes Cluster
#######################################################################

Write-Host "Step 2: Connecting to Kubernetes cluster..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Fetching cluster config for: $ClusterName"
doctl kubernetes cluster kubeconfig save $ClusterName

# Verify connection
$clusterInfo = kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to connect to cluster" -ForegroundColor Red
    Write-Host $clusterInfo
    exit 1
}
Write-Host "✓ Connected to cluster" -ForegroundColor Green

# Get nodes
Write-Host ""
Write-Host "Cluster nodes:"
kubectl get nodes
Write-Host ""

#######################################################################
# Step 3: Build and Push Docker Images
#######################################################################

if (!$SkipBuild) {
    Write-Host "Step 3: Building and pushing Docker images..." -ForegroundColor Yellow
    Write-Host ""
    
    # Login to registry
    Write-Host "Logging in to DigitalOcean Container Registry..."
    doctl registry login
    
    # Build web image
    Write-Host ""
    Write-Host "Building web application image..." -ForegroundColor Cyan
    docker build -f config/docker/Dockerfile.web -t ${REGISTRY_URL}/web:latest .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to build web image" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Web image built" -ForegroundColor Green
    
    # Build API image
    Write-Host ""
    Write-Host "Building API backend image..." -ForegroundColor Cyan
    docker build -f services/api-backend/Dockerfile.prod -t ${REGISTRY_URL}/api:latest .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to build API image" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ API image built" -ForegroundColor Green
    
    # Push images
    if (!$DryRun) {
        Write-Host ""
        Write-Host "Pushing images to registry..." -ForegroundColor Cyan
        
        docker push ${REGISTRY_URL}/web:latest
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Failed to push web image" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ Web image pushed" -ForegroundColor Green
        
        docker push ${REGISTRY_URL}/api:latest
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Failed to push API image" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ API image pushed" -ForegroundColor Green
    }
    
    Write-Host ""
} else {
    Write-Host "Step 3: Skipping image build (--SkipBuild flag)" -ForegroundColor Yellow
    Write-Host ""
}

#######################################################################
# Step 4: Update Kubernetes Manifests
#######################################################################

Write-Host "Step 4: Updating Kubernetes manifests..." -ForegroundColor Yellow
Write-Host ""

# Update image references in deployments
Write-Host "Updating image references..."

$apiDeploymentPath = "k8s/api-backend-deployment.yaml"
$webDeploymentPath = "k8s/web-deployment.yaml"

# Update API deployment
$apiContent = Get-Content $apiDeploymentPath -Raw
$apiContent = $apiContent -replace "image: .*zoidbot.*api.*", "image: ${REGISTRY_URL}/api:latest"
Set-Content -Path $apiDeploymentPath -Value $apiContent

# Update web deployment
$webContent = Get-Content $webDeploymentPath -Raw
$webContent = $webContent -replace "image: .*zoidbot.*web.*", "image: ${REGISTRY_URL}/web:latest"
Set-Content -Path $webDeploymentPath -Value $webContent

Write-Host "✓ Manifests updated" -ForegroundColor Green
Write-Host ""

#######################################################################
# Step 5: Create Secrets (if they don't exist)
#######################################################################

Write-Host "Step 5: Checking secrets..." -ForegroundColor Yellow
Write-Host ""

if (!(Test-Path "k8s/secrets.yaml")) {
    Write-Host " secrets.yaml not found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Creating secrets from template..."
    Copy-Item "k8s/secrets.yaml.template" "k8s/secrets.yaml"
    
    Write-Host ""
    Write-Host "Please edit k8s/secrets.yaml with your actual values:" -ForegroundColor Cyan
    Write-Host "  - postgres-password: Strong database password"
    Write-Host "  - jwt-secret: Generate with: openssl rand -base64 32"
    Write-Host "  - supertokens-api-key: Generate with: openssl rand -base64 32"
    Write-Host ""
    
    $continue = Read-Host "Have you updated secrets.yaml? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Exiting. Please update secrets.yaml and run again."
        exit 0
    }
} else {
    Write-Host "✓ secrets.yaml found" -ForegroundColor Green
}

Write-Host ""

#######################################################################
# Step 6: Deploy to Kubernetes
#######################################################################

Write-Host "Step 6: Deploying to Kubernetes..." -ForegroundColor Yellow
Write-Host ""

if (!$DryRun) {
    Set-Location k8s
    
    # Run deployment script
    if ($IsLinux -or $IsMacOS) {
        chmod +x deploy.sh
        ./deploy.sh
    } else {
        # Windows: Execute the commands manually
        Write-Host "Installing nginx-ingress controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/do/deploy.yaml
        
        Write-Host "Installing cert-manager..."
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
        
        Write-Host "Waiting for cert-manager to be ready..."
        Start-Sleep -Seconds 30
        
        Write-Host "Applying namespace..."
        kubectl apply -f namespace.yaml
        
        Write-Host "Applying secrets..."
        kubectl apply -f secrets.yaml
        
        Write-Host "Applying configmap..."
        kubectl apply -f configmap.yaml
        
        Write-Host "Deploying PostgreSQL..."
        kubectl apply -f postgres-statefulset.yaml
        
        Write-Host "Waiting for PostgreSQL..."
        kubectl wait --namespace $NAMESPACE --for=condition=ready pod --selector=app=postgres --timeout=120s
        
        Write-Host "Deploying API backend..."
        kubectl apply -f api-backend-deployment.yaml
        
        Write-Host "Deploying web application..."
        kubectl apply -f web-deployment.yaml
        
        Write-Host "Configuring cert-manager..."
        kubectl apply -f cert-manager.yaml
        
        Write-Host "Waiting for cert-manager ClusterIssuer..."
        Start-Sleep -Seconds 10
        
        Write-Host "Applying ingress..."
        kubectl apply -f ingress-nginx.yaml
    }
    
    Set-Location ..
    
    Write-Host "✓ Deployment complete" -ForegroundColor Green
} else {
    Write-Host "DRY RUN: Would deploy to Kubernetes" -ForegroundColor Cyan
}

Write-Host ""

#######################################################################
# Step 7: Get Load Balancer IP
#######################################################################

Write-Host "Step 7: Getting Load Balancer IP..." -ForegroundColor Yellow
Write-Host ""

if (!$DryRun) {
    Write-Host "Waiting for Load Balancer (this may take a few minutes)..."
    
    $retries = 0
    $maxRetries = 30
    $lbIP = $null
    
    while ($retries -lt $maxRetries) {
        $lbIP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        
        if ($lbIP) {
            Write-Host "✓ Load Balancer IP: $lbIP" -ForegroundColor Green
            break
        }
        
        $retries++
        Write-Host "  Waiting... ($retries/$maxRetries)"
        Start-Sleep -Seconds 10
    }
    
    if (!$lbIP) {
        Write-Host "✗ Failed to get Load Balancer IP" -ForegroundColor Red
        Write-Host "Check status: kubectl get svc -n ingress-nginx"
    }
} else {
    Write-Host "DRY RUN: Would get Load Balancer IP" -ForegroundColor Cyan
    $lbIP = "123.456.789.012"
}

Write-Host ""

#######################################################################
# Step 8: Setup DNS (Optional)
#######################################################################

if (!$SkipDNS -and $lbIP) {
    Write-Host "Step 8: Setting up DNS..." -ForegroundColor Yellow
    Write-Host ""
    
    $setupDNS = Read-Host "Do you want to setup DigitalOcean DNS now? (y/N)"
    
    if ($setupDNS -eq "y" -or $setupDNS -eq "Y") {
        if ($IsLinux -or $IsMacOS) {
            Set-Location k8s
            chmod +x setup-dns.sh
            ./setup-dns.sh
            Set-Location ..
        } else {
            Write-Host " DNS setup script is for Linux/macOS" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Please run manually in WSL or Git Bash:" -ForegroundColor Cyan
            Write-Host "  cd k8s && ./setup-dns.sh"
        }
    } else {
        Write-Host "Skipping DNS setup" -ForegroundColor Yellow
    }
} else {
    Write-Host "Step 8: Skipping DNS setup" -ForegroundColor Yellow
}

Write-Host ""

#######################################################################
# Summary
#######################################################################

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                    DEPLOYMENT SUMMARY                     ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

if (!$DryRun) {
    Write-Host "Cluster:" -ForegroundColor Cyan
    Write-Host "  Name: $ClusterName"
    Write-Host "  Namespace: $NAMESPACE"
    Write-Host ""
    
    Write-Host "Images:" -ForegroundColor Cyan
    Write-Host "  Web: ${REGISTRY_URL}/web:latest"
    Write-Host "  API: ${REGISTRY_URL}/api:latest"
    Write-Host ""
    
    if ($lbIP) {
        Write-Host "Load Balancer:" -ForegroundColor Cyan
        Write-Host "  IP: $lbIP"
        Write-Host ""
        
        Write-Host "DNS Records Needed:" -ForegroundColor Cyan
        Write-Host "  $DOMAIN              A  $lbIP"
        Write-Host "  app.$DOMAIN          A  $lbIP"
        Write-Host "  api.$DOMAIN          A  $lbIP"
        Write-Host "  auth.$DOMAIN         A  $lbIP"
        Write-Host ""
    }
    
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Setup DNS (if not done): cd k8s && ./setup-dns.sh"
    Write-Host "  2. Wait for DNS propagation (5-15 minutes)"
    Write-Host "  3. Check certificate: kubectl get certificate -n $NAMESPACE"
    Write-Host "  4. Test deployment: https://$DOMAIN"
    Write-Host "  5. Check API health: https://api.$DOMAIN/health"
    Write-Host ""
    
    Write-Host "Monitoring:" -ForegroundColor Cyan
    Write-Host "  View pods: kubectl get pods -n $NAMESPACE"
    Write-Host "  View logs: kubectl logs -n $NAMESPACE -l app=api-backend -f"
    Write-Host "  View ingress: kubectl get ingress -n $NAMESPACE"
    Write-Host ""
} else {
    Write-Host "✓ DRY RUN COMPLETE" -ForegroundColor Green
    Write-Host ""
    Write-Host "No changes were made. Run without --DryRun to deploy." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              DEPLOYMENT COMPLETE!                         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

