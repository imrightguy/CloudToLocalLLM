#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/docs/development/scripts/powershell/README.md"

if ! grep -Fq 'cd \${PROJECT_DIR:-/opt/CloudToLocalLLM} && ./scripts/deploy/update_and_deploy.sh --force --verbose' "$FILE"; then
  echo "missing project-dir-aware PowerShell deployment example" >&2
  exit 1
fi

if grep -Fq 'cd /opt/CloudToLocalLLM && ./scripts/deploy/update_and_deploy.sh --force --verbose' "$FILE"; then
  echo "found legacy hardcoded PowerShell deployment example" >&2
  exit 1
fi

echo "[test_powershell_readme_project_dir_example] Passed"
