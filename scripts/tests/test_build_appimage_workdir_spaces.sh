#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
APPIMAGE_WORKDIR="$WORK_DIR/appimage work dir with spaces"
APPIMAGE_OUTPUT="$WORK_DIR/output/cloudtolocalllm-workdir-spaces.AppImage"
APPIMAGETOOL_LOG="$WORK_DIR/appimagetool.log"
mkdir -p "$FAKE_ROOT/scripts" "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$FAKE_ROOT/build-tools/packaging/appimage/CloudToLocalLLM.AppDir"
export APPIMAGETOOL_LOG

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

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
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

cat > "$FAKE_TOOLS/fake-appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "$0" "$*" >> "${APPIMAGETOOL_LOG:?missing APPIMAGETOOL_LOG}"
appdir="$1"
out="$2"
mkdir -p "$(dirname "$out")"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_TOOLS/fake-appimagetool"

PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT" \
APPIMAGETOOL_CMD="$FAKE_TOOLS/fake-appimagetool" \
FLUTTER_CMD="$FAKE_ROOT/scripts/flutter_with_cleanup.sh" \
bash "$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_workdir_spaces.log 2>&1

if [[ ! -f "$APPIMAGE_OUTPUT" ]]; then
  echo "Expected AppImage output at $APPIMAGE_OUTPUT" >&2
  cat /tmp/test_build_appimage_workdir_spaces.log >&2
  exit 1
fi

if ! grep -Fq "$FAKE_TOOLS/fake-appimagetool AppDir" "$APPIMAGETOOL_LOG"; then
  echo "Expected appimagetool override to be invoked" >&2
  cat "$APPIMAGETOOL_LOG" >&2
  exit 1
fi

if [[ -d "$APPIMAGE_WORKDIR" ]]; then
  echo "Expected APPIMAGE_WORKDIR cleanup on success" >&2
  find "$APPIMAGE_WORKDIR" -maxdepth 2 -print >&2
  exit 1
fi

echo "[test_build_appimage_workdir_spaces] Passed"
