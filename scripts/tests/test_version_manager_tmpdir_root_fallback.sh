#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/version_manager.sh"
WORK_DIR="$(mktemp -d)"
INPUT_BASE="$WORK_DIR/nested/tmp/version-manager-temp"
mkdir -p "$(dirname "$INPUT_BASE")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

temp_output="$WORK_DIR/temp.out"
output="$(TMPDIR='/' bash -c 'source "$1"; create_secure_temp_file "$2" > "$3"; temp_file="$(cat "$3")"; [[ -f "$temp_file" ]] || exit 2; cleanup_temp_files >/dev/null; [[ ! -e "$temp_file" ]] || exit 3; printf "%s\n" "$temp_file"' _ "$TARGET_SCRIPT" "$INPUT_BASE" "$temp_output")"

if [[ "$output" != /tmp/version-manager-temp.* ]]; then
  echo "Expected secure temp file to fall back to /tmp, got: $output" >&2
  exit 1
fi

echo "[test_version_manager_tmpdir_root_fallback] Passed"
