#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
BUILD_DIR="$WORK_DIR/bundle"
APPIMAGE_WORKDIR="$WORK_DIR/work"
OUTPUT_FILE="$WORK_DIR/out/CloudToLocalLLM-x86_64.AppImage"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
APPIMAGETOOL_DIR="$WORK_DIR/appimagetool-dir"
PUBSPEC_FILE="$WORK_DIR/pubspec.yaml"
mkdir -p "$BUILD_DIR" "$APPIMAGE_WORKDIR" "$APPIMAGETOOL_DIR" "$(dirname "$OUTPUT_FILE")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$PUBSPEC_FILE" <<'EOF'
name: cloudtolocalllm
version: 1.2.3+4
EOF

cat > "$BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$BUILD_DIR/cloudtolocalllm"

cat > "$DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Packaging AppImage tool directory guard test
Terminal=false
EOF

set +e
APPIMAGETOOL_CMD="$APPIMAGETOOL_DIR" \
BUILD_DIR="$BUILD_DIR" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
APPIMAGE_OUTPUT="$OUTPUT_FILE" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
PUBSPEC_FILE="$PUBSPEC_FILE" \
"$TARGET_SCRIPT" >/tmp/test_packaging_build_appimage_appimagetool_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected packaging/build_appimage.sh to fail when APPIMAGETOOL_CMD is a directory" >&2
  cat /tmp/test_packaging_build_appimage_appimagetool_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'APPIMAGETOOL_CMD must not be a directory' /tmp/test_packaging_build_appimage_appimagetool_directory_guard.log; then
  echo "Missing APPIMAGETOOL_CMD directory validation message" >&2
  cat /tmp/test_packaging_build_appimage_appimagetool_directory_guard.log >&2
  exit 1
fi

if [[ -e "$OUTPUT_FILE" ]]; then
  echo "Expected no AppImage output when APPIMAGETOOL_CMD guard fails" >&2
  ls -l "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_packaging_build_appimage_appimagetool_directory_guard] Passed"
