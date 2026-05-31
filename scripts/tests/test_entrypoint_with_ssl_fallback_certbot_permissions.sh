#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$PROJECT_ROOT/config/docker/entrypoint-with-ssl-fallback.sh"

if ! grep -Fq 'find /var/www/certbot -type d -exec chmod 755 {} +' "$SCRIPT_FILE"; then
  echo "missing certbot directory permission normalization" >&2
  exit 1
fi

if ! grep -Fq 'find /var/www/certbot -type f -exec chmod 644 {} +' "$SCRIPT_FILE"; then
  echo "missing certbot file permission normalization" >&2
  exit 1
fi

if grep -Fq 'chmod -R 755 /var/www/certbot' "$SCRIPT_FILE"; then
  echo "found legacy recursive certbot chmod" >&2
  exit 1
fi

echo "[test_entrypoint_with_ssl_fallback_certbot_permissions] Passed"
