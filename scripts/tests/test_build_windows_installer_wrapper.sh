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
    'Build-GitHubReleaseAssets.ps1',
    "'-InstallInnoSetup'",
    "'-SkipBuild'",
    "'-Force'",
    "'-Version'",
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing installer wrapper string: {needle}')
if "'-SkipInstaller'" in script:
    raise SystemExit('installer wrapper should not skip installer creation')
print('[test_build_windows_installer_wrapper] Passed')
PY
