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
mkdir -p "$FAKE_XVFB_DIR" "$FAKE_APP_DIR"

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
echo 'crashing app now'
exit 42
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

set +e
DISPLAY_NUM=78 \
RESOLUTION='1024x768x24' \
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm" \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT" >/tmp/test_run_virtual_crash_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo 'Expected run_virtual.sh to fail when the app exits immediately' >&2
  cat /tmp/test_run_virtual_crash_guard.log >&2
  exit 1
fi

if ! grep -Fq 'App exited unexpectedly' /tmp/test_run_virtual_crash_guard.log; then
  echo 'Missing crash-guard failure message' >&2
  cat /tmp/test_run_virtual_crash_guard.log >&2
  exit 1
fi

if ! grep -Fq 'crashing app now' "$LOG_FILE"; then
  echo 'Expected app log entry was not captured' >&2
  cat /tmp/test_run_virtual_crash_guard.log >&2
  exit 1
fi

if [[ -e "$PID_FILE" ]]; then
  echo 'Expected PID file cleanup after startup failure' >&2
  ls -l "$PID_FILE" >&2
  exit 1
fi

echo "[test_run_virtual_crash_guard] Passed"
