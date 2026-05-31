#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
TMP_HOME="$WORK_DIR/home"
TMP_BUILD_DIR="$WORK_DIR/build/linux/x64/release/bundle"
TMP_TOOLS_DIR="$WORK_DIR/bin"
TMP_OUTPUT="$WORK_DIR/output/CloudToLocalLLM-x86_64.AppImage"
TMP_DESKTOP_TEMPLATE="$WORK_DIR/cloudtolocalllm.desktop"
TMP_LOG="$WORK_DIR/mktemp.log"
mkdir -p "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_TOOLS_DIR" "$(dirname "$TMP_OUTPUT")"
export TMP_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Tmpdir root fallback install cleanup test desktop entry
Terminal=false
EOF

cat > "$TMP_TOOLS_DIR/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
result="$(/usr/bin/mktemp "$@")"
printf '%s => %s\n' "$*" "$result" >> "$TMP_LOG"
printf '%s\n' "$result"
EOF
chmod +x "$TMP_TOOLS_DIR/mktemp"

cat > "$TMP_TOOLS_DIR/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
appdir="$1"
out="$2"
if [[ ! -f "$appdir/AppRun" ]]; then
  echo "missing AppRun in $appdir" >&2
  exit 1
fi
mkdir -p "$(dirname "$out")"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
exit 0
EOF
chmod +x "$TMP_TOOLS_DIR/appimagetool"

cat > "$TMP_TOOLS_DIR/chmod" <<'EOF'
#!/bin/bash
set -euo pipefail
for arg in "$@"; do
  if [[ "$arg" == "$HOME/.local/bin/cloudtolocalllm" ]]; then
    echo "[fake-chmod] failing intentionally for $arg" >&2
    exit 1
  fi
done
exec /bin/chmod "$@"
EOF
chmod +x "$TMP_TOOLS_DIR/chmod"

set +e
TMPDIR='/' \
PATH="$TMP_TOOLS_DIR:/usr/bin:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
FLUTTER_CMD=/usr/bin/true \
"$PROJECT_ROOT/scripts/build-appimage.sh" >"$WORK_DIR/output.log" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when chmod exits non-zero during install" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudtolocalllm-appimage.' "$TMP_LOG"; then
  echo "Expected APPIMAGE_WORKDIR to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

workdir_path="$(awk -F ' => ' '/cloudtolocalllm-appimage/ {print $2; exit}' "$TMP_LOG")"
if [[ -z "$workdir_path" ]]; then
  echo "Expected to capture AppImage workdir path" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if [[ -d "$workdir_path" ]]; then
  echo "Expected AppImage workdir cleanup after install failure" >&2
  printf '%s\n' "$workdir_path" >&2
  exit 1
fi

if [[ -e "$TMP_OUTPUT" ]]; then
  echo "Expected failed AppImage output cleanup" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

install_bin="$TMP_HOME/.local/bin/cloudtolocalllm"
if [[ -e "$install_bin" ]]; then
  echo "Expected failed AppImage install cleanup" >&2
  printf '%s\n' "$install_bin" >&2
  exit 1
fi

if [[ -e "$TMP_HOME/.local/share/applications/cloudtolocalllm-appimage.desktop" ]]; then
  echo "Expected desktop entry cleanup to keep failure side effects minimal" >&2
  find "$TMP_HOME/.local/share/applications" -maxdepth 1 -type f -print >&2
  exit 1
fi

echo "[test_build_appimage_tmpdir_root_fallback_install_cleanup] Passed"
