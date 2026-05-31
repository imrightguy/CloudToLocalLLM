#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'require_command_or_path() {',
    'require_command_or_path "$DPKG_DEB_CMD" "DPKG_DEB_CMD"',
    'echo "Required command not found: $value" >&2',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing dpkg-deb guard string: {needle}')

if '"$DPKG_DEB_CMD" --root-owner-group --build' not in script:
    raise SystemExit('dpkg-deb invocation missing from build script')

print('[test_build_deb_dpkg_guard] Passed')
PY
