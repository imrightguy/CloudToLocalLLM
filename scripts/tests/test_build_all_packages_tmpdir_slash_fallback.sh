#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_TOOLS="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/invocations.log"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_DIST_DIR="$FAKE_ROOT/dist/linux"
FAKE_APPIMAGE="$FAKE_DIST_DIR/cloudtolocalllm-2.3.4-x86_64.AppImage"
FAKE_VERSION_MANAGER="$WORK_DIR/version_manager.sh"
FAKE_FLUTTER="$WORK_DIR/flutter.sh"
FAKE_BUILD_APPIMAGE="$WORK_DIR/build_appimage.sh"
export LOG_FILE FAKE_BUILD_DIR FAKE_DIST_DIR FAKE_APPIMAGE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_ROOT/lib/config" "$FAKE_BUILD_DIR" "$FAKE_DIST_DIR" "$FAKE_TOOLS"

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 2.3.4+5
EOF

cat > "$FAKE_ROOT/lib/config/app_config.dart" <<'EOF'
class AppConfig {
  static const String appVersion = 'old';
}
EOF

cat > "$FAKE_VERSION_MANAGER" <<'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  get-semantic) printf '%s\n' '2.3.4' ;;
  get) printf '%s\n' '2.3.4+5' ;;
  get-build) printf '%s\n' '5' ;;
  validate) exit 0 ;;
  increment) echo "unexpected increment call" >&2; exit 1 ;;
  *) echo "unexpected version_manager call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$FAKE_VERSION_MANAGER"

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter %s\n' "$*" >> "$LOG_FILE"
case "$*" in
  *'build linux --release'*)
    mkdir -p "$FAKE_BUILD_DIR"
    cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'APP'
#!/bin/sh
exit 0
APP
    chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"
    ;;
esac
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

cat > "$FAKE_BUILD_APPIMAGE" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'build_appimage %s\n' "$*" >> "$LOG_FILE"
mkdir -p "$FAKE_DIST_DIR"
printf 'appimage\n' > "$FAKE_APPIMAGE"
printf 'checksum\n' > "$FAKE_APPIMAGE.sha256"
EOF
chmod +x "$FAKE_BUILD_APPIMAGE"

TMPDIR="/" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
VERSION_MANAGER_SCRIPT="$FAKE_VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_APPIMAGE" \
"$PROJECT_ROOT/scripts/packaging/build_all_packages.sh" --skip-increment >/tmp/test_build_all_packages_tmpdir_slash_fallback.log 2>&1

if [[ ! -f "$FAKE_APPIMAGE" ]]; then
  echo "Expected AppImage at $FAKE_APPIMAGE" >&2
  cat /tmp/test_build_all_packages_tmpdir_slash_fallback.log >&2
  exit 1
fi

if [[ ! -f "$FAKE_APPIMAGE.sha256" ]]; then
  echo "Expected AppImage checksum at $FAKE_APPIMAGE.sha256" >&2
  cat /tmp/test_build_all_packages_tmpdir_slash_fallback.log >&2
  exit 1
fi

if ! grep -q 'build linux --release' "$LOG_FILE"; then
  echo "Expected fake flutter build to run" >&2
  cat /tmp/test_build_all_packages_tmpdir_slash_fallback.log >&2
  exit 1
fi

if ! grep -q 'build_appimage' "$LOG_FILE"; then
  echo "Expected fake build_appimage to run" >&2
  cat /tmp/test_build_all_packages_tmpdir_slash_fallback.log >&2
  exit 1
fi

echo "[test_build_all_packages_tmpdir_slash_fallback] Passed"
