#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
MISSING_PUBSPEC="$WORK_DIR/pubspec.yaml"
LOG_FILE="/tmp/test_packaging_build_appimage_missing_pubspec_guard.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

set +e
PUBSPEC_FILE="$MISSING_PUBSPEC" \
BUILD_DIR="$WORK_DIR/build/linux/x64/release/bundle" \
OUTPUT_DIR="$WORK_DIR/dist/linux" \
APPIMAGE_WORKDIR="$WORK_DIR/work" \
"$TARGET_SCRIPT" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when pubspec.yaml is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "pubspec.yaml not found" "$LOG_FILE"; then
  echo "Expected pubspec missing error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$WORK_DIR/work" && -n "$(find "$WORK_DIR/work" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
  echo "Expected no AppImage work artifacts when pubspec.yaml is missing" >&2
  find "$WORK_DIR/work" -mindepth 1 -maxdepth 1 -print >&2
  exit 1
fi

echo "[test_packaging_build_appimage_missing_pubspec_guard] Passed"
