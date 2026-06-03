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
echo "virtual app started with DISPLAY=$DISPLAY"
sleep 60
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

DISPLAY_NUM=77 \
RESOLUTION='1024x768x24' \
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm" \
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
grep -Fq '77 -screen 0 1024x768x24' "$XVFB_LOG"
grep -Fq 'virtual app started with DISPLAY=:77' "$LOG_FILE"

echo "[test_run_virtual_smoke] Passed"
