#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
FAKE_APP_DIR="$WORK_DIR/app"
LOG_FILE="/tmp/app_virtual_display.log"
PID_FILE="/tmp/app_virtual_display.pid"
XVFB_LOG="$WORK_DIR/xvfb.log"
APP_LOG="$WORK_DIR/app.log"
mkdir -p "$FAKE_XVFB_DIR" "$FAKE_APP_DIR"
export XVFB_LOG APP_LOG

cleanup() {
  if [[ -f "$PID_FILE" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" 2>/dev/null || true
    done < "$PID_FILE"
  fi
  rm -f "$LOG_FILE" "$PID_FILE"
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

rm -f "$LOG_FILE" "$PID_FILE"

cat > "$FAKE_XVFB_DIR/Xvfb" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "\$*" >> "$XVFB_LOG"
sleep 60
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

cat > "$FAKE_APP_DIR/cloudtolocalllm" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "root-fallback app started with DISPLAY=$DISPLAY"
echo "root-fallback app started with DISPLAY=$DISPLAY" >> "$APP_LOG"
sleep 60
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

TMPDIR='/' \
DISPLAY_NUM=78 \
RESOLUTION='1280x720x24' \
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Expected log file at $LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$PID_FILE" ]]; then
  echo "Expected pid file at $PID_FILE" >&2
  exit 1
fi

if [[ ! -f "$APP_LOG" ]]; then
  echo "Expected app log at $APP_LOG" >&2
  exit 1
fi

if ! grep -Fq '78 -screen 0 1280x720x24' "$XVFB_LOG"; then
  echo "Expected Xvfb to start on the requested display and resolution" >&2
  cat "$XVFB_LOG" >&2
  exit 1
fi

if ! grep -Fq 'root-fallback app started with DISPLAY=:78' "$LOG_FILE"; then
  echo "Expected app startup log with DISPLAY=:78" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'root-fallback app started with DISPLAY=:78' "$APP_LOG"; then
  echo "Expected app startup log to be mirrored in APP_LOG" >&2
  cat "$APP_LOG" >&2
  exit 1
fi

if [[ $(wc -l < "$PID_FILE") -ne 2 ]]; then
  echo "Expected pid file to contain two PIDs" >&2
  cat "$PID_FILE" >&2
  exit 1
fi

if [[ "$LOG_FILE" != /tmp/* || "$PID_FILE" != /tmp/* ]]; then
  echo "Expected default log and pid files to normalize under /tmp" >&2
  exit 1
fi

echo "[test_run_virtual_tmpdir_root_fallback] Passed"
