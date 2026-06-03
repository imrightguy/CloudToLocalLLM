#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/bin"
APP_PATH="$WORK_DIR/app/cloudtolocalllm"
LOG_FILE="$WORK_DIR/logs/run.log"
PID_FILE="$WORK_DIR/state/run.pid"
mkdir -p "$FAKE_XVFB_DIR" "$WORK_DIR/app" "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_XVFB_DIR/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb should not start" >&2
exit 1
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

cat > "$APP_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "app should not start"
exit 0
EOF
chmod +x "$APP_PATH"

set +e
DISPLAY_NUM=91 \
RESOLUTION='' \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_resolution_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when RESOLUTION is empty" >&2
  cat /tmp/test_run_virtual_resolution_guard.log >&2
  exit 1
fi

if ! grep -Fq 'RESOLUTION must not be empty' /tmp/test_run_virtual_resolution_guard.log; then
  echo "Missing RESOLUTION validation message" >&2
  cat /tmp/test_run_virtual_resolution_guard.log >&2
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo "Expected no PID file when RESOLUTION validation fails" >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected no app log when RESOLUTION validation fails" >&2
  ls -l "$LOG_FILE" >&2
  exit 1
fi

echo "[test_run_virtual_resolution_guard] Passed"
