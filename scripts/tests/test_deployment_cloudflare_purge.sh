#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing deployment workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

if ! grep -Fq 'CF_TOKEN="${CLOUDFLARE_CACHE_PURGE_TOKEN:-}"' "$WORKFLOW_FILE"; then
  echo "Deployment workflow does not define CF_TOKEN from the Cloudflare cache purge token" >&2
  exit 1
fi

if ! grep -Fq -- '-H "Authorization: Bearer $CF_TOKEN"' "$WORKFLOW_FILE"; then
  echo "Deployment workflow does not use CF_TOKEN for Cloudflare purge auth" >&2
  exit 1
fi

if ! grep -Fq 'python3 -c' "$WORKFLOW_FILE"; then
  echo "Deployment workflow does not use python3 for Cloudflare purge result parsing" >&2
  exit 1
fi

echo "[test_deployment_cloudflare_purge] Passed"
