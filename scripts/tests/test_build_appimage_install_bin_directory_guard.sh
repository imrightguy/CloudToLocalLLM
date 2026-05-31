#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/build-appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/calls.log"
INSTALL_DIR="$WORK_DIR/install-bin"
APPIMAGE_OUTPUT="$WORK_DIR/output/CloudToLocalLLM-x86_64.AppImage"
DESKTOP_ENTRY="$WORK_DIR/share/cloudtolocalllm.desktop"
mkdir -p "$FAKE_TOOLS_DIR" "$INSTALL_DIR" "$(dirname "$APPIMAGE_OUTPUT")" "$(dirname "$DESKTOP_ENTRY")"

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
INSTALL_BIN="$INSTALL_DIR" \
APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT" \
DESKTOP_ENTRY="$DESKTOP_ENTRY" \
"$TARGET_SCRIPT" >/tmp/test_build_appimage_install_bin_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when INSTALL_BIN is a directory" >&2
  cat /tmp/test_build_appimage_install_bin_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'INSTALL_BIN must not be a directory' /tmp/test_build_appimage_install_bin_directory_guard.log; then
  echo "Missing INSTALL_BIN directory validation message" >&2
  cat /tmp/test_build_appimage_install_bin_directory_guard.log >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected flutter not to be invoked when INSTALL_BIN guard fails" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$APPIMAGE_OUTPUT" ]]; then
  echo "Expected no AppImage output when INSTALL_BIN guard fails" >&2
  ls -l "$APPIMAGE_OUTPUT" >&2
  exit 1
fi

echo "[test_build_appimage_install_bin_directory_guard] Passed"
