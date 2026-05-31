#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-linux-runner.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'set -euo pipefail',
    'append_line_once() {',
    "append_line_once 'export PATH=\"$HOME/flutter/bin:$PATH\"' ~/.bashrc",
    'RUNNER_LABELS="linux,self-hosted,wsl"',
    'RUNNER_VERSION="2.317.0"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing expected hardening string: {needle}')

if 'if ! grep -q "flutter/bin" ~/.bashrc; then' in script:
    raise SystemExit('stale non-idempotent PATH guard still present')

print('[test_setup_wsl_linux_runner_path_dedup] Passed')
PY
