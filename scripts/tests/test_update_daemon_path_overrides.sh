#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"
WORK_DIR="$(mktemp -d)"
STATE_DIR="$WORK_DIR/nested/state/cloudtolocalllm"
SOCKET_PATH="$WORK_DIR/nested/runtime/cloudtolocalllm.sock"
PID_FILE="$WORK_DIR/nested/runtime/cloudtolocalllm.pid"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Source the script in a subshell so we can inspect the configured paths
output="$(STATE_DIR_OVERRIDE="$STATE_DIR" SOCKET_PATH_OVERRIDE="$SOCKET_PATH" PID_FILE_OVERRIDE="$PID_FILE" bash -c 'source "$1"; printf "%s\n%s\n%s\n" "$STATE_DIR" "$SOCKET_PATH" "$PID_FILE"' _ "$TARGET_SCRIPT")"

state_out="$(printf '%s\n' "$output" | sed -n '1p')"
socket_out="$(printf '%s\n' "$output" | sed -n '2p')"
pid_out="$(printf '%s\n' "$output" | sed -n '3p')"

if [[ "$state_out" != "$STATE_DIR" ]]; then
  echo "STATE_DIR override was not applied" >&2
  printf 'got: %s\nexpected: %s\n' "$state_out" "$STATE_DIR" >&2
  exit 1
fi

if [[ "$socket_out" != "$SOCKET_PATH" ]]; then
  echo "SOCKET_PATH override was not applied" >&2
  printf 'got: %s\nexpected: %s\n' "$socket_out" "$SOCKET_PATH" >&2
  exit 1
fi

if [[ "$pid_out" != "$PID_FILE" ]]; then
  echo "PID_FILE override was not applied" >&2
  printf 'got: %s\nexpected: %s\n' "$pid_out" "$PID_FILE" >&2
  exit 1
fi

if [[ ! -d "$STATE_DIR" ]]; then
  echo "Expected nested STATE_DIR to be created" >&2
  exit 1
fi

if [[ ! -d "$(dirname "$SOCKET_PATH")" ]]; then
  echo "Expected nested SOCKET_PATH directory to be created" >&2
  exit 1
fi

if [[ ! -d "$(dirname "$PID_FILE")" ]]; then
  echo "Expected nested PID_FILE directory to be created" >&2
  exit 1
fi

echo "[test_update_daemon_path_overrides] Passed"
