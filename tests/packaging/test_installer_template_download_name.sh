#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/installer-template.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    'local appimage_name="cloudtolocalllm-${version}-x86_64.AppImage"',
    'local downloaded_appimage="${output_dir}/${appimage_name}"',
    'download_tmp="$(mktemp "$TMPDIR_ROOT/.cloudtolocalllm-download.XXXXXX")"',
    'if ! curl -L -o "$download_tmp" "$download_url" >&2; then',
    'mv "$download_tmp" "$downloaded_appimage"',
    'Exec=${install_dir}/cloudtolocalllm %u',
    'cp "$downloaded_appimage" "$INSTALL_DIR/cloudtolocalllm"',
    'echo "Location: $INSTALL_DIR/cloudtolocalllm"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing hardening string: {needle}')

if 'CloudToLocalLLM-${version}-x86_64.AppImage' in script:
    raise SystemExit('stale AppImage download name still present')
if 'curl -L -o "${output_dir}/${appimage_name}"' in script:
    raise SystemExit('installer still downloads directly to the final AppImage path')
if 'Exec=${install_dir}/CloudToLocalLLM %u' in script:
    raise SystemExit('stale desktop launcher path still present')
if 'cp "$downloaded_appimage" "$INSTALL_DIR/CloudToLocalLLM"' in script:
    raise SystemExit('stale installed launcher name still present')

print('[test_installer_template_download_name] Passed')
PY
