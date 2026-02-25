#!/bin/bash
set -e

# Load helper functions
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

NAMESPACE="${NAMESPACE:-CloudToLocalLLM}"

log_info "Initiating HARD RESET of namespace: $NAMESPACE"

# Check if namespace exists
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    log_warning "Deleting namespace $NAMESPACE and all its resources..."
    # Force delete the namespace to ensure everything is wiped
    kubectl delete namespace "$NAMESPACE" --timeout=120s || log_warning "Namespace deletion timed out or failed, continuing..."
    
    # Wait loop to ensure it's gone (or mostly gone)
    log_info "Waiting for namespace termination..."
    for i in {1..30}; do
        if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
            log_success "Namespace deleted successfully."
            break
        fi
        echo -n "."
        sleep 2
    done
else
    log_info "Namespace $NAMESPACE does not exist. proceeding..."
fi

log_info "Cleaning up Cluster-wide resources (PVs)..."
# Delete all PVs associated with the namespace (if any remain)
# This assumes PVs are created with a specific claim ref or label, which might not be reliable.
# Safer to just delete all non-bound PVs or specific ones if we knew names.
# For now, we'll rely on the StorageClass reclaiming them or manual cleanup if needed.

# Force delete any stuck pods in the namespace if it still exists (zombies)
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    log_warning "Namespace stuck terminating. Force deleting resources..."
    kubectl delete all --all -n "$NAMESPACE" --force --grace-period=0
fi

log_info "Recreating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE"

log_success "Cluster reset complete. Ready for fresh deployment."
