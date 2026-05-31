#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
TMPDIR_BASE="$WORK_DIR/trailing/tmpdir/base"
TMP_OUTPUT="$WORK_DIR/dist/linux/cloudtolocalllm-1.2.3-x86_64.AppImage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
LOG_FILE="$WORK_DIR/appimagetool.log"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$TMPDIR_BASE" "$(dirname "$TMP_OUTPUT")"

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
Comment=TMPDIR trailing slash test
Terminal=false
EOF

cat > "$FAKE_TOOLS/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'cwd:%s\n' "$PWD" >> "$LOG_FILE"
printf 'args:%s\n' "$*" >> "$LOG_FILE"
appdir="$1"
out="$2"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_TOOLS/appimagetool"

TMPDIR="$TMPDIR_BASE////" \
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
OUTPUT_DIR="$(dirname "$TMP_OUTPUT")" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
FLUTTER_CMD=/usr/bin/true \
"$PROJECT_ROOT/scripts/packaging/build_appimage.sh" >/tmp/test_build_appimage_tmpdir_trailing_slashes.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_build_appimage_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if ! grep -Fq "cwd:$TMPDIR_BASE/cloudtolocalllm-appimage." "$LOG_FILE"; then
  echo "Expected AppImage workdir to be created under normalized TMPDIR root" >&2
  cat /tmp/test_build_appimage_tmpdir_trailing_slashes.log >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_build_appimage_tmpdir_trailing_slashes] Passed"
