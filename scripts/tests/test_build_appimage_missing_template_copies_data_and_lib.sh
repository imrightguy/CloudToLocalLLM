#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_FAKE_ROOT="$(mktemp -d)"
TMP_BUILD_DIR="$TMP_FAKE_ROOT/build/linux/x64/release/bundle"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT="$TMP_FAKE_ROOT/dist/linux/cloudtolocalllm-appimage-missing-template-data-lib.AppImage"
TMP_PUBSPEC="$TMP_FAKE_ROOT/pubspec.yaml"
TMP_DESKTOP_TEMPLATE="$TMP_FAKE_ROOT/custom.desktop"
TMP_INVOKE_LOG="$TMP_WORKDIR/invoke.log"
BIN_DIR="$TMP_WORKDIR/bin"
mkdir -p "$BIN_DIR" "$TMP_BUILD_DIR/data/subdir" "$TMP_BUILD_DIR/lib/subdir" "$TMP_FAKE_ROOT/dist/linux"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_FAKE_ROOT" "$TMP_WORKDIR"
  rm -f "$TMP_OUTPUT"
}
trap cleanup EXIT

printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"
printf '%s\n' 'data-file' > "$TMP_BUILD_DIR/data/subdir/example.txt"
printf '%s\n' 'lib-file' > "$TMP_BUILD_DIR/lib/subdir/example.txt"
printf '%s\n' 'name: cloudtolocalllm' 'version: 1.2.3+4' > "$TMP_PUBSPEC"
cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
EOF

cat > "$BIN_DIR/fake-appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$TMP_INVOKE_LOG"
appdir="$1"
out="$2"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$BIN_DIR/fake-appimagetool"

PATH="$BIN_DIR:/usr/bin:/bin" \
HOME="$TMP_HOME" \
PROJECT_ROOT_OVERRIDE="$TMP_FAKE_ROOT" \
PUBSPEC_FILE="$TMP_PUBSPEC" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR/work" \
KEEP_WORKDIR=true \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
APPIMAGETOOL_CMD="$BIN_DIR/fake-appimagetool" \
TMP_INVOKE_LOG="$TMP_INVOKE_LOG" \
"$PROJECT_ROOT/scripts/packaging/build_appimage.sh" >/tmp/test_build_appimage_missing_template_copies_data_and_lib.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_build_appimage_missing_template_copies_data_and_lib.log >&2
  exit 1
fi

if [[ ! -f "$TMP_WORKDIR/work/AppDir/data/subdir/example.txt" ]]; then
  echo "Expected data directory contents to be copied into AppDir" >&2
  cat /tmp/test_build_appimage_missing_template_copies_data_and_lib.log >&2
  exit 1
fi

if [[ ! -f "$TMP_WORKDIR/work/AppDir/lib/subdir/example.txt" ]]; then
  echo "Expected lib directory contents to be copied into AppDir" >&2
  cat /tmp/test_build_appimage_missing_template_copies_data_and_lib.log >&2
  exit 1
fi

if ! grep -q "$BIN_DIR/fake-appimagetool" "$TMP_INVOKE_LOG"; then
  echo "Expected APPIMAGETOOL_CMD override to be invoked" >&2
  cat /tmp/test_build_appimage_missing_template_copies_data_and_lib.log >&2
  exit 1
fi

if ! grep -Fq 'AppDir template missing, creating basic structure' /tmp/test_build_appimage_missing_template_copies_data_and_lib.log; then
  echo "Expected missing AppDir template fallback log" >&2
  cat /tmp/test_build_appimage_missing_template_copies_data_and_lib.log >&2
  exit 1
fi

echo "[test_build_appimage_missing_template_copies_data_and_lib] Passed"
