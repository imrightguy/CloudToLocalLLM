#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/scripts/ssl/manage_ssl.sh"

for needle in \
  'EMAIL="${EMAIL:-christopher.maltais@gmail.com}"' \
  'DOMAIN_NAME="${DOMAIN_NAME:-cloudtolocalllm.online}"' \
  'PROJECT_DIR="${PROJECT_DIR:-/opt/CloudToLocalLLM}"' \
  'sed -i '\''s|ssl_certificate /etc/nginx/ssl/default.pem;|ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;|g'\'' "$PROJECT_DIR/config/nginx/nginx-webapp-internal.conf"' \
  'sed -i '\''s|ssl_certificate_key /etc/nginx/ssl/default.key;|ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;|g'\'' "$PROJECT_DIR/config/nginx/nginx-webapp-internal.conf"'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing hardening string: $needle" >&2
    exit 1
  fi
done

echo "[test_manage_ssl_project_dir_overrides] Passed"
