#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_APP_DIR="$WORK_DIR/app"
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm"
LOG_FILE="$WORK_DIR/logs/run.log"
PID_FILE="$WORK_DIR/state/run.pid"
MISSING_XVFB_BIN="$WORK_DIR/bin/missing-Xvfb"
mkdir -p "$FAKE_APP_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$APP_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "app should not run"
exit 0
EOF
chmod +x "$APP_PATH"

set +e
DISPLAY_NUM=85 \
RESOLUTION='1024x768x24' \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$MISSING_XVFB_BIN" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_missing_xvfb_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when XVFB_BIN is missing" >&2
  cat /tmp/test_run_virtual_missing_xvfb_guard.log >&2
  exit 1
fi

if ! grep -Fq 'Missing Xvfb binary' /tmp/test_run_virtual_missing_xvfb_guard.log; then
  echo "Missing validation message for absent XVFB_BIN" >&2
  cat /tmp/test_run_virtual_missing_xvfb_guard.log >&2
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo "Expected no PID file when XVFB_BIN validation fails" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected no app log when XVFB_BIN validation fails" >&2
  ls -l "$LOG_FILE" >&2
  exit 1
fi

echo "[test_run_virtual_missing_xvfb_guard] Passed"
