#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOL="$WORK_DIR/appimagetool"
FAKE_TOOL_LOG="$WORK_DIR/appimagetool.log"
OUTPUT_DIR="$WORK_DIR/out"
APPIMAGE_WORKDIR="$WORK_DIR/work"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
mkdir -p "$FAKE_BUILD_DIR/data" "$FAKE_BUILD_DIR/lib" "$OUTPUT_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Utility;
Version=1.0.0
EOF

cat > "$FAKE_TOOL" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'ARCH=%s %s\n' "${ARCH:-}" "$*" >> "$FAKE_TOOL_LOG"
: > "$2"
chmod +x "$2"
EOF
chmod +x "$FAKE_TOOL"

PATH="$WORK_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
OUTPUT_DIR="$OUTPUT_DIR" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
FAKE_TOOL_LOG="$FAKE_TOOL_LOG" \
"$TARGET_SCRIPT"

APPIMAGE_FILE="$OUTPUT_DIR/cloudtolocalllm-$(grep 'version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | cut -d '+' -f 1)-x86_64.AppImage"
CHECKSUM_FILE="$APPIMAGE_FILE.sha256"

[[ -f "$APPIMAGE_FILE" ]]
[[ -f "$CHECKSUM_FILE" ]]
[[ -x "$APPIMAGE_FILE" ]]
grep -Fq 'ARCH=x86_64' "$FAKE_TOOL_LOG"
grep -Fq 'AppDir' "$FAKE_TOOL_LOG"

echo "[test_packaging_build_appimage_smoke] Passed"
