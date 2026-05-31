#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/docs/development/deployment-script-development.md"

for needle in \
  'cd \${PROJECT_DIR:-/opt/CloudToLocalLLM} && ./scripts/deploy/complete_deployment.sh --force' \
  'cd $($Script:DeploymentConfig.VPSProjectPath) && bash scripts/deploy/complete_deployment.sh'; do
  if ! grep -Fq "$needle" "$FILE"; then
    echo "missing project-dir-aware deployment example: $needle" >&2
    exit 1
  fi
done

if grep -Fq 'cd /opt/CloudToLocalLLM && ./scripts/deploy/complete_deployment.sh --force' "$FILE"; then
  echo "found legacy hardcoded VPS deployment example (PowerShell comment)" >&2
  exit 1
fi

if grep -Fq "cd /opt/CloudToLocalLLM && bash scripts/deploy/complete_deployment.sh" "$FILE"; then
  echo "found legacy hardcoded VPS deployment example (PowerShell)" >&2
  exit 1
fi

echo "[test_deployment_script_development_project_dir_examples] Passed"
