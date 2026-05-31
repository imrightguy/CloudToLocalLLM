#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT="$(mktemp -u /tmp/cloudtolocalllm-appimage-missing-build-dir.XXXXXX.AppImage)"
TMP_DESKTOP_TEMPLATE="$(mktemp)"
LOG_FILE="/tmp/test_build_appimage_missing_build_dir_guard.log"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_WORKDIR"
  rm -f "$TMP_OUTPUT" "$TMP_DESKTOP_TEMPLATE"
}
trap cleanup EXIT

cat > "$TMP_WORKDIR/flutter" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF
chmod +x "$TMP_WORKDIR/flutter"

cat > "$TMP_DESKTOP_TEMPLATE" <<'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Development;
Comment=Missing build dir guard test desktop entry
Terminal=false
EOF

set +e
PATH="/usr/bin:/bin" \
HOME="$TMP_HOME" \
BUILD_DIR="$TMP_WORKDIR/missing-build-dir" \
APPIMAGE_WORKDIR="$TMP_WORKDIR/work" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_DESKTOP_TEMPLATE" \
FLUTTER_CMD="$TMP_WORKDIR/flutter" \
"$PROJECT_ROOT/scripts/build-appimage.sh" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when BUILD_DIR is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "Flutter Linux build directory not found" "$LOG_FILE"; then
  echo "Expected missing BUILD_DIR error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$TMP_OUTPUT" ]]; then
  echo "Expected no AppImage output when BUILD_DIR is missing" >&2
  ls -l "$TMP_OUTPUT" >&2
  exit 1
fi

echo "[test_build_appimage_missing_build_dir_guard] Passed"
