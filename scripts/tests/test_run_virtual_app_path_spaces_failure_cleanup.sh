#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
FAKE_APP_DIR="$WORK_DIR/app dir with spaces"
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm"
LOG_FILE="$WORK_DIR/logs with spaces/virtual app.log"
PID_FILE="$WORK_DIR/state with spaces/virtual app.pid"
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
printf '%s\n' "$*" >> "$XVFB_LOG"
sleep 60
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

cat > "$APP_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "app failure with spaces on DISPLAY=$DISPLAY"
echo "app failure with spaces on DISPLAY=$DISPLAY" >> "$APP_LOG"
exit 42
EOF
chmod +x "$APP_PATH"

set +e
DISPLAY_NUM=83 \
RESOLUTION='1920x1080x24' \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_app_path_spaces_failure_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when the spaced app exits immediately" >&2
  cat /tmp/test_run_virtual_app_path_spaces_failure_cleanup.log >&2
  exit 1
fi

if ! grep -Fq 'App exited unexpectedly' /tmp/test_run_virtual_app_path_spaces_failure_cleanup.log; then
  echo "Missing startup failure message" >&2
  cat /tmp/test_run_virtual_app_path_spaces_failure_cleanup.log >&2
  exit 1
fi

if ! grep -Fq 'app failure with spaces on DISPLAY=:83' "$LOG_FILE"; then
  echo "Expected failure output in the spaced log path" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'app failure with spaces on DISPLAY=:83' "$APP_LOG"; then
  echo "Expected failure output in the app-specific log" >&2
  cat "$APP_LOG" >&2
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo "Expected PID file cleanup after failure" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

if ! grep -Fq '83 -screen 0 1920x1080x24' "$XVFB_LOG"; then
  echo "Expected Xvfb startup to be logged" >&2
  cat "$XVFB_LOG" >&2
  exit 1
fi

echo "[test_run_virtual_app_path_spaces_failure_cleanup] Passed"
