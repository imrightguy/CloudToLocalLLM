#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/scripts/ssl/check_certificates.sh"

for needle in \
  'DOMAIN="${DOMAIN:-cloudtolocalllm.online}"' \
  'CERT_PATH="${CERT_PATH:-/etc/letsencrypt/live/$DOMAIN}"' \
  'DOCKER_CMD="${DOCKER_CMD:-docker}"' \
  'compose() {' \
  'compose exec webapp test -f "$CERT_PATH/$file"' \
  'compose ps | grep -q "CloudToLocalLLM-webapp.*Up"'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing hardening string: $needle" >&2
    exit 1
  fi
done

echo "[test_check_certificates_sandboxable] Passed"
