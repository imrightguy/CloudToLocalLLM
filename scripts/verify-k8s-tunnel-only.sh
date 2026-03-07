#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="CloudToLocalLLM"
CLOUDFLARED_NAME="cloudflared"
CONFIGMAP_NAME="cloudflared-config"
FORBIDDEN_HOST="argocd.cloudtolocalllm.online"
ADMIN_HOST="argocd-admin.cloudtolocalllm.online"
APP_HOST="app.cloudtolocalllm.online"
API_HOST="api.cloudtolocalllm.online"

log() {
  printf '[verify-k8s-tunnel-only] %s\n' "$1"
}

fail() {
  printf '[verify-k8s-tunnel-only] ERROR: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

require_cmd kubectl

log "Checking cloudflared deployment readiness"
kubectl -n "$NAMESPACE" rollout status deploy/"$CLOUDFLARED_NAME" --timeout=120s >/dev/null

log "Loading cloudflared ingress config"
CONFIG_CONTENT=$(kubectl -n "$NAMESPACE" get configmap "$CONFIGMAP_NAME" -o jsonpath='{.data.config\.yaml}')

[[ -n "$CONFIG_CONTENT" ]] || fail "cloudflared configmap data is empty"

echo "$CONFIG_CONTENT" | grep -q "$APP_HOST" || fail "missing app host route: $APP_HOST"
echo "$CONFIG_CONTENT" | grep -q "$API_HOST" || fail "missing api host route: $API_HOST"

echo "$CONFIG_CONTENT" | grep -q "$FORBIDDEN_HOST" && fail "forbidden public ArgoCD host still present: $FORBIDDEN_HOST"

if echo "$CONFIG_CONTENT" | grep -q "$ADMIN_HOST"; then
  log "Admin host appears in app tunnel config (expected in separate admin tunnel only)"
fi

log "Checking admin tunnel deployment (optional but recommended)"
if kubectl -n argocd get deploy/cloudflared-admin >/dev/null 2>&1; then
  kubectl -n argocd rollout status deploy/cloudflared-admin --timeout=120s >/dev/null
  log "Admin tunnel deployment is ready"
else
  log "Admin tunnel deployment not found in argocd namespace"
fi

log "Tunnel-only verification checks passed"
