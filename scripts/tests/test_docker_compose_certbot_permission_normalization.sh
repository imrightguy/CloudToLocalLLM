#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/docker-compose.yml"

for needle in \
  'find /var/www/certbot -type d -exec chmod 755 {} +' \
  'find /var/www/certbot -type f -exec chmod 644 {} +' \
  'find /etc/letsencrypt -type d -exec chmod 755 {} +' \
  'find /etc/letsencrypt -type f -exec chmod 644 {} +'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing hardening string: $needle" >&2
    exit 1
  fi
done

if grep -Fq 'chmod -R 755 /var/www/certbot' "$FILE"; then
  echo "found legacy certbot chmod -R /var/www/certbot" >&2
  exit 1
fi

if grep -Fq 'chmod -R 755 /etc/letsencrypt' "$FILE"; then
  echo "found legacy certbot chmod -R /etc/letsencrypt" >&2
  exit 1
fi

echo "[test_docker_compose_certbot_permission_normalization] Passed"
