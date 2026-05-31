#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'elif command -v wget >/dev/null 2>&1; then',
    'if ! wget -q "$APPIMAGETOOL_DOWNLOAD_URL" -O "$download_tmp"; then',
    'log_error "curl or wget is required to download appimagetool"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing wget fallback string: {needle}')

if 'if ! curl -fsSL "$APPIMAGETOOL_DOWNLOAD_URL" -o "$download_tmp"; then' not in script:
    raise SystemExit('curl download branch missing')

print('[test_build_appimage_wget_fallback] Passed')
PY
