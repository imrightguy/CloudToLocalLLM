#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_TOOLS="$WORK_DIR/bin"
TMPDIR_BASE="$WORK_DIR/trailing/tmpdir/base"
APP_PATH="$FAKE_ROOT/build/linux/x64/debug/bundle/cloudtolocalllm"
LOG_FILE="$TMPDIR_BASE/app_virtual_display.log"
PID_FILE="$TMPDIR_BASE/app_virtual_display.pid"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$(dirname "$APP_PATH")" "$FAKE_TOOLS" "$TMPDIR_BASE"

cat > "$APP_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail
sleep 60
EOF
chmod +x "$APP_PATH"

cat > "$FAKE_TOOLS/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
sleep 60
EOF
chmod +x "$FAKE_TOOLS/Xvfb"

TMPDIR="$TMPDIR_BASE////" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN=Xvfb \
XVFB_READY_DELAY=0 \
STARTUP_CHECK_DELAY=0 \
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
"$PROJECT_ROOT/scripts/archive/run_virtual.sh" >/tmp/test_run_virtual_tmpdir_trailing_slashes.log 2>&1

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Expected log file at $LOG_FILE" >&2
  cat /tmp/test_run_virtual_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if [[ ! -f "$PID_FILE" ]]; then
  echo "Expected pid file at $PID_FILE" >&2
  cat /tmp/test_run_virtual_tmpdir_trailing_slashes.log >&2
  exit 1
fi

echo "[test_run_virtual_tmpdir_trailing_slashes] Passed"
