#!/bin/bash
# purge-argocd.sh - Comprehensive decommissioning script for legacy ArgoCD infrastructure

set -e

echo "Starting ArgoCD decommissioning process..."

# 1. Terminate Application management to prevent finalizer hangs
echo "Deleting Applications and ApplicationSets..."
kubectl delete applicationsets.argoproj.io --all -n argocd --timeout=60s || echo "No ApplicationSets found."
kubectl delete applications.argoproj.io --all -n argocd --timeout=60s || echo "No Applications found."

# 2. Patch any remaining stuck Applications (remove finalizers)
STUCK_APPS=$(kubectl get applications.argoproj.io -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
for app in $STUCK_APPS; do
    echo "Patching stuck application: $app"
    kubectl patch application.argoproj.io "$app" -n argocd --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
done

# 3. Delete the ArgoCD Namespace and all namespaced resources
echo "Deleting ArgoCD namespace..."
kubectl delete namespace argocd --timeout=120s || echo "Namespace argocd already removed."

# 4. Cleanup Cluster-wide RBAC
echo "Cleaning up Cluster RBAC..."
kubectl delete clusterrole argocd-server argocd-application-controller argocd-repo-server argocd-server-metrics 2>/dev/null || true
kubectl delete clusterrolebinding argocd-server argocd-application-controller argocd-repo-server 2>/dev/null || true

# 5. Purge Custom Resource Definitions (CRDs)
echo "Purging Custom Resource Definitions..."
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io 2>/dev/null || true

# 6. Audit check
echo "Conducting environment audit..."
REMAINING_ARGO=$(kubectl get all,configmaps,secrets,clusterroles,clusterrolebindings -A -l "app.kubernetes.io/part-of=argocd" -o name)

if [ -z "$REMAINING_ARGO" ]; then
    echo "SUCCESS: Legacy ArgoCD infrastructure completely purged."
else
    echo "WARNING: The following legacy artifacts remain:"
    echo "$REMAINING_ARGO"
fi
