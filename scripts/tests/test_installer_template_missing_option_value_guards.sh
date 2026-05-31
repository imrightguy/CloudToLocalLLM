#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/installer-template.sh"
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
    echo "Expected installer-template.sh to fail for missing argument case: $*" >&2
    cat "$OUTPUT_LOG" >&2
    exit 1
  fi

  if ! grep -Fq -- "$expected" "$OUTPUT_LOG"; then
    echo "Expected error message not found: $expected" >&2
    cat "$OUTPUT_LOG" >&2
    exit 1
  fi
}

run_case "--channel requires a value (stable|beta|edge)" --channel
run_case "--dir requires a path value" --dir

echo "[test_installer_template_missing_option_value_guards] Passed"
