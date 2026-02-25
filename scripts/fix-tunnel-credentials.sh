#!/bin/bash
# Script to create Cloudflare tunnel credentials secret

set -e

echo "🔧 Fixing Cloudflare tunnel credentials..."

# Get tunnel token from GitHub secret (will be set as env var when run in workflow)
TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN}"

if [ -z "$TUNNEL_TOKEN" ]; then
  echo "❌ Error: CLOUDFLARE_TUNNEL_TOKEN not set"
  echo "This script should be run with CLOUDFLARE_TUNNEL_TOKEN environment variable"
  exit 1
fi

echo "✅ Retrieved tunnel token"

# Add after line 17
NAMESPACE="${NAMESPACE:-CloudToLocalLLM}"
echo "✅ Using namespace: $NAMESPACE"

# Debug: Check kubectl configuration
echo "🔍 Checking kubectl configuration..."
kubectl config view --minify
kubectl config current-context



# Create or update the tunnel-credentials secret
# verify validation is off to avoid schema download issues on some networks/configs
kubectl create secret generic tunnel-credentials \
  --from-literal=token="$TUNNEL_TOKEN" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f - --validate=false


echo "✅ Tunnel credentials secret created/updated"

echo "🔍 Applying updated tunnel configuration..."
kubectl apply -f k8s/apps/local/ingress-cloudflared/shared/overlays/managed/cloudflared-tunnel.yaml -n "$NAMESPACE" --validate=false

# Restart cloudflared deployment to pick up new credentials
kubectl rollout restart deployment/cloudflared -n "$NAMESPACE"

echo "✅ Cloudflared deployment restarted"

# Wait for rollout to complete
kubectl rollout status deployment/cloudflared -n "$NAMESPACE" --timeout=300s

echo "🎉 Tunnel credentials fixed! The web should now be accessible."