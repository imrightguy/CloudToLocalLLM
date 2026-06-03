#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
LOG_FILE="$WORK_DIR/run.log"
PID_FILE="$WORK_DIR/run.pid"
XVFB_LOG="$WORK_DIR/xvfb.log"
MISSING_APP_PATH="$WORK_DIR/missing app dir/cloudtolocalllm"
mkdir -p "$FAKE_XVFB_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_XVFB_DIR/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb should not run" >> "$XVFB_LOG"
exit 1
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

set +e
DISPLAY_NUM=84 \
RESOLUTION='1024x768x24' \
APP_PATH="$MISSING_APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_missing_app_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when APP_PATH is missing" >&2
  cat /tmp/test_run_virtual_missing_app_guard.log >&2
  exit 1
fi

if ! grep -Fq 'App bundle is not executable' /tmp/test_run_virtual_missing_app_guard.log; then
  echo "Missing validation message for absent APP_PATH" >&2
  cat /tmp/test_run_virtual_missing_app_guard.log >&2
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo "Expected no PID file when APP_PATH validation fails" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected no app log when APP_PATH validation fails" >&2
  ls -l "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$XVFB_LOG" ]]; then
  echo "Expected Xvfb to remain unused when APP_PATH validation fails" >&2
  cat "$XVFB_LOG" >&2
  exit 1
fi

echo "[test_run_virtual_missing_app_guard] Passed"
