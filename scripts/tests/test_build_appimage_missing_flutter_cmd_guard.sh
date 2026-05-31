#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT="$(mktemp -u /tmp/cloudtolocalllm-appimage-missing-flutter.XXXXXX.AppImage)"
TMP_DESKTOP_TEMPLATE="$(mktemp)"
LOG_FILE="/tmp/test_build_appimage_missing_flutter_cmd_guard.log"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_WORKDIR"
  rm -f "$TMP_OUTPUT" "$TMP_DESKTOP_TEMPLATE"
}
trap cleanup EXIT

mkdir -p "$TMP_BUILD_DIR"
printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Missing FLUTTER_CMD guard test desktop entry
Terminal=false
EOF

set +e
PATH="/usr/bin:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
FLUTTER_CMD="$TMP_WORKDIR/missing-flutter" \
"$PROJECT_ROOT/scripts/build-appimage.sh" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when FLUTTER_CMD is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "FLUTTER_CMD not found or not executable" "$LOG_FILE"; then
  echo "Expected missing FLUTTER_CMD error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$TMP_OUTPUT" ]]; then
  echo "Expected no AppImage output when FLUTTER_CMD is missing" >&2
  ls -l "$TMP_OUTPUT" >&2
  exit 1
fi

echo "[test_build_appimage_missing_flutter_cmd_guard] Passed"
