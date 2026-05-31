#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/app-builds.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing app builds workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

python3 - <<'PY' "$WORKFLOW_FILE"
from pathlib import Path
import sys

workflow = Path(sys.argv[1]).read_text()
checks = [
    'PUBSPEC_TMP="$(mktemp pubspec.yaml.XXXXXX)"',
    'VERSION_JSON_TMP="$(mktemp assets/.version.json.XXXXXX)"',
    "trap 'rm -f \"$PUBSPEC_TMP\" \"$VERSION_JSON_TMP\"' RETURN",
    'sed "s/^version: .*/version: $VERSION+${{ github.run_number }}/" pubspec.yaml > "$PUBSPEC_TMP"',
    'jq ".version = \\\"$VERSION\\\" | .build_number = \\\"${{ github.run_number }}\\\"" assets/version.json > "$VERSION_JSON_TMP"',
    'mv "$PUBSPEC_TMP" pubspec.yaml',
    'mv "$VERSION_JSON_TMP" assets/version.json',
]
for needle in checks:
    if needle not in workflow:
        raise SystemExit(f'missing atomic update string: {needle}')

if 'sed -i "s/^version: .*/version: $VERSION+${{ github.run_number }}/" pubspec.yaml' in workflow:
    raise SystemExit('workflow still uses in-place sed -i version mutation')
if 'assets/version.json.tmp' in workflow:
    raise SystemExit('workflow still writes version.json via .tmp file')

print('[test_app_builds_update_version_atomic] Passed')
PY
