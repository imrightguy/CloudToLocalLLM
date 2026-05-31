#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-runner-autostart.sh"
WORK_DIR="$(mktemp -d)"
RUNNER_DIR="$WORK_DIR/actions-runner"
BASHRC_FILE="$WORK_DIR/.bashrc"
PROFILE_FILE="$WORK_DIR/.bash_profile"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$RUNNER_DIR"
: > "$BASHRC_FILE"
: > "$PROFILE_FILE"
: > "$RUNNER_DIR/config.sh"

PATH="$PATH" HOME="$WORK_DIR" BASHRC_FILE="$BASHRC_FILE" PROFILE_FILE="$PROFILE_FILE" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_runner_autostart_dedup.log 2>&1
PATH="$PATH" HOME="$WORK_DIR" BASHRC_FILE="$BASHRC_FILE" PROFILE_FILE="$PROFILE_FILE" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_runner_autostart_dedup.log 2>&1

if [[ ! -x "$RUNNER_DIR/start-runner.sh" ]]; then
  echo "Expected runner startup script to be created and executable" >&2
  cat /tmp/test_setup_wsl_runner_autostart_dedup.log >&2
  exit 1
fi

start_line="if [ -f \"$WORK_DIR/actions-runner/start-runner.sh\" ]; then $WORK_DIR/actions-runner/start-runner.sh & fi"
if [[ $(grep -Fxc "$start_line" "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected autostart line in .bashrc exactly once" >&2
  cat "$BASHRC_FILE" >&2
  cat /tmp/test_setup_wsl_runner_autostart_dedup.log >&2
  exit 1
fi

if [[ $(grep -Fxc "$start_line" "$PROFILE_FILE") -ne 1 ]]; then
  echo "Expected autostart line in .bash_profile exactly once" >&2
  cat "$PROFILE_FILE" >&2
  cat /tmp/test_setup_wsl_runner_autostart_dedup.log >&2
  exit 1
fi

if ! grep -Fq 'nohup ./run.sh > runner.log 2>&1 &' "$RUNNER_DIR/start-runner.sh"; then
  echo "Expected generated startup script to launch the runner in the background" >&2
  cat "$RUNNER_DIR/start-runner.sh" >&2
  exit 1
fi

echo "[test_setup_wsl_runner_autostart_dedup] Passed"
