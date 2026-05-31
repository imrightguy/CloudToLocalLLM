#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
TMP_HOME="$WORK_DIR/home"
TMP_BUILD_DIR="$WORK_DIR/bundle"
TMP_OUTPUT_DIR="$WORK_DIR/dist/linux"
TMP_APPIMAGE_WORKDIR="$WORK_DIR/appimage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/desktop/cloudtolocalllm.desktop"
TMP_PUBSPEC="$WORK_DIR/pubspec.yaml"
LOG_FILE="$WORK_DIR/build.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_OUTPUT_DIR" "$(dirname "$TMP_DESKTOP_TEMPLATE")"
printf '%s\n' 'name: cloudtolocalllm' > "$TMP_PUBSPEC"
printf '%s\n' '#!/bin/sh' 'echo bundle-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"
cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Malformed version test desktop entry
Terminal=false
EOF

set +e
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
OUTPUT_DIR="$TMP_OUTPUT_DIR" \
APPIMAGE_WORKDIR="$TMP_APPIMAGE_WORKDIR" \
PUBSPEC_FILE="$TMP_PUBSPEC" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
APPIMAGETOOL_CMD=/bin/true \
"$PROJECT_ROOT/scripts/packaging/build_appimage.sh" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when version entry is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "version entry not found in pubspec.yaml" "$LOG_FILE"; then
  echo "Expected missing version entry error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_packaging_build_appimage_missing_version_guard] Passed"
