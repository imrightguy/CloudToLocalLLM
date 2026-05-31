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
    'SIMON_VPS_SSH_PRIVATE_KEY: ${{ secrets.SIMON_VPS_SSH_PRIVATE_KEY }}',
    'VM_SSH_PRIVATE_KEY: ${{ secrets.VM_SSH_PRIVATE_KEY }}',
    'SIMON_HOST: ${{ secrets.SIMON_HOST }}',
    'SSH_KEY="${SIMON_VPS_SSH_PRIVATE_KEY:-${VM_SSH_PRIVATE_KEY:-}}"',
    'install -d -m 700 ~/.ssh',
    'printf \'%s\\n\' "$SSH_KEY" > ~/.ssh/simon_vps_key',
    'chmod 600 ~/.ssh/simon_vps_key',
]
for needle in checks:
    if needle not in workflow:
        raise SystemExit(f'missing deploy SSH workspace hardening string: {needle}')

for forbidden in [
    'SWARM_SSH_KEY',
    'SWARM_HOST',
    'KUBECONFIG_BASE64',
    'K8S_HOST',
    'K8S_USER',
]:
    if forbidden in workflow:
        raise SystemExit(f'workflow still contains old deploy SSH pattern: {forbidden}')

print('[test_deployment_ssh_workspace] Passed')
PY
