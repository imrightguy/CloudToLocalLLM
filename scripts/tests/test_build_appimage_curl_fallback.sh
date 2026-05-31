#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT_DIR="$(mktemp -d)"
TMP_OUTPUT="$TMP_OUTPUT_DIR/nested/cloudtolocalllm-curl-fallback.AppImage"
TMP_DESKTOP_TEMPLATE="$(mktemp)"
TMP_INVOKE_LOG="$(mktemp /tmp/appimage-curl-fallback-invoke.XXXXXX.log)"
BIN_DIR="$TMP_WORKDIR/bin"
mkdir -p "$BIN_DIR"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_WORKDIR" "$TMP_OUTPUT_DIR"
  rm -f "$TMP_DESKTOP_TEMPLATE"
  rm -f "$TMP_INVOKE_LOG"
}
trap cleanup EXIT

mkdir -p "$TMP_BUILD_DIR"
printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Curl fallback smoke test desktop entry
Terminal=false
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
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
if [[ -z "$out" ]]; then
  echo "curl stub missing -o output" >&2
  exit 1
fi
cp "$FAKE_APPIMAGETOOL_TEMPLATE" "$out"
chmod +x "$out"
printf '%s\n' "$out" >> "$TMP_INVOKE_LOG"
EOF
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/fake-appimagetool-template" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "appimagetool $*" >> "$TMP_INVOKE_LOG"
appdir="$1"
out="$2"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$BIN_DIR/fake-appimagetool-template"

PATH="$BIN_DIR:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
TMP_INVOKE_LOG="$TMP_INVOKE_LOG" \
FAKE_APPIMAGETOOL_TEMPLATE="$BIN_DIR/fake-appimagetool-template" \
FLUTTER_CMD=/usr/bin/true \
"$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_curl_fallback.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected fallback AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_build_appimage_curl_fallback.log >&2
  exit 1
fi

if [[ ! -x "$TMP_HOME/.local/bin/cloudtolocalllm" ]]; then
  echo "Expected installed AppImage binary in temp HOME" >&2
  cat /tmp/test_build_appimage_curl_fallback.log >&2
  exit 1
fi

if ! grep -q "$TMP_WORKDIR/" "$TMP_INVOKE_LOG"; then
  echo "Expected curl fallback to download appimagetool into the workdir" >&2
  cat /tmp/test_build_appimage_curl_fallback.log >&2
  exit 1
fi

if ! grep -q '^appimagetool ' "$TMP_INVOKE_LOG"; then
  echo "Expected downloaded appimagetool to be invoked" >&2
  cat /tmp/test_build_appimage_curl_fallback.log >&2
  exit 1
fi

echo "[test_build_appimage_curl_fallback] Passed"
