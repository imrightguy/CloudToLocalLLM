#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'if ! command -v sudo >/dev/null 2>&1; then',
    'log_error "sudo is required to prepare the development environment"',
    'sudo chown -R "$USER:$(id -gn "$USER")" "$REPO_ROOT"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing sudo hardening string: {needle}')

if 'sudo chown -R $USER:$(id -gn $USER) "$REPO_ROOT"' in script:
    raise SystemExit('setup script still uses unquoted chown ownership string')

print('[test_setup_development_environment_sudo_guard] Passed')
PY
