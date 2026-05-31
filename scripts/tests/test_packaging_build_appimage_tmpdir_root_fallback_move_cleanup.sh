#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
OUTPUT_DIR="$WORK_DIR/out"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
LOG_FILE="$WORK_DIR/mv.log"
TMP_LOG="$WORK_DIR/mktemp.log"
APPIMAGE_OUTPUT="$WORK_DIR/out/nested/CloudToLocalLLM.AppImage"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$OUTPUT_DIR" "$(dirname "$APPIMAGE_OUTPUT")"
export LOG_FILE TMP_LOG

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
Comment=Tmpdir root fallback move cleanup test desktop entry
Terminal=false
EOF

cat > "$FAKE_TOOLS_DIR/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
result="$(/usr/bin/mktemp "$@")"
printf '%s => %s\n' "$*" "$result" >> "$TMP_LOG"
printf '%s\n' "$result"
EOF
chmod +x "$FAKE_TOOLS_DIR/mktemp"

cat > "$FAKE_TOOLS_DIR/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -fsSL)
      shift
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -z "$output" ]]; then
  echo "curl stub missing -o output" >&2
  exit 1
fi
cat > "$output" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
chmod +x "$output"
EOF
chmod +x "$FAKE_TOOLS_DIR/curl"

cat > "$FAKE_TOOLS_DIR/mv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
exit 1
EOF
chmod +x "$FAKE_TOOLS_DIR/mv"

set +e
TMPDIR='/' PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
OUTPUT_DIR="$OUTPUT_DIR" \
APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT" \
DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
FLUTTER_CMD=/usr/bin/true \
"$TARGET_SCRIPT" >/tmp/test_packaging_build_appimage_tmpdir_root_fallback_move_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when mv exits non-zero" >&2
  cat /tmp/test_packaging_build_appimage_tmpdir_root_fallback_move_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudtolocalllm-appimage.' "$TMP_LOG"; then
  echo "Expected AppImage workdir to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

workdir_path="$(awk -F ' => ' '/cloudtolocalllm-appimage/ {print $2; exit}' "$TMP_LOG")"
if [[ -z "$workdir_path" ]]; then
  echo "Expected to capture AppImage workdir path" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if ! grep -Fq "$workdir_path/appimagetool-download." "$TMP_LOG"; then
  echo "Expected appimagetool download temp file to live under the normalized AppImage workdir" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

download_tmp="$(awk -F ' => ' '/appimagetool-download/ {print $2; exit}' "$TMP_LOG")"
if [[ -z "$download_tmp" ]]; then
  echo "Expected to capture the appimagetool download temp file path" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if [[ -e "$download_tmp" ]]; then
  echo "Expected failed mv cleanup for the downloaded appimagetool" >&2
  printf '%s\n' "$download_tmp" >&2
  exit 1
fi

if [[ -d "$workdir_path" ]]; then
  echo "Expected AppImage workdir cleanup after mv failure" >&2
  printf '%s\n' "$workdir_path" >&2
  exit 1
fi

if [[ -e "$APPIMAGE_OUTPUT" ]]; then
  echo "Expected failed AppImage output cleanup" >&2
  cat /tmp/test_packaging_build_appimage_tmpdir_root_fallback_move_cleanup.log >&2
  exit 1
fi

if [[ -s "$LOG_FILE" ]]; then
  :
fi

echo "[test_packaging_build_appimage_tmpdir_root_fallback_move_cleanup] Passed"
