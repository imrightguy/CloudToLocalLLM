#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/xvfb dir with spaces"
FAKE_APP_DIR="$WORK_DIR/app"
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm"
LOG_FILE="$WORK_DIR/logs/run.log"
PID_FILE="$WORK_DIR/state/run.pid"
XVFB_LOG="$WORK_DIR/xvfb.log"
APP_LOG="$WORK_DIR/app.log"
mkdir -p "$FAKE_XVFB_DIR" "$FAKE_APP_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"
export XVFB_LOG APP_LOG

cleanup() {
  if [[ -f "$PID_FILE" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" 2>/dev/null || true
    done < "$PID_FILE"
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_XVFB_DIR/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb path with spaces started: $*" >> "$XVFB_LOG"
sleep 60
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

cat > "$APP_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "app with xvfb-spaces started with DISPLAY=$DISPLAY"
echo "app with xvfb-spaces started with DISPLAY=$DISPLAY" >> "$APP_LOG"
sleep 60
EOF
chmod +x "$APP_PATH"

DISPLAY_NUM=88 \
RESOLUTION='1280x720x24' \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
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

if ! grep -Fq 'xvfb path with spaces started: :88 -screen 0 1280x720x24' "$XVFB_LOG"; then
  echo "Expected Xvfb command path with spaces to be invoked" >&2
  cat "$XVFB_LOG" >&2
  exit 1
fi

if ! grep -Fq 'app with xvfb-spaces started with DISPLAY=:88' "$LOG_FILE"; then
  echo "Expected app output in the redirected log" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'app with xvfb-spaces started with DISPLAY=:88' "$APP_LOG"; then
  echo "Expected app output in the app-specific log" >&2
  cat "$APP_LOG" >&2
  exit 1
fi

if [[ $(wc -l < "$PID_FILE") -ne 2 ]]; then
  echo "Expected pid file to contain two PIDs" >&2
  cat "$PID_FILE" >&2
  exit 1
fi

echo "[test_run_virtual_xvfb_path_spaces] Passed"
