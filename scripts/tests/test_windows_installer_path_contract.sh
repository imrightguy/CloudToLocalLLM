#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_SCRIPT="$PROJECT_ROOT/windows/installer/CloudToLocalLLM.iss"
LEGACY_SCRIPT="$PROJECT_ROOT/build-tools/installers/windows/Basic.iss"

for file in "$CANONICAL_SCRIPT" "$LEGACY_SCRIPT"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing expected installer contract file: $file" >&2
    exit 1
  fi
done

python3 - <<'PY' "$CANONICAL_SCRIPT" "$LEGACY_SCRIPT"
from pathlib import Path
import sys

canonical = Path(sys.argv[1]).read_text()
legacy = Path(sys.argv[2]).read_text()

required_canonical = [
    'MyOutputDir',
    'OutputBaseFilename=CloudToLocalLLM-Windows-x64-Setup',
    'MyAppSourceDir',
    'Source:',
    'DestDir: "{app}"',
]
for needle in required_canonical:
    if needle not in canonical:
        raise SystemExit(f'missing canonical installer string: {needle}')

if 'CloudToLocalLLM.iss' not in legacy and 'include' not in legacy:
    raise SystemExit('legacy installer wrapper does not reference canonical installer script')

print('[test_windows_installer_path_contract] Passed')
PY
