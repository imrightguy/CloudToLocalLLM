#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_SCRIPT="$PROJECT_ROOT/windows/installer/CloudToLocalLLM.iss"
LEGACY_SCRIPT="$PROJECT_ROOT/build-tools/installers/windows/Basic.iss"
BUILDER_SCRIPT="$PROJECT_ROOT/scripts/powershell/Build-GitHubReleaseAssets.ps1"

for file in "$CANONICAL_SCRIPT" "$LEGACY_SCRIPT" "$BUILDER_SCRIPT"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing expected installer contract file: $file" >&2
    exit 1
  fi
done

python3 - <<'PY' "$CANONICAL_SCRIPT" "$LEGACY_SCRIPT" "$BUILDER_SCRIPT"
from pathlib import Path
import sys

canonical = Path(sys.argv[1]).read_text()
legacy = Path(sys.argv[2]).read_text()
builder = Path(sys.argv[3]).read_text()

required_canonical = [
    'OutputDir=..\\..\\dist\\windows',
    'OutputBaseFilename=CloudToLocalLLM-Windows-{#MyAppVersion}-Setup',
    'Source: "..\\..\\build\\windows\\x64\\runner\\Release\\*"',
]
for needle in required_canonical:
    if needle not in canonical:
        raise SystemExit(f'missing canonical installer string: {needle}')

if '#include "..\\..\\..\\windows\\installer\\CloudToLocalLLM.iss"' not in legacy:
    raise SystemExit('legacy installer wrapper does not include canonical installer script')

required_builder = [
    'windows\\installer\\CloudToLocalLLM.iss',
    'build-tools\\installers\\windows\\Basic.iss',
]
for needle in required_builder:
    if needle not in builder:
        raise SystemExit(f'missing installer builder path string: {needle}')

prefer_new = builder.find('windows\\installer\\CloudToLocalLLM.iss')
prefer_old = builder.find('build-tools\\installers\\windows\\Basic.iss')
if prefer_new == -1 or prefer_old == -1 or prefer_new > prefer_old:
    raise SystemExit('installer builder does not prefer the canonical script path')

print('[test_windows_installer_path_contract] Passed')
PY
