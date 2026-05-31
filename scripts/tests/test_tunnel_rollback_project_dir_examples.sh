#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/docs/deployment/TUNNEL_ROLLBACK_PROCEDURES.md"

for needle in \
  'cd \${PROJECT_DIR:-/opt/CloudToLocalLLM}' \
  'docker-compose down api-backend' \
  'docker-compose build api-backend' \
  'sudo systemctl stop cloudtolocalllm-api'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing rollback guidance string: $needle" >&2
    exit 1
  fi
done

if grep -Fq 'cd /opt/CloudToLocalLLM' "$FILE"; then
  echo "found legacy hardcoded project directory in tunnel rollback procedures" >&2
  exit 1
fi

echo "[test_tunnel_rollback_project_dir_examples] Passed"
