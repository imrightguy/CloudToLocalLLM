#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORK_DIR="$(mktemp -d)"
BASHRC_DIR="$WORK_DIR/bashrc-dir"
mkdir -p "$BASHRC_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

set +e
BASHRC_FILE="$BASHRC_DIR" \
"$TARGET_SCRIPT" >/tmp/test_setup_development_environment_bashrc_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected setup-development-environment.sh to fail when BASHRC_FILE is a directory" >&2
  cat /tmp/test_setup_development_environment_bashrc_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'BASHRC_FILE must not be a directory' /tmp/test_setup_development_environment_bashrc_directory_guard.log; then
  echo "Missing BASHRC_FILE directory validation message" >&2
  cat /tmp/test_setup_development_environment_bashrc_directory_guard.log >&2
  exit 1
fi

echo "[test_setup_development_environment_bashrc_directory_guard] Passed"
