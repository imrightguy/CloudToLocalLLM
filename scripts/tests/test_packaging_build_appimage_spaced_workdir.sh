#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
TMP_BUILD_DIR="$WORK_DIR/bundle"
TMP_WORK_ROOT="$WORK_DIR/work root with spaces"
TMP_WORKDIR="$TMP_WORK_ROOT/appimage work"
TMP_OUTPUT="$WORK_DIR/output dir with spaces/cloudtolocalllm-spaced-workdir.AppImage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
FAKE_BIN_DIR="$WORK_DIR/bin"
APPIMAGE_LOG="$WORK_DIR/appimagetool.log"
export APPIMAGE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_BUILD_DIR" "$FAKE_BIN_DIR" "$WORK_DIR/output dir with spaces"
printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Spaced workdir smoke test desktop entry
Terminal=false
EOF

cat > "$FAKE_BIN_DIR/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s|%s\n' "$PWD" "$*" >> "$APPIMAGE_LOG"
appdir="$1"
out="$2"
mkdir -p "$(dirname "$out")"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_BIN_DIR/appimagetool"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

TMPDIR="$WORK_DIR/tmp dir" \
PATH="$FAKE_BIN_DIR:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$WORK_DIR" \
BUILD_DIR="$TMP_BUILD_DIR" \
OUTPUT_DIR="$WORK_DIR/output dir with spaces" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
"$TARGET_SCRIPT" >/tmp/test_packaging_build_appimage_spaced_workdir.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_packaging_build_appimage_spaced_workdir.log >&2
  exit 1
fi

if ! grep -Fq "$TMP_WORKDIR" "$APPIMAGE_LOG"; then
  echo "Expected build_appimage.sh to use the spaced APPIMAGE_WORKDIR" >&2
  cat /tmp/test_packaging_build_appimage_spaced_workdir.log >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fq 'AppDir ' "$APPIMAGE_LOG"; then
  echo "Expected appimagetool override to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

echo "[test_packaging_build_appimage_spaced_workdir] Passed"
