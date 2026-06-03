#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
FAKE_APP_DIR="$WORK_DIR/app"
LOG_FILE="$WORK_DIR/app.log"
PID_FILE="$WORK_DIR/pids.txt"
XVFB_LOG="$WORK_DIR/xvfb.log"
APP_LOG="$WORK_DIR/app-runtime.log"
mkdir -p "$FAKE_BIN" "$FAKE_APP_DIR"
export LOG_FILE PID_FILE XVFB_LOG APP_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb $*" >> "$XVFB_LOG"
sleep 60
EOF
chmod +x "$FAKE_BIN/Xvfb"

cat > "$FAKE_APP_DIR/cloudtolocalllm" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "app started with DISPLAY=$DISPLAY" >> "$APP_LOG"
sleep 60
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

DISPLAY_NUM=79 \
RESOLUTION='800x600x24' \
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_BIN/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_signal_cleanup.log 2>&1 &
run_pid=$!

for _ in $(seq 1 50); do
  if [[ -f "$PID_FILE" && $(wc -l < "$PID_FILE") -eq 2 ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -f "$PID_FILE" || $(wc -l < "$PID_FILE") -ne 2 ]]; then
  echo "Expected PID file to be written before signal cleanup" >&2
  cat /tmp/test_run_virtual_signal_cleanup.log >&2
  exit 1
fi

mapfile -t pids < "$PID_FILE"
main_xvfb_pid="${pids[0]}"
main_app_pid="${pids[1]}"

kill -TERM "$run_pid"
wait "$run_pid" || true

if [[ -e "$PID_FILE" ]]; then
  echo "Expected PID file removal after signal cleanup" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

if kill -0 "$main_xvfb_pid" 2>/dev/null; then
  echo "Xvfb process still alive after signal cleanup" >&2
  exit 1
fi

if kill -0 "$main_app_pid" 2>/dev/null; then
  echo "App process still alive after signal cleanup" >&2
  exit 1
fi

if ! grep -Fq 'xvfb :79 -screen 0 800x600x24' "$XVFB_LOG"; then
  echo "Expected Xvfb startup to be logged" >&2
  cat "$XVFB_LOG" >&2
  exit 1
fi

if ! grep -Fq 'app started with DISPLAY=:79' "$APP_LOG"; then
  echo "Expected app startup to be logged" >&2
  cat "$APP_LOG" >&2
  exit 1
fi

echo "[test_run_virtual_signal_cleanup] Passed"
