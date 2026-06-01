#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_windows_installer.ps1"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'iscc.exe',
    'ISCC.exe',
    'CloudToLocalLLM.iss',
    'MyAppVersion',
    'MyAppSourceDir',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing installer script string: {needle}')
print('[test_build_windows_installer_wrapper] Passed')
PY
