#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/build-appimage.sh"
WORK_DIR="$(mktemp -d)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_WORKDIR="$WORK_DIR/work dir with spaces"
TMP_OUTPUT="$WORK_DIR/output dir with spaces/cloudtolocalllm-appimage-spaced-cmd.AppImage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
DPKG_DIR="$WORK_DIR/appimage tools"
TMP_INVOKE_LOG="$WORK_DIR/appimage.log"
mkdir -p "$TMP_WORKDIR" "$TMP_BUILD_DIR" "$WORK_DIR/output dir with spaces" "$DPKG_DIR"
export TMP_INVOKE_LOG

cleanup() {
  rm -rf "$WORK_DIR" "$TMP_HOME" "$TMP_BUILD_DIR"
}
trap cleanup EXIT

printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Spaced appimagetool command test desktop entry
Terminal=false
EOF

cat > "$DPKG_DIR/appimagetool wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$TMP_INVOKE_LOG"
appdir="$1"
out="$2"
mkdir -p "$(dirname "$out")"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$DPKG_DIR/appimagetool wrapper"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

PATH="/usr/bin:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
APPIMAGETOOL_CMD="$DPKG_DIR/appimagetool wrapper" \
FLUTTER_CMD=/usr/bin/true \
"$TARGET_SCRIPT" >/tmp/test_build_appimage_cmd_path_spaces.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_build_appimage_cmd_path_spaces.log >&2
  exit 1
fi

if ! grep -Fq "$DPKG_DIR/appimagetool wrapper" "$TMP_INVOKE_LOG"; then
  echo "Expected spaced APPIMAGETOOL_CMD path to be invoked" >&2
  cat "$TMP_INVOKE_LOG" >&2
  exit 1
fi

if grep -Fq 'Downloading appimagetool' /tmp/test_build_appimage_cmd_path_spaces.log; then
  echo "Expected APPIMAGETOOL_CMD override to skip download path" >&2
  cat /tmp/test_build_appimage_cmd_path_spaces.log >&2
  exit 1
fi

echo "[test_build_appimage_cmd_path_spaces] Passed"
