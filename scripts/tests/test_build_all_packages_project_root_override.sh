#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
SCRIPT_COPY_DIR="$WORK_DIR/scripts/packaging"
FAKE_BIN="$WORK_DIR/bin"
VERSION_MANAGER="$WORK_DIR/version_manager.sh"
FAKE_BUILD_SCRIPT="$WORK_DIR/fake_build_appimage.sh"
APP_CONFIG_FILE="$TMP_ROOT/lib/config/app_config.dart"
VERSION_JSON_FILE="$TMP_ROOT/assets/version.json"
GIT_LOG="$WORK_DIR/git.log"
mkdir -p "$TMP_ROOT/lib/config" "$TMP_ROOT/assets" "$TMP_ROOT/build/linux/x64/release/bundle" "$TMP_ROOT/dist/linux" "$SCRIPT_COPY_DIR" "$FAKE_BIN"

cat > "$TMP_ROOT/pubspec.yaml" <<'EOF'
name: temp_app
version: 10.1.200+4200
EOF

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$TARGET_SCRIPT" "$SCRIPT_COPY_DIR/build_all_packages.sh"
chmod +x "$SCRIPT_COPY_DIR/build_all_packages.sh"

cat > "$VERSION_MANAGER" <<'EOF'
#!/bin/bash
set -euo pipefail
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

cat > "$TMP_ROOT/fake_flutter.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
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
chmod +x "$TMP_ROOT/fake_flutter.sh"

cat > "$TMP_ROOT/fake_build_appimage.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
mkdir -p "$proj_root/dist/linux"
printf '%s\n' 'appimage-built' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
printf '%s\n' 'checksum-built' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage.sha256"
chmod +x "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
exit 0
EOF
chmod +x "$TMP_ROOT/fake_build_appimage.sh"

cat > "$FAKE_BIN/git" <<EOF
#!/bin/bash
set -euo pipefail
echo "git:\$*" >> "$GIT_LOG"
if [[ "\${1:-}" == "-C" && "\${2:-}" == "$TMP_ROOT" && "\${3:-}" == "rev-parse" && "\${4:-}" == "--short" && "\${5:-}" == "HEAD" ]]; then
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
SCRIPT_DIR_OVERRIDE="$SCRIPT_COPY_DIR" \
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$TMP_ROOT/fake_flutter.sh" \
BUILD_APPIMAGE_CMD="$TMP_ROOT/fake_build_appimage.sh" \
PATH="$FAKE_BIN:$PATH" \
"$SCRIPT_COPY_DIR/build_all_packages.sh" --packages appimage >/tmp/test_build_all_packages_project_root_override.log 2>&1

if ! grep -Fq "static const String appVersion = '10.1.200';" "$APP_CONFIG_FILE"; then
  echo "app_config.dart did not retain the expected version update" >&2
  cat /tmp/test_build_all_packages_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '"git_commit": "feedface"' "$VERSION_JSON_FILE"; then
  echo "version.json did not record the project-root git commit" >&2
  cat /tmp/test_build_all_packages_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq "git:-C $TMP_ROOT rev-parse --short HEAD" "$GIT_LOG"; then
  echo "Expected git -C override-root invocation" >&2
  cat "$GIT_LOG" >&2
  exit 1
fi

if [[ ! -f "$TMP_ROOT/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Expected final AppImage artifact on success" >&2
  cat /tmp/test_build_all_packages_project_root_override.log >&2
  exit 1
fi

echo "[test_build_all_packages_project_root_override] Passed"
