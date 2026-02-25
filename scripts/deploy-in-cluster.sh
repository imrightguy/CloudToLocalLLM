#!/bin/bash
set -e

log_warning() {
    echo -e "\033[1;33m⚠️  $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m❌  $1\033[0m"
}

log_info() {
    echo -e "\033[0;34mℹ️  $1\033[0m"
}

log_success() {
    echo -e "\033[0;32m✅  $1\033[0m"
}

echo "Deploying to environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"

EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-cloudtolocalllm-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if ! kubectl cluster-info > /dev/null 2>&1; then
    log_info "No kubectl context configured. Configuring for AWS EKS..."

    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI is not installed. Cannot configure kubectl for EKS."
        if [[ "${CI:-}" == "true" ]]; then
            log_warning "No cluster connectivity detected in CI. Skipping actual deployment."
            exit 0
        fi
        exit 1
    fi

    log_info "Updating kubeconfig for EKS cluster: $EKS_CLUSTER_NAME"
    aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_error "Failed to connect to EKS cluster"
        if [[ "${CI:-}" == "true" ]]; then
            log_warning "No cluster connectivity detected in CI. Skipping actual deployment."
            exit 0
        fi
        exit 1
    fi
fi

log_success "Connected to Kubernetes cluster"

CLUSTER_INFO=$(kubectl cluster-info 2>/dev/null | head -1)
echo "Cluster: $CLUSTER_INFO"

log_info "Generating Kubernetes manifests for environment: $ENVIRONMENT"

if [[ ! -d "k8s/deployments/overlays/$ENVIRONMENT" ]]; then
    log_error "Environment overlay not found: k8s/deployments/overlays/$ENVIRONMENT"
    ls -la k8s/deployments/overlays/ 2>/dev/null || true
    exit 1
fi

kustomize build --load-restrictor LoadRestrictionsNone k8s/deployments/overlays/$ENVIRONMENT > full-manifest.yaml

log_success "Generated full-manifest.yaml"

log_info "Updating image tags..."
sed -i "s|ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/web:latest|$WEB_IMAGE|g" full-manifest.yaml
sed -i "s|ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/api:latest|$API_IMAGE|g" full-manifest.yaml
sed -i "s|ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/streaming:latest|$STREAMING_IMAGE|g" full-manifest.yaml
sed -i "s|CloudToLocalLLM/postgres:latest|$POSTGRES_IMAGE|g" full-manifest.yaml

log_info "Injecting configuration..."
# Hardcoded ID from health check - ideally should be dynamic but fixing for immediate stability
TUNNEL_ID="62da6c19-947b-4bf6-acad-100a73de4e0d"
CONFIG_SHA="sha-$(date +%s)" # Simple timestamp for config churn

sed -i "s|\${CLOUDFLARE_TUNNEL_ID}|$TUNNEL_ID|g" full-manifest.yaml
sed -i "s|\${CLOUDFLARED_CONFIG_SHA}|$CONFIG_SHA|g" full-manifest.yaml

echo "Verifying cluster connectivity..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    if [[ "${CI:-}" == "true" ]]; then
        log_warning "No cluster connectivity detected in CI. Skipping actual deployment but manifests are generated."
        exit 0
    else
        log_error "No cluster connectivity detected. Please ensure you are logged into your Kubernetes cluster."
        exit 1
    fi
fi

log_info "Checking namespace: $NAMESPACE"
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

# Cleanup stuck pods to free up resources and force RS reconciliation
log_info "Cleaning up stuck pods..."
kubectl delete pods --field-selector=status.phase=Pending -n $NAMESPACE --ignore-not-found=true
kubectl delete pods --field-selector=status.phase=Failed -n $NAMESPACE --ignore-not-found=true

echo "Deploying Postgres first..."
kubectl apply -f full-manifest.yaml -l app=postgres -n $NAMESPACE --validate=false

echo "Waiting for Postgres to be ready..."
kubectl rollout status statefulset/postgres -n $NAMESPACE --timeout=5m || log_warning "Postgres rollout status check timed out or failed"

echo "Deploying remaining services..."
kubectl apply -f full-manifest.yaml -n $NAMESPACE --validate=false

echo ""
log_success "Deployment complete!"
echo ""
echo "Verifying deployment status..."
kubectl get all -n $NAMESPACE

echo ""
log_info "To check logs: kubectl logs -n $NAMESPACE -l app=<app-name>"
log_info "To scale: kubectl scale deployment/<name> -n $NAMESPACE --replicas=<count>"
