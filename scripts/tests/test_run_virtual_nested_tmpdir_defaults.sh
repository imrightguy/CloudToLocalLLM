#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/scripts/archive/run_virtual.sh"
WORK_DIR="$(mktemp -d)"
TMPDIR_ROOT="$WORK_DIR/nested/tmp/dir"
FAKE_XVFB_DIR="$WORK_DIR/fakebin"
FAKE_APP_DIR="$WORK_DIR/app"
APP_LOG="$TMPDIR_ROOT/app_virtual_display.log"
PID_FILE="$TMPDIR_ROOT/app_virtual_display.pid"
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
echo "nested tmpdir virtual app started with DISPLAY=$DISPLAY"
sleep 60
EOF
chmod +x "$FAKE_APP_DIR/cloudtolocalllm"

TMPDIR="$TMPDIR_ROOT" \
DISPLAY_NUM=79 \
RESOLUTION='1280x720x24' \
APP_PATH="$FAKE_APP_DIR/cloudtolocalllm" \
XVFB_BIN="$FAKE_XVFB_DIR/Xvfb" \
XVFB_READY_DELAY=1 \
STARTUP_CHECK_DELAY=1 \
"$RUN_SCRIPT"

[[ -d "$TMPDIR_ROOT" ]]
[[ -f "$APP_LOG" ]]
[[ -f "$PID_FILE" ]]
[[ $(wc -l < "$PID_FILE") -eq 2 ]]
grep -Fq 'nested tmpdir virtual app started with DISPLAY=:79' "$APP_LOG"
grep -Fq '79 -screen 0 1280x720x24' "$XVFB_LOG"

echo "[test_run_virtual_nested_tmpdir_defaults] Passed"
