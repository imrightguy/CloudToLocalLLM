#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
TMP_HOME="$WORK_DIR/home with spaces"
TMP_BUILD_DIR="$WORK_DIR/build dir"
TMP_WORKDIR="$WORK_DIR/appimage workdir"
TMP_OUTPUT="$WORK_DIR/output dir/cloudtolocalllm-install-path-spaces.AppImage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
TMP_INSTALL_BIN="$WORK_DIR/install bin path with spaces/cloudtolocalllm"
TMP_DESKTOP_ENTRY="$WORK_DIR/desktop entries with spaces/cloudtolocalllm-appimage.desktop"
APPIMAGETOOL_LOG="$WORK_DIR/appimagetool.log"
FAKE_TOOLS="$WORK_DIR/bin"
mkdir -p "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_WORKDIR" "$FAKE_TOOLS" "$(dirname "$TMP_OUTPUT")" "$(dirname "$TMP_INSTALL_BIN")" "$(dirname "$TMP_DESKTOP_ENTRY")"
export APPIMAGETOOL_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Install path spaces test desktop entry
Terminal=false
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
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
INSTALL_BIN="$TMP_INSTALL_BIN" \
DESKTOP_ENTRY="$TMP_DESKTOP_ENTRY" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
APPIMAGETOOL_CMD="$FAKE_TOOLS/fake-appimagetool" \
FLUTTER_CMD=/usr/bin/true \
bash "$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_install_paths_spaces.log 2>&1

if [[ ! -f "$TMP_INSTALL_BIN" ]]; then
  echo "Expected installed binary at $TMP_INSTALL_BIN" >&2
  cat /tmp/test_build_appimage_install_paths_spaces.log >&2
  exit 1
fi

if [[ ! -f "$TMP_DESKTOP_ENTRY" ]]; then
  echo "Expected desktop entry at $TMP_DESKTOP_ENTRY" >&2
  cat /tmp/test_build_appimage_install_paths_spaces.log >&2
  exit 1
fi

if ! grep -Fq "Exec=$TMP_INSTALL_BIN" "$TMP_DESKTOP_ENTRY"; then
  echo "Expected desktop entry to reference spaced install bin path" >&2
  cat "$TMP_DESKTOP_ENTRY" >&2
  exit 1
fi

if ! grep -Fq "$FAKE_TOOLS/fake-appimagetool AppDir" "$APPIMAGETOOL_LOG"; then
  echo "Expected appimagetool override to be invoked" >&2
  cat "$APPIMAGETOOL_LOG" >&2
  exit 1
fi

if [[ -d "$TMP_WORKDIR" ]]; then
  echo "Expected APPIMAGE_WORKDIR cleanup on success" >&2
  find "$TMP_WORKDIR" -maxdepth 2 -print >&2
  exit 1
fi

echo "[test_build_appimage_install_paths_spaces] Passed"
