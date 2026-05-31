#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
VERSION_MANAGER_DIR="$WORK_DIR/version-manager-dir"
mkdir -p "$VERSION_MANAGER_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

set +e
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER_DIR" \
PROJECT_ROOT_OVERRIDE="$PROJECT_ROOT" \
SCRIPT_DIR_OVERRIDE="$PROJECT_ROOT/scripts/packaging" \
TMPDIR="$WORK_DIR/tmp" \
"$TARGET_SCRIPT" --skip-increment --packages appimage >/tmp/test_build_all_packages_version_manager_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when VERSION_MANAGER_SCRIPT is a directory" >&2
  cat /tmp/test_build_all_packages_version_manager_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'Version manager script must not be a directory' /tmp/test_build_all_packages_version_manager_directory_guard.log; then
  echo "Missing version manager directory validation message" >&2
  cat /tmp/test_build_all_packages_version_manager_directory_guard.log >&2
  exit 1
fi

echo "[test_build_all_packages_version_manager_directory_guard] Passed"
