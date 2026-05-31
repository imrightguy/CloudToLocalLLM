#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'app_config_tmp="$(mktemp "$PROJECT_ROOT/.tmp.app-config.XXXXXX")"',
    'sed "s/static const String appVersion =',
    'mv "$app_config_tmp" "$app_config_file"',
    'version_json_tmp="$(mktemp "$assets_dir/.version.json.XXXXXX")"',
    'cat > "$version_json_tmp" << EOFVERSION',
    'mv "$version_json_tmp" "$assets_dir/version.json"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing atomic version asset string: {needle}')

if 'sed -i "s/static const String appVersion' in script:
    raise SystemExit('app_config.dart still uses in-place sed -i mutation')
if 'cat > "$assets_dir/version.json" << EOFVERSION' in script:
    raise SystemExit('version.json still writes directly to the final file')

print('[test_build_all_packages_atomic_version_asset] Passed')
PY
