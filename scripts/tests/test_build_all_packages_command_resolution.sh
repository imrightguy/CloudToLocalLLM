#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
import sys
from pathlib import Path

script = Path(sys.argv[1]).read_text()
checks = [
    'local flutter_cmd="${FLUTTER_CMD:-$PROJECT_ROOT/scripts/flutter_with_cleanup.sh}"',
    'if [[ ! -x "$flutter_cmd" ]]; then',
    'Cleanup wrapper not found or not executable at $flutter_cmd',
    'local build_appimage_cmd="${BUILD_APPIMAGE_CMD:-$SCRIPT_DIR/build_appimage.sh}"',
    'if [[ ! -x "$build_appimage_cmd" ]]; then',
    'AppImage build script not found or not executable: $build_appimage_cmd',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing expected hardening snippet: {needle}')

print('[test_build_all_packages_command_resolution] Passed')
PY
