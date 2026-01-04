#!/bin/bash
set -e

echo "[Ritual] Commencing the incineration of ArgoCD artifacts..."

# 1. Terminate all managed applications
echo "[Ritual] Annihilating Applications and ApplicationSets..."
kubectl delete applicationsets.argoproj.io --all -n argocd --ignore-not-found
kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found

# 2. Purge the namespace
echo "[Ritual] Purging the argocd namespace..."
kubectl delete namespace argocd --ignore-not-found

# 3. Strip cluster-wide RBAC
echo "[Ritual] Stripping cluster-wide RBAC dominion..."
kubectl delete clusterrole argocd-server argocd-application-controller --ignore-not-found
kubectl delete clusterrolebinding argocd-server argocd-application-controller --ignore-not-found

# 4. Final CRD sacrifice
echo "[Ritual] Executing final CRD sacrifice..."
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io --ignore-not-found

echo "[Ritual] ArgoCD has been purged. Long live the Overlord."
