#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/build-appimage.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
DIST_DIR="$WORK_DIR/dist"
LOG_FILE="$WORK_DIR/output.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$DIST_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_TOOLS_DIR/appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
appdir="$1"
out="$2"
cp "$appdir/AppRun" "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_TOOLS_DIR/appimagetool"

MISSING_PUBSPEC="$WORK_DIR/missing-pubspec.yaml"

set +e
PATH="$FAKE_TOOLS_DIR:$PATH" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
PUBSPEC_FILE="$MISSING_PUBSPEC" \
FLUTTER_CMD=/usr/bin/true \
bash "$TARGET_SCRIPT" > "$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when PUBSPEC_FILE is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "pubspec.yaml not found" "$LOG_FILE"; then
  echo "Expected missing pubspec error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if compgen -G "$DIST_DIR/*.AppImage" >/dev/null; then
  echo "Expected no AppImage output when pubspec is missing" >&2
  ls -l "$DIST_DIR" >&2
  exit 1
fi

echo "[test_build_appimage_missing_pubspec_guard] Passed"
