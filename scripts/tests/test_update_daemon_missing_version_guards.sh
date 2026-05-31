#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"
WORK_DIR="$(mktemp -d)"
OUTPUT_LOG="$WORK_DIR/output.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

run_case() {
  local expected="$1"
  shift

  set +e
  bash "$TARGET_SCRIPT" "$@" > "$OUTPUT_LOG" 2>&1
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    echo "Expected update daemon to fail for missing argument case: $*" >&2
    cat "$OUTPUT_LOG" >&2
    exit 1
  fi

  if ! grep -Fq -- "$expected" "$OUTPUT_LOG"; then
    echo "Expected error message not found: $expected" >&2
    cat "$OUTPUT_LOG" >&2
    exit 1
  fi
}

run_case "download requires a version" download
run_case "install requires a version" install

echo "[test_update_daemon_missing_version_guards] Passed"
