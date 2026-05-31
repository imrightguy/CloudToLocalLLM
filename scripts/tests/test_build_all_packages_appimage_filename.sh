#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
expected = 'cloudtolocalllm-${version}-x86_64.AppImage'
if expected not in script:
    raise SystemExit(f'missing AppImage filename hardening string: {expected}')

if 'CloudToLocalLLM-${version}-x86_64.AppImage' in script:
    raise SystemExit('stale AppImage filename string still present')

print('[test_build_all_packages_appimage_filename] Passed')
PY
