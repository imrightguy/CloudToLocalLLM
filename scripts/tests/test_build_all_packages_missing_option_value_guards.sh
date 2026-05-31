#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
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
    echo "Expected build_all_packages.sh to fail for missing argument case: $*" >&2
    cat "$OUTPUT_LOG" >&2
    exit 1
  fi

  if ! grep -Fq -- "$expected" "$OUTPUT_LOG"; then
    echo "Expected error message not found: $expected" >&2
    cat "$OUTPUT_LOG" >&2
    exit 1
  fi
}

run_case "--packages requires a value (all|debian|appimage)" --packages
run_case "--increment requires a value (major|minor|patch)" --increment

echo "[test_build_all_packages_missing_option_value_guards] Passed"
