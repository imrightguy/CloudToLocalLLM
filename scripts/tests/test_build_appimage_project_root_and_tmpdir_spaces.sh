#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
TMPDIR_ROOT="$WORK_DIR/tmp dir with spaces/base/inner"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
APPIMAGETOOL_DIR="$WORK_DIR/appimage tools"
APPIMAGE_LOG="$WORK_DIR/appimage.log"
TMP_OUTPUT="$WORK_DIR/output dir with spaces/cloudtolocalllm-appimage-project-root-tmpdir-spaces.AppImage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$APPIMAGETOOL_DIR" "$TMPDIR_ROOT" "$(dirname "$TMP_OUTPUT")" "$FAKE_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir" "$FAKE_ROOT/scripts"
export APPIMAGE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 9.8.7+6
EOF

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Project root and tmpdir spaces test desktop entry
Terminal=false
EOF

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter:%s\n' "$*" >> "${APPIMAGE_LOG:?missing APPIMAGE_LOG}"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

cat > "$FAKE_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir/cloudtolocalllm.desktop" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
EOF

cat > "$APPIMAGETOOL_DIR/appimagetool wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "$0" "$*" >> "${APPIMAGE_LOG:?missing APPIMAGE_LOG}"
appdir="$1"
out="$2"
mkdir -p "$(dirname "$out")"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$APPIMAGETOOL_DIR/appimagetool wrapper"

PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
TMPDIR="$TMPDIR_ROOT////" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
APPIMAGETOOL_CMD="$APPIMAGETOOL_DIR/appimagetool wrapper" \
FLUTTER_CMD="$FAKE_ROOT/scripts/flutter_with_cleanup.sh" \
bash "$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_project_root_and_tmpdir_spaces.log 2>&1

APPIMAGE_FILE="$TMP_OUTPUT"

if [[ ! -f "$APPIMAGE_FILE" ]]; then
  echo "Expected AppImage output at $APPIMAGE_FILE" >&2
  cat /tmp/test_build_appimage_project_root_and_tmpdir_spaces.log >&2
  exit 1
fi

if ! grep -Fq 'flutter:build linux --release' "$APPIMAGE_LOG"; then
  echo "Expected Flutter wrapper under spaced project root to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fq "$APPIMAGETOOL_DIR/appimagetool wrapper AppDir" "$APPIMAGE_LOG"; then
  echo "Expected spaced appimagetool override to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fq 'AppImage built and installed successfully!' /tmp/test_build_appimage_project_root_and_tmpdir_spaces.log; then
  echo "Expected successful build output" >&2
  cat /tmp/test_build_appimage_project_root_and_tmpdir_spaces.log >&2
  exit 1
fi

if find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'cloudtolocalllm-appimage.*' | grep -q .; then
  echo "Expected AppImage workdir cleanup under normalized TMPDIR root" >&2
  find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'cloudtolocalllm-appimage.*' >&2
  exit 1
fi

echo "[test_build_appimage_project_root_and_tmpdir_spaces] Passed"
