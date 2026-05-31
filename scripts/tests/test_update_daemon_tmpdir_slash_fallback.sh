#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"
WORK_DIR="$(mktemp -d)"
HOME_DIR="$WORK_DIR/home"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$HOME_DIR"

output="$(HOME="$HOME_DIR" TMPDIR="/" bash -c 'source "$1"; printf "%s\n%s\n" "$SOCKET_PATH" "$PID_FILE"' _ "$TARGET_SCRIPT")"

socket_out="$(printf '%s\n' "$output" | sed -n '1p')"
pid_out="$(printf '%s\n' "$output" | sed -n '2p')"
expected_socket="/tmp/cloudtolocalllm-updated.sock"
expected_pid="/tmp/cloudtolocalllm-updated.pid"

if [[ "$socket_out" != "$expected_socket" ]]; then
  echo "SOCKET_PATH fallback for TMPDIR=/ did not use /tmp" >&2
  printf 'got: %s\nexpected: %s\n' "$socket_out" "$expected_socket" >&2
  exit 1
fi

if [[ "$pid_out" != "$expected_pid" ]]; then
  echo "PID_FILE fallback for TMPDIR=/ did not use /tmp" >&2
  printf 'got: %s\nexpected: %s\n' "$pid_out" "$expected_pid" >&2
  exit 1
fi

echo "[test_update_daemon_tmpdir_slash_fallback] Passed"
