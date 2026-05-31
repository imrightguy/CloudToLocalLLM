#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
BUILD_APPIMAGE_DIR="$WORK_DIR/build-appimage-dir"
mkdir -p "$BUILD_APPIMAGE_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

set +e
BUILD_APPIMAGE_CMD="$BUILD_APPIMAGE_DIR" \
"$TARGET_SCRIPT" --skip-increment --packages appimage >/tmp/test_build_all_packages_build_appimage_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when BUILD_APPIMAGE_CMD is a directory" >&2
  cat /tmp/test_build_all_packages_build_appimage_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'AppImage build script must not be a directory' /tmp/test_build_all_packages_build_appimage_directory_guard.log; then
  echo "Missing AppImage build-script directory validation message" >&2
  cat /tmp/test_build_all_packages_build_appimage_directory_guard.log >&2
  exit 1
fi

echo "[test_build_all_packages_build_appimage_directory_guard] Passed"
