#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
BUILD_DIR="$WORK_DIR/bundle"
APPIMAGE_WORKDIR="$WORK_DIR/work"
OUTPUT_FILE="$WORK_DIR/out/CloudToLocalLLM-x86_64.AppImage"
PUBSPEC_DIR="$WORK_DIR/pubspec-dir"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
mkdir -p "$BUILD_DIR" "$APPIMAGE_WORKDIR" "$(dirname "$OUTPUT_FILE")" "$PUBSPEC_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

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
Comment=Packaging pubspec guard test
Terminal=false
EOF

set +e
BUILD_DIR="$BUILD_DIR" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
APPIMAGE_OUTPUT="$OUTPUT_FILE" \
PUBSPEC_FILE="$PUBSPEC_DIR" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
"$TARGET_SCRIPT" >/tmp/test_packaging_build_appimage_pubspec_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected packaging/build_appimage.sh to fail when PUBSPEC_FILE is a directory" >&2
  cat /tmp/test_packaging_build_appimage_pubspec_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'pubspec.yaml must not be a directory' /tmp/test_packaging_build_appimage_pubspec_directory_guard.log; then
  echo "Missing PUBSPEC_FILE directory validation message" >&2
  cat /tmp/test_packaging_build_appimage_pubspec_directory_guard.log >&2
  exit 1
fi

echo "[test_packaging_build_appimage_pubspec_directory_guard] Passed"
