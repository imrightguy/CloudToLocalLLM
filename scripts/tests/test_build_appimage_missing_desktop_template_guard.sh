#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_DIR="$(mktemp -d)"
TMP_WORKDIR="$(mktemp -d)"
TMP_OUTPUT="$(mktemp -u /tmp/cloudtolocalllm-appimage-missing-template.XXXXXX.AppImage)"
TMP_PUBSPEC="$(mktemp)"
LOG_FILE="/tmp/test_build_appimage_missing_desktop_template_guard.log"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BUILD_DIR" "$TMP_WORKDIR"
  rm -f "$TMP_OUTPUT" "$TMP_PUBSPEC"
}
trap cleanup EXIT

cat > "$TMP_WORKDIR/flutter" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF
chmod +x "$TMP_WORKDIR/flutter"

printf '%s\n' 'name: cloudtolocalllm' > "$TMP_PUBSPEC"
printf '%s\n' '#!/bin/sh' 'echo packaged-ok' > "$TMP_BUILD_DIR/cloudtolocalllm"
chmod +x "$TMP_BUILD_DIR/cloudtolocalllm"

set +e
PATH="/usr/bin:/bin" \
HOME="$TMP_HOME" \
PUBSPEC_FILE="$TMP_PUBSPEC" \
BUILD_DIR="$TMP_BUILD_DIR" \
APPIMAGE_WORKDIR="$TMP_WORKDIR/work" \
APPIMAGE_OUTPUT="$TMP_OUTPUT" \
DESKTOP_TEMPLATE="$TMP_WORKDIR/missing.desktop" \
FLUTTER_CMD="$TMP_WORKDIR/flutter" \
"$PROJECT_ROOT/scripts/build-appimage.sh" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_appimage.sh to fail when DESKTOP_TEMPLATE is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "Desktop entry template not found" "$LOG_FILE"; then
  echo "Expected missing desktop template error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$TMP_OUTPUT" ]]; then
  echo "Expected no AppImage output when DESKTOP_TEMPLATE is missing" >&2
  ls -l "$TMP_OUTPUT" >&2
  exit 1
fi

echo "[test_build_appimage_missing_desktop_template_guard] Passed"
