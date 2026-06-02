#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/installer-template.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'set -euo pipefail',
    'cleanup_download_tmp() {',
    'trap cleanup_download_tmp EXIT',
    'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then',
    'main "$@"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing hardening string: {needle}')

if 'set -e\n' in script:
    raise SystemExit('installer template still uses set -e without pipefail')
if 'main "$@"\n' in script and 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then' not in script:
    raise SystemExit('main remains unguarded when sourced')

print('[test_installer_template_hardening] Passed')
PY
