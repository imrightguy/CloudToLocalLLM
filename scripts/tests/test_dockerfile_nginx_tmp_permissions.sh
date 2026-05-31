#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/config/docker/Dockerfile.nginx"

if ! grep -Fq 'find /tmp/nginx -type d -exec chmod 755 {} +' "$FILE"; then
  echo "missing tmp nginx permission hardening" >&2
  exit 1
fi

if grep -Fq 'chmod -R 755 /tmp/nginx' "$FILE"; then
  echo "found legacy tmp nginx chmod -R" >&2
  exit 1
fi

echo "[test_dockerfile_nginx_tmp_permissions] Passed"
