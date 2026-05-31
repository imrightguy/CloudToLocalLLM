#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMPDIR_BASE="$(mktemp -d)"
TMPDIR_ROOT="$TMPDIR_BASE/nested/tmp/dir"
TMP_OUTPUT="$TMPDIR_ROOT/CloudToLocalLLM-x86_64.AppImage"
TMP_DESKTOP_TEMPLATE="$(mktemp)"
TMP_INVOKE_LOG="$(mktemp /tmp/appimage-tmpdir-default-invoke.XXXXXX.log)"
export TMP_INVOKE_LOG

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_WORKDIR" "$TMPDIR_BASE"
  rm -f "$TMP_DESKTOP_TEMPLATE" "$TMP_INVOKE_LOG"
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
Comment=Default TMPDIR smoke test desktop entry
Terminal=false
EOF

mkdir -p "$TMP_WORKDIR"
cat > "$TMP_WORKDIR/appimagetool-x86_64.AppImage" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "\$0 \$*" >> "$TMP_INVOKE_LOG"
appdir="\$1"
out="\$2"
cp "\$appdir/AppRun" "\$out"
chmod +x "\$out"
EOF
chmod +x "$TMP_WORKDIR/appimagetool-x86_64.AppImage"

TMPDIR="$TMPDIR_ROOT" \
PATH="/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
TMP_INVOKE_LOG="$TMP_INVOKE_LOG" \
FLUTTER_CMD=/usr/bin/true \
"$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_tmpdir_default_output.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected default TMPDIR AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_build_appimage_tmpdir_default_output.log >&2
  exit 1
fi

if [[ ! -x "$TMP_HOME/.local/bin/cloudtolocalllm" ]]; then
  echo "Expected installed AppImage binary in temp HOME" >&2
  cat /tmp/test_build_appimage_tmpdir_default_output.log >&2
  exit 1
fi

if ! grep -q 'appimagetool-x86_64.AppImage' "$TMP_INVOKE_LOG"; then
  echo "Expected local appimagetool fallback to be invoked" >&2
  cat /tmp/test_build_appimage_tmpdir_default_output.log >&2
  exit 1
fi

echo "[test_build_appimage_tmpdir_default_output] Passed"
