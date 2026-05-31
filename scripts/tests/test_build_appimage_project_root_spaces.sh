#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
APPIMAGE_LOG="$WORK_DIR/appimage.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$FAKE_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir" "$FAKE_ROOT/scripts" "$WORK_DIR/tmp dir"
export APPIMAGE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: temp_app
version: 9.8.7+6
EOF

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "flutter:$*" >> "${APPIMAGE_LOG:?missing APPIMAGE_LOG}"
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

cat > "$FAKE_TOOLS_DIR/fake-appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "appimagetool:$*" >> "${APPIMAGE_LOG:?missing APPIMAGE_LOG}"
appdir="$1"
out="$2"
mkdir -p "$(dirname "$out")"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_TOOLS_DIR/fake-appimagetool"

PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
APPIMAGE_WORKDIR="$WORK_DIR/tmp dir/appimage work" \
KEEP_WORKDIR=true \
APPIMAGE_OUTPUT="$FAKE_ROOT/dist dir with spaces/linux packages/cloudtolocalllm-9.8.7-x86_64.AppImage" \
DESKTOP_TEMPLATE="$FAKE_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir/cloudtolocalllm.desktop" \
APPIMAGETOOL_CMD="$FAKE_TOOLS_DIR/fake-appimagetool" \
FLUTTER_CMD="$FAKE_ROOT/scripts/flutter_with_cleanup.sh" \
"$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_project_root_spaces.log 2>&1

if [[ ! -f "$FAKE_ROOT/dist dir with spaces/linux packages/cloudtolocalllm-9.8.7-x86_64.AppImage" ]]; then
  echo "Expected AppImage output in the spaced override root dist directory" >&2
  cat /tmp/test_build_appimage_project_root_spaces.log >&2
  exit 1
fi

if ! grep -Fq 'flutter:build linux --release' "$APPIMAGE_LOG"; then
  echo "Expected Flutter wrapper under spaced override root to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fq 'appimagetool:AppDir' "$APPIMAGE_LOG"; then
  echo "Expected appimagetool override to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fq 'AppImage built and installed successfully!' /tmp/test_build_appimage_project_root_spaces.log; then
  echo "Expected successful build output" >&2
  cat /tmp/test_build_appimage_project_root_spaces.log >&2
  exit 1
fi

echo "[test_build_appimage_project_root_spaces] Passed"
