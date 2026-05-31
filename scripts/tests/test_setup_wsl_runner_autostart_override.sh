#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-runner-autostart.sh"
WORK_DIR="$(mktemp -d)"
RUNNER_DIR="$WORK_DIR/actions-runner"
BASHRC_FILE="$WORK_DIR/config/shell/custom.bashrc"
PROFILE_FILE="$WORK_DIR/config/shell/custom.profile"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$RUNNER_DIR" "$WORK_DIR/config/shell"
: > "$RUNNER_DIR/config.sh"

PATH="$PATH" HOME="$WORK_DIR" RUNNER_DIR="$RUNNER_DIR" BASHRC_FILE="$BASHRC_FILE" PROFILE_FILE="$PROFILE_FILE" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_runner_autostart_override.log 2>&1

if [[ ! -x "$RUNNER_DIR/start-runner.sh" ]]; then
  echo "Expected runner startup script to be created and executable" >&2
  cat /tmp/test_setup_wsl_runner_autostart_override.log >&2
  exit 1
fi

start_line="if [ -f \"$RUNNER_DIR/start-runner.sh\" ]; then $RUNNER_DIR/start-runner.sh & fi"
if ! grep -Fq "RUNNER_DIR=\"$RUNNER_DIR\"" "$RUNNER_DIR/start-runner.sh"; then
  echo "Expected generated start script to embed the overridden runner directory" >&2
  cat "$RUNNER_DIR/start-runner.sh" >&2
  cat /tmp/test_setup_wsl_runner_autostart_override.log >&2
  exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom bashrc override to be created" >&2
  exit 1
fi

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Expected custom profile override to be created" >&2
  exit 1
fi

if [[ $(grep -Fxc "$start_line" "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected autostart line in custom bashrc exactly once" >&2
  cat "$BASHRC_FILE" >&2
  cat /tmp/test_setup_wsl_runner_autostart_override.log >&2
  exit 1
fi

if [[ $(grep -Fxc "$start_line" "$PROFILE_FILE") -ne 1 ]]; then
  echo "Expected autostart line in custom profile exactly once" >&2
  cat "$PROFILE_FILE" >&2
  cat /tmp/test_setup_wsl_runner_autostart_override.log >&2
  exit 1
fi

echo "[test_setup_wsl_runner_autostart_override] Passed"
