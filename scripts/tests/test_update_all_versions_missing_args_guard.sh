#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/update-all-versions.sh"
WORK_DIR="$(mktemp -d)"
OUTPUT_LOG="$WORK_DIR/output.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

set +e
bash "$TARGET_SCRIPT" > "$OUTPUT_LOG" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected update-all-versions.sh to fail when required args are missing" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

if ! grep -Fq "Usage: $TARGET_SCRIPT <new-version> <commit-sha>" "$OUTPUT_LOG"; then
  echo "Expected usage message for missing args" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

echo "[test_update_all_versions_missing_args_guard] Passed"
