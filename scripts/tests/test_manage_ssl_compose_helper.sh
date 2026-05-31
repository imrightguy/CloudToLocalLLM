#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/scripts/ssl/manage_ssl.sh"

for needle in \
  'DOCKER_CMD="${DOCKER_CMD:-docker}"' \
  'compose() {' \
  'PROJECT_DIR="${PROJECT_DIR:-/opt/CloudToLocalLLM}"' \
  'compose restart webapp' \
  'sed -i '\''s|ssl_certificate /etc/nginx/ssl/default.pem;|ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;|g'\'' "$PROJECT_DIR/config/nginx/nginx-webapp-internal.conf"' \
  'sed -i '\''s|ssl_certificate_key /etc/nginx/ssl/default.key;|ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;|g'\'' "$PROJECT_DIR/config/nginx/nginx-webapp-internal.conf"'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing hardening string: $needle" >&2
    exit 1
  fi
done

if grep -Fq 'docker compose restart webapp' "$FILE"; then
  echo "found legacy docker compose restart in manage_ssl.sh" >&2
  exit 1
fi

echo "[test_manage_ssl_compose_helper] Passed"
