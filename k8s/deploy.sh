#!/bin/bash
# ============================================================================
# Zoidbot - Kubernetes Deployment Script for Azure AKS
# NOTE: This script is for manual deployment. CI/CD handles automated deployment.
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# Check Prerequisites
# ============================================================================

print_header "Checking Prerequisites"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi
print_success "kubectl is installed"

# Check connection to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# ============================================================================
# Install Required Components
# ============================================================================

print_header "Installing Required Components"

# Install nginx-ingress controller
print_info "Installing nginx-ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml
print_success "nginx-ingress controller installed"

# Wait for nginx-ingress to be ready
print_info "Waiting for nginx-ingress to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
print_success "nginx-ingress is ready"

# Install cert-manager
print_info "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
print_success "cert-manager installed"

# Wait for cert-manager to be ready
print_info "Waiting for cert-manager to be ready..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s || true
print_success "cert-manager is ready"

# ============================================================================
# Configure Secrets
# ============================================================================

print_header "Configuring Secrets"

if [ ! -f "secrets.yaml" ]; then
    print_warning "secrets.yaml not found. Creating from template..."
    cp secrets.yaml.template secrets.yaml
    print_error "Please edit secrets.yaml with your actual values before continuing."
    print_info "Run: nano secrets.yaml"
    exit 1
fi

print_success "secrets.yaml found"

# ============================================================================
# Deploy Application
# ============================================================================

print_header "Deploying Zoidbot to Kubernetes"

# Apply manifests in order
print_info "Creating namespace..."
kubectl apply -f namespace.yaml

print_info "Applying secrets..."
kubectl apply -f secrets.yaml

print_info "Applying configmap..."
kubectl apply -f configmap.yaml

print_info "Deploying PostgreSQL..."
kubectl apply -f postgres-statefulset.yaml

print_info "Waiting for PostgreSQL to be ready..."
kubectl wait --namespace zoidbot \
  --for=condition=ready pod \
  --selector=app=postgres \
  --timeout=120s

print_info "Deploying API backend..."
kubectl apply -f api-backend-deployment.yaml

print_info "Deploying web application..."
kubectl apply -f web-deployment.yaml

print_info "Setting up cert-manager issuers..."
kubectl apply -f cert-manager.yaml

print_info "Configuring ingress..."
kubectl apply -f ingress-nginx.yaml

print_success "All components deployed!"

# ============================================================================
# Wait for Deployments
# ============================================================================

print_header "Waiting for Deployments to be Ready"

print_info "Waiting for API backend..."
kubectl wait --namespace zoidbot \
  --for=condition=available deployment/api-backend \
  --timeout=180s

print_info "Waiting for web application..."
kubectl wait --namespace zoidbot \
  --for=condition=available deployment/web \
  --timeout=180s

print_success "All deployments are ready!"

# ============================================================================
# Get LoadBalancer IP
# ============================================================================

print_header "Getting Load Balancer IP"

print_info "Fetching nginx-ingress load balancer IP..."
LOAD_BALANCER_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$LOAD_BALANCER_IP" ]; then
    print_warning "Load balancer IP not yet assigned. Waiting..."
    sleep 10
    LOAD_BALANCER_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

if [ -n "$LOAD_BALANCER_IP" ]; then
    print_success "Load Balancer IP: $LOAD_BALANCER_IP"
    echo ""
    print_warning "IMPORTANT: Configure your DNS A records to point to this IP:"
    echo "  yourdomain.com     -> $LOAD_BALANCER_IP"
    echo "  app.yourdomain.com -> $LOAD_BALANCER_IP"
    echo "  api.yourdomain.com -> $LOAD_BALANCER_IP"
else
    print_error "Could not retrieve load balancer IP"
fi

# ============================================================================
# Display Status
# ============================================================================

print_header "Deployment Status"

kubectl get pods -n zoidbot
echo ""
kubectl get svc -n zoidbot
echo ""
kubectl get ingress -n zoidbot

print_header "Deployment Complete!"

print_info "Useful commands:"
echo "  View logs:          kubectl logs -n zoidbot -l app=api-backend -f"
echo "  Check pods:         kubectl get pods -n zoidbot"
echo "  Check ingress:      kubectl get ingress -n zoidbot"
echo "  Describe pod:       kubectl describe pod -n zoidbot <pod-name>"
echo "  Scale deployment:   kubectl scale -n zoidbot deployment/api-backend --replicas=3"
echo ""
print_info "Once DNS is configured, your application will be available at:"
echo "  https://yourdomain.com"
echo "  https://app.yourdomain.com"
echo "  https://api.yourdomain.com"

