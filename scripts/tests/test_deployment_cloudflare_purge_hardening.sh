#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing deployment workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

python3 - <<'PY' "$WORKFLOW_FILE"
from pathlib import Path
import sys

workflow = Path(sys.argv[1]).read_text()
checks = [
    'CF_TOKEN="${CLOUDFLARE_CACHE_PURGE_TOKEN:-}"',
    'CF_TOKEN="${CLOUDFLARE_DNS_API_TOKEN:-}"',
    'CF_TOKEN="${CLOUDFLARE_TUNNEL_API_TOKEN:-}"',
    'RESPONSE_FILE="$(mktemp /tmp/cloudflare-purge.XXXXXX)"',
    "trap 'rm -f \"$RESPONSE_FILE\"' RETURN",
    'curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache"',
    '-H "Authorization: Bearer $CF_TOKEN"',
    "--data '{\"purge_everything\":true}' -o \"$RESPONSE_FILE\"",
    'RESPONSE="$(cat "$RESPONSE_FILE")"',
]
for needle in checks:
    if needle not in workflow:
        raise SystemExit(f'missing Cloudflare purge hardening string: {needle}')

for forbidden in [
    '-H "Authorization: Bearer ***',
    'RESPONSE=$(curl -sS -X POST',
]:
    if forbidden in workflow:
        raise SystemExit(f'workflow still contains old Cloudflare purge pattern: {forbidden}')

print('[test_deployment_cloudflare_purge_hardening] Passed')
PY
