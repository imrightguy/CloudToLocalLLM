#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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
    'KUBECONFIG_FILE="$(mktemp /tmp/kubeconfig.XXXXXX)"',
    'echo "$kubeconfig_base64" | base64 -d > "$KUBECONFIG_FILE"',
    'chmod 600 "$KUBECONFIG_FILE"',
    'export KUBECONFIG="$KUBECONFIG_FILE"',
    "trap 'rm -f \"$KUBECONFIG_FILE\"' RETURN",
]
for needle in checks:
    if needle not in workflow:
        raise SystemExit(f'missing kubeconfig temp-file hardening string: {needle}')

if 'echo "$kubeconfig_base64" | base64 -d > /tmp/kubeconfig' in workflow:
    raise SystemExit('workflow still writes kubeconfig to fixed /tmp/kubeconfig')
if 'export KUBECONFIG=/tmp/kubeconfig' in workflow:
    raise SystemExit('workflow still exports fixed /tmp/kubeconfig path')

print('[test_deployment_kubeconfig_tempfile] Passed')
PY
