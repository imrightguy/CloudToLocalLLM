#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/scripts/ssl/setup_letsencrypt.sh"

for needle in \
  'PROJECT_DIR="${PROJECT_DIR:-/opt/CloudToLocalLLM}"' \
  'WEBROOT_ROOT="${CERTBOT_WEBROOT_ROOT:-$PROJECT_DIR/certbot/www}"' \
  'PROJECT_DIR="${PROJECT_DIR:-/opt/CloudToLocalLLM}"' \
  'cd "$PROJECT_DIR"' \
  'DOCKER_CMD="${DOCKER_CMD:-docker}"' \
  'compose() {'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing hardening string: $needle" >&2
    exit 1
  fi
done

if grep -Fq 'cd /opt/CloudToLocalLLM' "$FILE"; then
  echo "found legacy hardcoded project directory in renewal script" >&2
  exit 1
fi

echo "[test_setup_letsencrypt_project_dir_override] Passed"
