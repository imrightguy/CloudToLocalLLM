#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
APPIMAGE_OUTPUT_DIR="$WORK_DIR/output-dir"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
PUBSPEC_FILE="$WORK_DIR/pubspec.yaml"
LOG_FILE="$WORK_DIR/appimagetool.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$APPIMAGE_OUTPUT_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$PUBSPEC_FILE" <<'EOF'
name: cloudtolocalllm
version: 1.2.3+4
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
Categories=Development;
Comment=Output directory guard test desktop entry
Terminal=false
EOF

cat > "$FAKE_TOOLS_DIR/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "appimagetool should not have been invoked" >&2
exit 1
EOF
chmod +x "$FAKE_TOOLS_DIR/appimagetool"

set +e
PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
OUTPUT_DIR="$WORK_DIR/out" \
APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT_DIR" \
APPIMAGE_WORKDIR="$WORK_DIR/work" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
PUBSPEC_FILE="$PUBSPEC_FILE" \
FLUTTER_CMD=/usr/bin/true \
"$TARGET_SCRIPT" >/tmp/test_packaging_build_appimage_output_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when APPIMAGE_OUTPUT is a directory" >&2
  cat /tmp/test_packaging_build_appimage_output_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'APPIMAGE_OUTPUT must not be a directory' /tmp/test_packaging_build_appimage_output_directory_guard.log; then
  echo "Missing APPIMAGE_OUTPUT directory validation message" >&2
  cat /tmp/test_packaging_build_appimage_output_directory_guard.log >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected appimagetool not to be invoked when APPIMAGE_OUTPUT guard fails" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if find "$APPIMAGE_OUTPUT_DIR" -mindepth 1 -print -quit | grep -q .; then
  echo "Expected no artifacts to be written into the output directory target" >&2
  find "$APPIMAGE_OUTPUT_DIR" -mindepth 1 -print >&2
  exit 1
fi

echo "[test_packaging_build_appimage_output_directory_guard] Passed"
