#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
FAKE_APP_DIR="$WORK_DIR/app"
LOG_FILE="$WORK_DIR/app.log"
PID_FILE="$WORK_DIR/pids.txt"
XVFB_LOG="$WORK_DIR/xvfb.log"
APP_LOG="$WORK_DIR/app-runtime.log"
mkdir -p "$FAKE_XVFB_DIR" "$FAKE_APP_DIR"
export LOG_FILE PID_FILE XVFB_LOG APP_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_XVFB_DIR/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb starting and then exiting" >> "$XVFB_LOG"
exit 0
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

cat > "$FAKE_APP_DIR/cloudtolocalllm" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "app pid=$$ started with DISPLAY=$DISPLAY" >> "$APP_LOG"
sleep 60
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

set +e
DISPLAY_NUM=86 \
RESOLUTION='800x600x24' \
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_xvfb_exit_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when Xvfb exits immediately" >&2
  cat /tmp/test_run_virtual_xvfb_exit_guard.log >&2
  exit 1
fi

if ! grep -Fq 'Xvfb exited unexpectedly during startup' /tmp/test_run_virtual_xvfb_exit_guard.log; then
  echo "Missing Xvfb startup failure message" >&2
  cat /tmp/test_run_virtual_xvfb_exit_guard.log >&2
  exit 1
fi

if ! grep -Fq 'app pid=' "$APP_LOG"; then
  echo "Expected app to start before Xvfb failure was detected" >&2
  cat "$APP_LOG" >&2
  exit 1
fi

app_pid="$(sed -n 's/^app pid=\([0-9][0-9]*\) started with DISPLAY=:86$/\1/p' "$APP_LOG" | tail -n1)"
if [[ -z "$app_pid" ]]; then
  echo "Expected to capture the app pid from the log" >&2
  cat "$APP_LOG" >&2
  exit 1
fi

if kill -0 "$app_pid" 2>/dev/null; then
  echo "Expected app process cleanup after Xvfb failure" >&2
  ps -p "$app_pid" -f >&2 || true
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo "Expected PID file cleanup after Xvfb failure" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

echo "[test_run_virtual_xvfb_exit_guard] Passed"
