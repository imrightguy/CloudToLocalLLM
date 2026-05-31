#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
OUTPUT_DIR="$WORK_DIR/out"
APPIMAGE_WORKDIR="$WORK_DIR/work"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
LOG_FILE="$WORK_DIR/appimagetool.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$OUTPUT_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
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
Comment=Failure cleanup test desktop entry
Terminal=false
EOF

cat > "$FAKE_TOOLS_DIR/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_TOOLS_DIR/appimagetool"

cat > "$FAKE_TOOLS_DIR/du" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 1
EOF
chmod +x "$FAKE_TOOLS_DIR/du"

set +e
PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
OUTPUT_DIR="$OUTPUT_DIR" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
LOG_FILE="$LOG_FILE" \
FLUTTER_CMD=/usr/bin/true \
"$TARGET_SCRIPT" >/tmp/test_packaging_build_appimage_failure_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when du exits non-zero during validation" >&2
  cat /tmp/test_packaging_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -d "$APPIMAGE_WORKDIR" ]]; then
  echo "Expected AppImage workdir cleanup after failure, but $APPIMAGE_WORKDIR still exists" >&2
  cat /tmp/test_packaging_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -f "$OUTPUT_DIR/cloudtolocalllm-1.0.0-x86_64.AppImage" ]]; then
  echo "Expected failed AppImage output cleanup, but output file still exists" >&2
  cat /tmp/test_packaging_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -f "$OUTPUT_DIR/cloudtolocalllm-1.0.0-x86_64.AppImage.sha256" ]]; then
  echo "Expected failed AppImage checksum cleanup, but checksum file still exists" >&2
  cat /tmp/test_packaging_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if ! grep -Fq 'appimagetool' "$LOG_FILE"; then
  echo "Expected appimagetool invocation to be logged before failure" >&2
  cat /tmp/test_packaging_build_appimage_failure_cleanup.log >&2
  exit 1
fi

echo "[test_packaging_build_appimage_failure_cleanup] Passed"
