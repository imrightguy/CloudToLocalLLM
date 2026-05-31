#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/docs/development/release/RELEASE_WORKFLOW.md"

if ! grep -Fq 'cd \${PROJECT_DIR:-/opt/CloudToLocalLLM}' "$FILE"; then
  echo "missing project-dir-aware SSH deployment example" >&2
  exit 1
fi

if grep -Fq 'cd /opt/CloudToLocalLLM && git pull origin master && flutter build web --release' "$FILE"; then
  echo "found legacy hardcoded deployment SSH example" >&2
  exit 1
fi

echo "[test_release_workflow_project_dir_example] Passed"
