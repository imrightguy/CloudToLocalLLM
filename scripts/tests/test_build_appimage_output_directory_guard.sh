#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/build-appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/calls.log"
INSTALL_BIN="$WORK_DIR/install/cloudtolocalllm"
APPIMAGE_OUTPUT_DIR="$WORK_DIR/output-dir"
DESKTOP_ENTRY="$WORK_DIR/share/cloudtolocalllm.desktop"
mkdir -p "$FAKE_TOOLS_DIR" "$(dirname "$INSTALL_BIN")" "$APPIMAGE_OUTPUT_DIR" "$(dirname "$DESKTOP_ENTRY")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_TOOLS_DIR/flutter" <<EOF
#!/bin/bash
set -euo pipefail
echo "flutter \$*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_TOOLS_DIR/flutter"

set +e
PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
FLUTTER_CMD="$FAKE_TOOLS_DIR/flutter" \
INSTALL_BIN="$INSTALL_BIN" \
APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT_DIR" \
DESKTOP_ENTRY="$DESKTOP_ENTRY" \
"$TARGET_SCRIPT" >/tmp/test_build_appimage_output_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when APPIMAGE_OUTPUT is a directory" >&2
  cat /tmp/test_build_appimage_output_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'APPIMAGE_OUTPUT must not be a directory' /tmp/test_build_appimage_output_directory_guard.log; then
  echo "Missing APPIMAGE_OUTPUT directory validation message" >&2
  cat /tmp/test_build_appimage_output_directory_guard.log >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected flutter not to be invoked when APPIMAGE_OUTPUT guard fails" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if find "$APPIMAGE_OUTPUT_DIR" -mindepth 1 -print -quit | grep -q .; then
  echo "Expected no artifacts to be written inside APPIMAGE_OUTPUT directory guard target" >&2
  find "$APPIMAGE_OUTPUT_DIR" -mindepth 1 -print >&2
  exit 1
fi

echo "[test_build_appimage_output_directory_guard] Passed"
