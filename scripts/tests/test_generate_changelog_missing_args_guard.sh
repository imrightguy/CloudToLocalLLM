#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/generate-changelog.sh"
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
  echo "Expected generate-changelog.sh to fail when the version argument is missing" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

if ! grep -Fq "Usage: $TARGET_SCRIPT <new-version>" "$OUTPUT_LOG"; then
  echo "Expected usage message for missing version argument" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

echo "[test_generate_changelog_missing_args_guard] Passed"
