#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
FAKE_APP_DIR="$FAKE_ROOT/build/linux/x64/debug/bundle"
LOG_FILE="$WORK_DIR/log dir/virtual app.log"
PID_FILE="$WORK_DIR/pid dir/virtual app.pid"
XVFB_LOG="$WORK_DIR/xvfb.log"
mkdir -p "$FAKE_XVFB_DIR" "$FAKE_APP_DIR"
export LOG_FILE PID_FILE XVFB_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_XVFB_DIR/Xvfb" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "xvfb $*" >> "$XVFB_LOG"
sleep 60
EOF
chmod +x "$FAKE_XVFB_DIR/Xvfb"

cat > "$FAKE_APP_DIR/cloudtolocalllm" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "space root app started with DISPLAY=$DISPLAY" >> "${LOG_FILE:?missing LOG_FILE}"
sleep 60
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
DISPLAY_NUM=80 \
RESOLUTION='1024x768x24' \
LOG_FILE="$LOG_FILE" \
PID_FILE="$PID_FILE" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT"

[[ -f "$PID_FILE" ]]
[[ $(wc -l < "$PID_FILE") -eq 2 ]]
[[ -s "$LOG_FILE" ]]
[[ -s "$XVFB_LOG" ]]
grep -Fq '80 -screen 0 1024x768x24' "$XVFB_LOG"
grep -Fq 'space root app started with DISPLAY=:80' "$LOG_FILE"

echo "[test_run_virtual_project_root_spaces] Passed"
