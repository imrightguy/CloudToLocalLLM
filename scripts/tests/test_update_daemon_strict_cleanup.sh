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
    'set -euo pipefail',
    'TMPDIR_ROOT="$(normalize_tmpdir_root "$TMPDIR")"',
    'STATE_DIR="${STATE_DIR_OVERRIDE:-$HOME/.config/cloudtolocalllm}"',
    'SOCKET_PATH="${SOCKET_PATH_OVERRIDE:-$TMPDIR_ROOT/cloudtolocalllm-updated.sock}"',
    'PID_FILE="${PID_FILE_OVERRIDE:-$TMPDIR_ROOT/cloudtolocalllm-updated.pid}"',
    'mkdir -p "$STATE_DIR" "$(dirname "$SOCKET_PATH")" "$(dirname "$PID_FILE")" "$TMPDIR_ROOT"',
    'response_file="$(mktemp "$TMPDIR_ROOT/cloudtolocalllm-updated-response.XXXXXX")"',
    'rm -f "$response_file"',
    'tmp_file="$(mktemp "$TMPDIR_ROOT/cloudtolocalllm-${version}.AppImage.XXXXXX")"',
    'rm -f "$tmp_file"',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing update-daemon hardening string: {needle}')

print('[test_update_daemon_strict_cleanup] Passed')
PY
