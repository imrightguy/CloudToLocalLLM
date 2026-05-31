#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_BIN="$WORK_DIR/bin"
VERSION_MANAGER_DIR="$WORK_DIR/version manager dir"
BUILD_APPIMAGE_DIR="$WORK_DIR/build appimage dir"
VERSION_MANAGER="$VERSION_MANAGER_DIR/version_manager.sh"
FAKE_FLUTTER="$WORK_DIR/flutter wrapper.sh"
FAKE_BUILD_APPIMAGE="$BUILD_APPIMAGE_DIR/build_appimage.sh"
APP_CONFIG_FILE="$FAKE_ROOT/lib/config/app_config.dart"
VERSION_JSON_FILE="$FAKE_ROOT/assets/version.json"
GIT_LOG="$WORK_DIR/git.log"
FLUTTER_LOG="$WORK_DIR/flutter.log"
APPIMAGE_LOG="$WORK_DIR/appimage.log"
mkdir -p "$FAKE_ROOT/lib/config" "$FAKE_ROOT/assets" "$FAKE_BUILD_DIR" "$FAKE_ROOT/dist/linux" "$FAKE_BIN" "$VERSION_MANAGER_DIR" "$BUILD_APPIMAGE_DIR"
export GIT_LOG FLUTTER_LOG APPIMAGE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$VERSION_MANAGER" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "${APPIMAGE_LOG:?missing APPIMAGE_LOG}"
case "${1:-}" in
  get-semantic) echo 10.1.200 ;;
  get) echo 10.1.200+4200 ;;
  get-build) echo 4200 ;;
  validate) exit 0 ;;
  increment) exit 0 ;;
  *) echo "unexpected version_manager command: ${1:-}" >&2; exit 1 ;;
esac
EOF
chmod +x "$VERSION_MANAGER"

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "${FLUTTER_LOG:?missing FLUTTER_LOG}"
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
case "${1:-}" in
  clean|pub)
    exit 0
    ;;
  build)
    if [[ "${2:-}" == "linux" ]]; then
      mkdir -p "$proj_root/build/linux/x64/release/bundle"
      printf '%s\n' '#!/bin/sh' 'echo bundle-ok' > "$proj_root/build/linux/x64/release/bundle/cloudtolocalllm"
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
printf '%s\n' "$0 $*" >> "${APPIMAGE_LOG:?missing APPIMAGE_LOG}"
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
mkdir -p "$proj_root/dist/linux"
printf '%s\n' 'appimage-built' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
printf '%s\n' 'checksum-built' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage.sha256"
chmod +x "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
exit 0
EOF
chmod +x "$FAKE_BUILD_APPIMAGE"

cat > "$FAKE_BIN/git" <<EOF
#!/bin/bash
set -euo pipefail
echo "git:\$*" >> "$GIT_LOG"
if [[ "\${1:-}" == "-C" && "\${2:-}" == "$FAKE_ROOT" && "\${3:-}" == "rev-parse" && "\${4:-}" == "--short" && "\${5:-}" == "HEAD" ]]; then
  echo feedface
  exit 0
fi
echo "unexpected git invocation: \$*" >&2
exit 1
EOF
chmod +x "$FAKE_BIN/git"

printf '%s\n' 'class AppConfig {\n  static const String appVersion = '\''0.0.0'\'';\n}\n' > "$APP_CONFIG_FILE"
printf '%s\n' '{"version":"0.0.0","build_number":"0"}' > "$VERSION_JSON_FILE"

cd /tmp
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_APPIMAGE" \
PATH="$FAKE_BIN:$PATH" \
"$PROJECT_ROOT/scripts/packaging/build_all_packages.sh" --packages appimage >/tmp/test_build_all_packages_command_paths_spaces.log 2>&1

if ! grep -Fq "static const String appVersion = '10.1.200';" "$APP_CONFIG_FILE"; then
  echo "app_config.dart did not retain the expected version update" >&2
  cat /tmp/test_build_all_packages_command_paths_spaces.log >&2
  exit 1
fi

if ! grep -Fq '"git_commit": "feedface"' "$VERSION_JSON_FILE"; then
  echo "version.json did not record the project-root git commit" >&2
  cat /tmp/test_build_all_packages_command_paths_spaces.log >&2
  exit 1
fi

if ! grep -Fq "$VERSION_MANAGER" "$APPIMAGE_LOG"; then
  echo "Expected spaced VERSION_MANAGER_SCRIPT path to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fq "$FAKE_BUILD_APPIMAGE" "$APPIMAGE_LOG"; then
  echo "Expected spaced BUILD_APPIMAGE_CMD path to be invoked" >&2
  cat "$APPIMAGE_LOG" >&2
  exit 1
fi

if [[ ! -f "$FAKE_ROOT/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Expected final AppImage artifact on success" >&2
  cat /tmp/test_build_all_packages_command_paths_spaces.log >&2
  exit 1
fi

echo "[test_build_all_packages_command_paths_spaces] Passed"
