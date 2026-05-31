#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
TMPDIR_ROOT="$WORK_DIR/tmp dir with spaces/base/inner"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_DIST_DIR="$FAKE_ROOT/dist/linux"
FAKE_TOOLS="$WORK_DIR/bin"
FAKE_VERSION_MANAGER="$WORK_DIR/version manager.sh"
FAKE_FLUTTER="$WORK_DIR/flutter wrapper.sh"
FAKE_BUILD_APPIMAGE="$WORK_DIR/build appimage.sh"
APP_CONFIG_FILE="$FAKE_ROOT/lib/config/app_config.dart"
VERSION_JSON_FILE="$FAKE_ROOT/assets/version.json"
LOG_FILE="$WORK_DIR/invocations.log"
mkdir -p "$FAKE_ROOT/lib/config" "$FAKE_ROOT/assets" "$FAKE_BUILD_DIR" "$FAKE_DIST_DIR" "$FAKE_TOOLS" "$TMPDIR_ROOT"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$APP_CONFIG_FILE" <<'EOF'
class AppConfig {
  static const String appVersion = 'old';
}
EOF

cat > "$FAKE_VERSION_MANAGER" <<'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  get-semantic) printf '%s\n' '10.1.200' ;;
  get) printf '%s\n' '10.1.200+4200' ;;
  get-build) printf '%s\n' '4200' ;;
  validate) exit 0 ;;
  increment) exit 0 ;;
  *) echo "unexpected version_manager call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$FAKE_VERSION_MANAGER"

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter %s\n' "$*" >> "$LOG_FILE"
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
case "${1:-}" in
  clean|pub)
    exit 0
    ;;
  build)
    if [[ "${2:-}" == "linux" ]]; then
      mkdir -p "$proj_root/build/linux/x64/release/bundle"
      cat > "$proj_root/build/linux/x64/release/bundle/cloudtolocalllm" <<'APP'
#!/bin/sh
exit 0
APP
      chmod +x "$proj_root/build/linux/x64/release/bundle/cloudtolocalllm"
      exit 0
    fi
    ;;
esac
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

cat > "$FAKE_BUILD_APPIMAGE" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'build_appimage %s\n' "$*" >> "$LOG_FILE"
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
mkdir -p "$proj_root/dist/linux"
printf '%s\n' 'appimage' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
printf '%s\n' 'checksum' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage.sha256"
EOF
chmod +x "$FAKE_BUILD_APPIMAGE"

PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
TMPDIR="$TMPDIR_ROOT////" \
VERSION_MANAGER_SCRIPT="$FAKE_VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_APPIMAGE" \
"$TARGET_SCRIPT" --skip-increment >/tmp/test_build_all_packages_project_root_and_tmpdir_spaces.log 2>&1

APPIMAGE_FILE="$FAKE_DIST_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage"
APPIMAGE_SHA="$APPIMAGE_FILE.sha256"

if [[ ! -f "$APPIMAGE_FILE" ]]; then
  echo "Expected AppImage at $APPIMAGE_FILE" >&2
  cat /tmp/test_build_all_packages_project_root_and_tmpdir_spaces.log >&2
  exit 1
fi

if [[ ! -f "$APPIMAGE_SHA" ]]; then
  echo "Expected AppImage checksum at $APPIMAGE_SHA" >&2
  cat /tmp/test_build_all_packages_project_root_and_tmpdir_spaces.log >&2
  exit 1
fi

if ! grep -Fq "static const String appVersion = '10.1.200';" "$APP_CONFIG_FILE"; then
  echo "Expected app_config.dart version update" >&2
  cat "$APP_CONFIG_FILE" >&2
  exit 1
fi

if ! grep -Fq '"version": "10.1.200"' "$VERSION_JSON_FILE"; then
  echo "Expected version.json semantic version update" >&2
  cat "$VERSION_JSON_FILE" >&2
  exit 1
fi

if find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'package-backup.*' | grep -q .; then
  echo "Expected temporary package backup dirs to be cleaned up under spaced TMPDIR root" >&2
  find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'package-backup.*' >&2
  exit 1
fi

if ! grep -Fq 'flutter build linux --release' "$LOG_FILE"; then
  echo "Expected fake flutter build to run" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'build_appimage' "$LOG_FILE"; then
  echo "Expected fake build_appimage to run" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_build_all_packages_project_root_and_tmpdir_spaces] Passed"
