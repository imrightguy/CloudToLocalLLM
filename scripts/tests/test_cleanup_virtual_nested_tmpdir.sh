#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/cleanup_virtual.sh"
WORK_DIR="$(mktemp -d)"
TMPDIR_BASE="$WORK_DIR/nested"
TMPDIR_ROOT="$TMPDIR_BASE/tmp/dir"
PID_FILE="$TMPDIR_ROOT/app_virtual_display.pid"
KILL_LOG="$WORK_DIR/kill.log"
PKILL_LOG="$WORK_DIR/pkill.log"
FAKE_BIN="$WORK_DIR/bin"
mkdir -p "$FAKE_BIN" "$TMPDIR_ROOT"
export KILL_LOG PKILL_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/paperclip-kill" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$KILL_LOG"
EOF
chmod +x "$FAKE_BIN/paperclip-kill"

cat > "$FAKE_BIN/paperclip-pkill" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$PKILL_LOG"
EOF
chmod +x "$FAKE_BIN/paperclip-pkill"

cat > "$PID_FILE" <<'EOF'
1111
2222
EOF

TMPDIR="$TMPDIR_ROOT" KILL_CMD=paperclip-kill PKILL_CMD=paperclip-pkill PATH="$FAKE_BIN:$PATH" "$TARGET_SCRIPT" >/tmp/test_cleanup_virtual_nested_tmpdir.log 2>&1

if [[ -e "$PID_FILE" ]]; then
  echo "Expected PID file cleanup after stopping virtual display" >&2
  cat /tmp/test_cleanup_virtual_nested_tmpdir.log >&2
  exit 1
fi

if [[ $(grep -Fc -- '-9 1111' "$KILL_LOG") -ne 1 ]]; then
  echo "Expected exactly one kill for pid 1111" >&2
  cat "$KILL_LOG" >&2
  exit 1
fi

if [[ $(grep -Fc -- '-9 2222' "$KILL_LOG") -ne 1 ]]; then
  echo "Expected exactly one kill for pid 2222" >&2
  cat "$KILL_LOG" >&2
  exit 1
fi

if [[ -e "$PKILL_LOG" ]]; then
  echo "pkill should not run when a PID file exists" >&2
  cat "$PKILL_LOG" >&2
  exit 1
fi

echo "[test_cleanup_virtual_nested_tmpdir] Passed"
