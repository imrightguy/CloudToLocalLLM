#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/build-appimage.sh"
WORK_DIR="$(mktemp -d)"
BUILD_DIR="$WORK_DIR/bundle"
PUBSPEC_DIR="$WORK_DIR/pubspec-dir"
DIST_DIR="$WORK_DIR/dist"
mkdir -p "$BUILD_DIR" "$PUBSPEC_DIR" "$DIST_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$BUILD_DIR/cloudtolocalllm"

set +e
BUILD_DIR="$BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
PUBSPEC_FILE="$PUBSPEC_DIR" \
FLUTTER_CMD=/usr/bin/true \
APPIMAGETOOL_CMD=/usr/bin/true \
"$TARGET_SCRIPT" >/tmp/test_build_appimage_pubspec_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when PUBSPEC_FILE is a directory" >&2
  cat /tmp/test_build_appimage_pubspec_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'pubspec.yaml must not be a directory' /tmp/test_build_appimage_pubspec_directory_guard.log; then
  echo "Missing PUBSPEC_FILE directory validation message" >&2
  cat /tmp/test_build_appimage_pubspec_directory_guard.log >&2
  exit 1
fi

echo "[test_build_appimage_pubspec_directory_guard] Passed"
