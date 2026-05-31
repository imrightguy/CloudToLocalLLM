#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_TOOLS_DIR="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT="$(mktemp -u /tmp/cloudtolocalllm-appimage.XXXXXX.AppImage)"
TMP_DESKTOP_TEMPLATE="$(mktemp)"
TMP_INSTALL_BIN="$TMP_HOME/.local/bin/cloudtolocalllm"
TMP_DESKTOP_ENTRY="$TMP_HOME/.local/share/applications/cloudtolocalllm-appimage.desktop"

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

cat > "$TMP_TOOLS_DIR/chmod" <<'EOF'
#!/bin/bash
set -euo pipefail
for arg in "$@"; do
  if [[ "$arg" == "$TMP_INSTALL_BIN" ]]; then
    echo "[fake-chmod] failing intentionally for $TMP_INSTALL_BIN" >&2
    exit 1
  fi
done
exec /bin/chmod "$@"
EOF
chmod +x "$TMP_TOOLS_DIR/chmod"

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
Comment=Failure cleanup test desktop entry
Terminal=false
EOF

set +e
PATH="$TMP_TOOLS_DIR:/usr/bin:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
FLUTTER_CMD=/usr/bin/true \
"$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_failure_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when chmod exits non-zero during install" >&2
  cat /tmp/test_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -d "$TMP_WORKDIR" ]]; then
  echo "Expected temporary AppImage workdir cleanup after failure, but $TMP_WORKDIR still exists" >&2
  cat /tmp/test_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -f "$TMP_OUTPUT" ]]; then
  echo "Expected failed AppImage output cleanup, but $TMP_OUTPUT still exists" >&2
  cat /tmp/test_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -e "$TMP_INSTALL_BIN" ]]; then
  echo "Expected failed AppImage install cleanup, but $TMP_INSTALL_BIN still exists" >&2
  cat /tmp/test_build_appimage_failure_cleanup.log >&2
  exit 1
fi

if [[ -e "$TMP_DESKTOP_ENTRY" ]]; then
  echo "Expected failed AppImage desktop entry cleanup, but $TMP_DESKTOP_ENTRY still exists" >&2
  cat /tmp/test_build_appimage_failure_cleanup.log >&2
  exit 1
fi

echo "[test_build_appimage_failure_cleanup] Passed"
