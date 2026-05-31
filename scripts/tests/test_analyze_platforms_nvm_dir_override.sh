#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/analyze-platforms.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
required = [
    'NVM_DIR="${NVM_DIR:-$HOME/.nvm}"',
    '[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"',
]
for needle in required:
    if needle not in script:
        raise SystemExit(f'missing nvm bootstrap string: {needle}')

if '/home/rightguy/.nvm/nvm.sh' in script:
    raise SystemExit('found hardcoded nvm path in analyze-platforms.sh')

print('[test_analyze_platforms_nvm_dir_override] Passed')
PY
