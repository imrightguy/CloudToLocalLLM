#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'local asset_name="cloudtolocalllm-${version}-x86_64.AppImage"',
    'local output_file="$DOWNLOAD_DIR/cloudtolocalllm-${version}.AppImage"',
    'tmp_file="$(mktemp "$TMPDIR_ROOT/cloudtolocalllm-${version}.AppImage.XXXXXX")"',
    'mv "$tmp_file" "$output_file"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing hardening string: {needle}')

for stale in [
    'CloudToLocalLLM-${version}-x86_64.AppImage',
    'curl -fL "$url" -o "$output_file"',
    'chmod +x "$output_file"',
]:
    if stale in script:
        raise SystemExit(f'stale pattern still present: {stale}')

print('[test_update_daemon_atomic_download] Passed')
PY
