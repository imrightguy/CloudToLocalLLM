#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_TOOLS_DIR="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT="$(mktemp -u /tmp/cloudtolocalllm-appimage.XXXXXX.AppImage)"
TMP_DESKTOP_TEMPLATE="$(mktemp)"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_TOOLS_DIR" "$TMP_WORKDIR"
  rm -f "$TMP_OUTPUT" "$TMP_DESKTOP_TEMPLATE"
}
trap cleanup EXIT

cat > "$TMP_TOOLS_DIR/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
appdir="$1"
out="$2"
shift 2
if [[ ! -f "$appdir/AppRun" ]]; then
  echo "missing AppRun in $appdir" >&2
  exit 1
fi
cp "$appdir/AppRun" "$out"
chmod +x "$out"
echo "[fake-appimagetool] built $out"
EOF
chmod +x "$TMP_TOOLS_DIR/appimagetool"

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
Comment=Smoke test desktop entry
Terminal=false
EOF

PATH="$TMP_TOOLS_DIR:/usr/bin:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
FLUTTER_CMD=/usr/bin/true \
"$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_smoke.log 2>&1

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Expected AppImage output at $TMP_OUTPUT" >&2
  cat /tmp/test_build_appimage_smoke.log >&2
  exit 1
fi

if [[ -e "$TMP_WORKDIR" ]]; then
  echo "Expected temporary AppImage workdir to be cleaned up: $TMP_WORKDIR" >&2
  cat /tmp/test_build_appimage_smoke.log >&2
  exit 1
fi

if [[ ! -x "$TMP_HOME/.local/bin/cloudtolocalllm" ]]; then
  echo "Expected installed AppImage binary in temp HOME" >&2
  cat /tmp/test_build_appimage_smoke.log >&2
  exit 1
fi

if [[ ! -f "$TMP_HOME/.local/share/applications/cloudtolocalllm-appimage.desktop" ]]; then
  echo "Expected desktop entry in temp HOME" >&2
  cat /tmp/test_build_appimage_smoke.log >&2
  exit 1
fi

echo "[test_build_appimage_smoke] Passed"
