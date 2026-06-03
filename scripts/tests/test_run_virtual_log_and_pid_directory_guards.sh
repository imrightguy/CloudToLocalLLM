#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_XVFB_DIR="$WORK_DIR/bin"
APP_PATH="$WORK_DIR/app/cloudtolocalllm"
LOG_DIR="$WORK_DIR/logs"
PID_DIR="$WORK_DIR/state"
mkdir -p "$FAKE_XVFB_DIR" "$WORK_DIR/app" "$LOG_DIR" "$PID_DIR"

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
RESOLUTION='1920x1080x24' \
APP_PATH="$APP_PATH" \
LOG_FILE="$LOG_DIR" \
PID_FILE="$PID_DIR" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_log_and_pid_directory_guards.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected run_virtual.sh to fail when LOG_FILE or PID_FILE is a directory" >&2
  cat /tmp/test_run_virtual_log_and_pid_directory_guards.log >&2
  exit 1
fi

if ! grep -Eq 'LOG_FILE must not be a directory|PID_FILE must not be a directory' /tmp/test_run_virtual_log_and_pid_directory_guards.log; then
  echo "Missing LOG_FILE/PID_FILE directory validation message" >&2
  cat /tmp/test_run_virtual_log_and_pid_directory_guards.log >&2
  exit 1
fi

if [[ -e "$LOG_DIR/run.log" || -e "$PID_DIR/run.pid" ]]; then
  echo "Expected no app log or pid file to be created when directory validation fails" >&2
  find "$WORK_DIR" -maxdepth 2 -type f -o -type d >&2
  exit 1
fi

echo "[test_run_virtual_log_and_pid_directory_guards] Passed"
