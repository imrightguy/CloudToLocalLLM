#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
SCRIPT_COPY="$WORK_DIR/scripts/packaging/build_appimage.sh"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOL="$WORK_DIR/appimagetool"
FAKE_TOOL_LOG="$WORK_DIR/appimagetool.log"
OUTPUT_DIR="$WORK_DIR/out"
APPIMAGE_WORKDIR="$WORK_DIR/work"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
TEMPLATE_DIR="$WORK_DIR/build-tools/packaging/appimage/CloudToLocalLLM.AppDir"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BUILD_DIR" "$OUTPUT_DIR" "$TEMPLATE_DIR" "$(dirname "$SCRIPT_COPY")"
cp "$TARGET_SCRIPT" "$SCRIPT_COPY"
chmod +x "$SCRIPT_COPY"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

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

cat > "$TEMPLATE_DIR/AppRun" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TEMPLATE_DIR/AppRun"
cat > "$TEMPLATE_DIR/.template-marker" <<'EOF'
hidden-template-marker
EOF

cat > "$FAKE_TOOL" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'ARCH=%s %s\n' "${ARCH:-}" "$*" >> "$FAKE_TOOL_LOG"
if [[ ! -f AppDir/.template-marker ]]; then
  echo "expected hidden template marker in AppDir" >&2
  exit 1
fi
: > "$2"
chmod +x "$2"
EOF
chmod +x "$FAKE_TOOL"

export FAKE_TOOL_LOG
PATH="$WORK_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
OUTPUT_DIR="$OUTPUT_DIR" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
APPIMAGETOOL_CMD="$FAKE_TOOL" \
"$SCRIPT_COPY" >/dev/null 2>&1

APPIMAGE_FILE="$OUTPUT_DIR/cloudtolocalllm-$(grep 'version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | cut -d '+' -f 1)-x86_64.AppImage"
[[ -f "$APPIMAGE_FILE" ]]
[[ -x "$APPIMAGE_FILE" ]]
grep -Fq 'ARCH=x86_64' "$FAKE_TOOL_LOG"

echo "[test_packaging_build_appimage_template_copy_hidden_file] Passed"
