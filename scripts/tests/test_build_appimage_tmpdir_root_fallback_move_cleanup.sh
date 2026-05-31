#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
TMP_LOG="$WORK_DIR/mktemp.log"
CURL_LOG="$WORK_DIR/curl.log"
MV_LOG="$WORK_DIR/mv.log"
BUILD_DIR="$WORK_DIR/build/linux/x64/release/bundle"
APPIMAGE_OUTPUT="$WORK_DIR/output/nested/CloudToLocalLLM.AppImage"
DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
mkdir -p "$FAKE_BIN" "$BUILD_DIR" "$(dirname "$APPIMAGE_OUTPUT")"
export TMP_LOG CURL_LOG MV_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$BUILD_DIR/cloudtolocalllm"
chmod +x "$BUILD_DIR/cloudtolocalllm"

cat > "$DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Move cleanup test desktop entry
Terminal=false
EOF

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
result="$(/usr/bin/mktemp "$@")"
printf '%s => %s\n' "$*" "$result" >> "$TMP_LOG"
printf '%s\n' "$result"
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/curl" <<'EOF'
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
printf '%s\n' "$output" >> "$CURL_LOG"
cat > "$output" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
echo appimagetool-stub
SCRIPT
chmod +x "$output"
EOF
chmod +x "$FAKE_BIN/curl"

cat > "$FAKE_BIN/mv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'KEEP_WORKDIR=%s\n' "${KEEP_WORKDIR:-}" >> "$MV_LOG"
printf '%s\n' "$*" >> "$MV_LOG"
exit 1
EOF
chmod +x "$FAKE_BIN/mv"

set +e
TMPDIR='/' KEEP_WORKDIR=true PATH="$FAKE_BIN:/usr/bin:/bin" \
  BUILD_DIR="$BUILD_DIR" \
  APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT" \
  DESKTOP_TEMPLATE="$DESKTOP_TEMPLATE" \
  FLUTTER_CMD=/usr/bin/true \
  "$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_tmpdir_root_fallback_move_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when mv exits non-zero" >&2
  cat /tmp/test_build_appimage_tmpdir_root_fallback_move_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudtolocalllm-appimage.' "$TMP_LOG"; then
  echo "Expected AppImage workdir to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
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
  echo "Expected appimagetool download temp file to live under the AppImage workdir" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

move_source="$(awk -F ' => ' '/appimagetool-download/ {print $2; exit}' "$TMP_LOG")"
if [[ -z "$move_source" ]]; then
  echo "Expected to capture appimagetool download temp file path" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if [[ -e "$move_source" ]]; then
  echo "Expected failed mv path cleanup for downloaded appimagetool" >&2
  printf '%s\n' "$move_source" >&2
  exit 1
fi

if ! grep -Fq 'KEEP_WORKDIR=true' "$MV_LOG"; then
  echo "Expected KEEP_WORKDIR=true to reach the mv failure path" >&2
  cat "$MV_LOG" >&2
  exit 1
fi

if [[ -e "$APPIMAGE_OUTPUT" ]]; then
  echo "Expected failed AppImage output cleanup" >&2
  cat /tmp/test_build_appimage_tmpdir_root_fallback_move_cleanup.log >&2
  exit 1
fi

if [[ -s "$MV_LOG" ]]; then
  :
fi

echo "[test_build_appimage_tmpdir_root_fallback_move_cleanup] Passed"
