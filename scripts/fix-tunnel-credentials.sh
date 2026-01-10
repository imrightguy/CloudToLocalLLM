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

# Create or update the tunnel-credentials secret
kubectl create secret generic tunnel-credentials \
  --from-literal=token="$TUNNEL_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Tunnel credentials secret created/updated"

# Restart cloudflared deployment to pick up new credentials
kubectl rollout restart deployment/cloudflared -n cloudtolocalllm

echo "✅ Cloudflared deployment restarted"

# Wait for rollout to complete
kubectl rollout status deployment/cloudflared -n cloudtolocalllm --timeout=300s

echo "🎉 Tunnel credentials fixed! The web should now be accessible."