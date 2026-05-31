#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing deployment workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

python3 - <<'PY' "$WORKFLOW_FILE"
from pathlib import Path
import sys

workflow = Path(sys.argv[1]).read_text()
checks = [
    'AUR_REPO_DIR=""',
    'cleanup_aur_publication() {',
    'ssh-agent -k >/dev/null 2>&1 || true',
    'rm -rf "$SSH_WORK_DIR" "$AUR_REPO_DIR"',
    'trap cleanup_aur_publication EXIT',
    'AUR_REPO_DIR="$(mktemp -d /tmp/aur-repo.XXXXXX)"',
]
for needle in checks:
    if needle not in workflow:
        raise SystemExit(f'missing AUR cleanup hardening string: {needle}')

for forbidden in [
    "trap 'rm -rf \"$SSH_WORK_DIR\"' EXIT",
    "trap 'rm -rf \"$AUR_REPO_DIR\"' EXIT",
]:
    if forbidden in workflow:
        raise SystemExit(f'workflow still contains old AUR trap pattern: {forbidden}')

print('[test_deployment_aur_cleanup_consolidated] Passed')
PY
