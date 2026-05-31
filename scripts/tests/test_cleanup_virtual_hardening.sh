#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/cleanup_virtual.sh"
WORK_DIR="$(mktemp -d)"
PID_FILE="$WORK_DIR/app_virtual_display.pid"
KILL_LOG="$WORK_DIR/kill.log"
PKILL_LOG="$WORK_DIR/pkill.log"
FAKE_BIN="$WORK_DIR/bin"
mkdir -p "$FAKE_BIN"
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

PID_FILE="$PID_FILE" KILL_CMD=paperclip-kill PKILL_CMD=paperclip-pkill PATH="$FAKE_BIN:$PATH" "$TARGET_SCRIPT" >/tmp/test_cleanup_virtual_existing.log 2>&1

if [[ -e "$PID_FILE" ]]; then
  echo "Expected PID file cleanup after stopping virtual display" >&2
  cat /tmp/test_cleanup_virtual_existing.log >&2
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

: > "$KILL_LOG"
: > "$PKILL_LOG"
rm -f "$PID_FILE"

set +e
PID_FILE="$PID_FILE" KILL_CMD=paperclip-kill PKILL_CMD=paperclip-pkill PATH="$FAKE_BIN:$PATH" "$TARGET_SCRIPT" >/tmp/test_cleanup_virtual_missing.log 2>&1
missing_status=$?
set -e

if [[ $missing_status -ne 0 ]]; then
  echo "cleanup_virtual.sh should not fail when the PID file is missing" >&2
  cat /tmp/test_cleanup_virtual_missing.log >&2
  exit 1
fi

if ! grep -Fq 'No PID file found. Cleanup manually if needed.' /tmp/test_cleanup_virtual_missing.log; then
  echo "Missing missing-file status message" >&2
  cat /tmp/test_cleanup_virtual_missing.log >&2
  exit 1
fi

if [[ $(grep -Fc -- '-9 -f cloudtolocalllm' "$PKILL_LOG") -ne 1 ]]; then
  echo "Expected one pkill -f cloudtolocalllm call" >&2
  cat "$PKILL_LOG" >&2
  exit 1
fi

if [[ $(grep -Fc -- '-9 Xvfb' "$PKILL_LOG") -ne 1 ]]; then
  echo "Expected one pkill Xvfb call" >&2
  cat "$PKILL_LOG" >&2
  exit 1
fi

: > "$KILL_LOG"
: > "$PKILL_LOG"
cat > "$PID_FILE" <<'EOF'
1234
invalid-pid
  
4321
EOF

PID_FILE="$PID_FILE" KILL_CMD=paperclip-kill PKILL_CMD=paperclip-pkill PATH="$FAKE_BIN:$PATH" "$TARGET_SCRIPT" >/tmp/test_cleanup_virtual_invalid.log 2>&1

if [[ -e "$PID_FILE" ]]; then
  echo "Expected PID file cleanup after invalid-entry run" >&2
  cat /tmp/test_cleanup_virtual_invalid.log >&2
  exit 1
fi

if ! grep -Fq 'Skipping invalid PID entry: invalid-pid' /tmp/test_cleanup_virtual_invalid.log; then
  echo "Expected invalid PID skip message" >&2
  cat /tmp/test_cleanup_virtual_invalid.log >&2
  exit 1
fi

if [[ $(grep -Fc -- '-9 1234' "$KILL_LOG") -ne 1 ]]; then
  echo "Expected exactly one kill for pid 1234" >&2
  cat "$KILL_LOG" >&2
  exit 1
fi

if [[ $(grep -Fc -- '-9 4321' "$KILL_LOG") -ne 1 ]]; then
  echo "Expected exactly one kill for pid 4321" >&2
  cat "$KILL_LOG" >&2
  exit 1
fi

if grep -Fq 'invalid-pid' "$KILL_LOG"; then
  echo "Invalid PID should not be passed to kill" >&2
  cat "$KILL_LOG" >&2
  exit 1
fi

echo "[test_cleanup_virtual_hardening] Passed"
