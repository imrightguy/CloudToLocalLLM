#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
TMPDIR_BASE="$WORK_DIR/trailing/tmpdir/base"
TMPDIR_ROOT="$TMPDIR_BASE////"
LOG_FILE="$WORK_DIR/kill.log"
PID_FILE="$TMPDIR_BASE/app_virtual_display.pid"
FAKE_KILL="$WORK_DIR/kill.sh"
FAKE_PKILL="$WORK_DIR/pkill.sh"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR_BASE"
printf '12345\n' > "$PID_FILE"

cat > "$FAKE_KILL" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_KILL"

cat > "$FAKE_PKILL" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "pkill $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_PKILL"

TMPDIR="$TMPDIR_ROOT" \
KILL_CMD="$FAKE_KILL" \
PKILL_CMD="$FAKE_PKILL" \
LOG_FILE="$LOG_FILE" \
"$PROJECT_ROOT/scripts/cleanup_virtual.sh" >/tmp/test_cleanup_virtual_tmpdir_trailing_slashes.log 2>&1

if ! grep -Fq -- '-9 12345' "$LOG_FILE"; then
  echo "Expected kill to target the pid from the normalized TMPDIR root" >&2
  cat /tmp/test_cleanup_virtual_tmpdir_trailing_slashes.log >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_cleanup_virtual_tmpdir_trailing_slashes] Passed"
