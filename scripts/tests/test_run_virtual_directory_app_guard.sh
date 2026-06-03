#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
APP_PATH="$WORK_DIR/app dir"
LOG_FILE="$WORK_DIR/logs/run.log"
PID_FILE="$WORK_DIR/state/run.pid"
mkdir -p "$FAKE_XVFB_DIR" "$APP_PATH" "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_XVFB_DIR/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb should not run" >&2
exit 1
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

set +e
DISPLAY_NUM=87 \
RESOLUTION='1024x768x24' \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_directory_app_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when APP_PATH is a directory" >&2
  cat /tmp/test_run_virtual_directory_app_guard.log >&2
  exit 1
fi

if ! grep -Fq 'App bundle is not executable' /tmp/test_run_virtual_directory_app_guard.log; then
  echo "Missing validation message for directory APP_PATH" >&2
  cat /tmp/test_run_virtual_directory_app_guard.log >&2
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo "Expected no PID file when directory APP_PATH validation fails" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected no app log when directory APP_PATH validation fails" >&2
  ls -l "$LOG_FILE" >&2
  exit 1
fi

if grep -Fq 'xvfb should not run' /tmp/test_run_virtual_directory_app_guard.log; then
  echo "Expected validation failure before Xvfb launch" >&2
  cat /tmp/test_run_virtual_directory_app_guard.log >&2
  exit 1
fi

echo "[test_run_virtual_directory_app_guard] Passed"
