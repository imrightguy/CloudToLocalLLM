#!/bin/bash
set -e

log_warning() {
    echo -e "\033[1;33m⚠️  $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m❌ $1\033[0m"
}


echo "Deploying to environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"

# Generate full manifest
kustomize build --load-restrictor LoadRestrictionsNone k8s/apps/local/overlays/$ENVIRONMENT > full-manifest.yaml

# Update image tags (using sed as we don't have the exact SHA in the image unless passed as env var)
# We will rely on env vars passed to the job
sed -i "s|cloudtolocalllm/web:latest|$WEB_IMAGE|g" full-manifest.yaml
sed -i "s|cloudtolocalllm/api-backend:latest|$API_IMAGE|g" full-manifest.yaml
sed -i "s|cloudtolocalllm/streaming-proxy:latest|$STREAMING_IMAGE|g" full-manifest.yaml
sed -i "s|cloudtolocalllm/postgres:latest|$POSTGRES_IMAGE|g" full-manifest.yaml

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

echo "Deploying Postgres first..."
kubectl apply -f full-manifest.yaml -l app=postgres -n $NAMESPACE --validate=false

echo "Waiting for Postgres to be ready..."
kubectl rollout status statefulset/postgres -n $NAMESPACE --timeout=5m

echo "Deploying remaining services..."
kubectl apply -f full-manifest.yaml -n $NAMESPACE --validate=false

echo "Deployment complete!"
