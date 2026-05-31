#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
FAKE_TOOLS="$WORK_DIR/bin"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_DIST_DIR="$FAKE_ROOT/dist/linux"
FAKE_VERSION_MANAGER="$WORK_DIR/version manager.sh"
FAKE_FLUTTER="$WORK_DIR/flutter wrapper.sh"
FAKE_BUILD_APPIMAGE="$WORK_DIR/build appimage.sh"
APP_CONFIG_FILE="$FAKE_ROOT/lib/config/app_config.dart"
VERSION_JSON_FILE="$FAKE_ROOT/assets/version.json"
MKTEMP_LOG="$WORK_DIR/mktemp.log"
LOG_FILE="$WORK_DIR/run.log"
mkdir -p "$FAKE_ROOT/lib/config" "$FAKE_ROOT/assets" "$FAKE_BUILD_DIR" "$FAKE_DIST_DIR" "$FAKE_TOOLS"
export MKTEMP_LOG LOG_FILE

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

cat > "$VERSION_JSON_FILE" <<'EOF'
{"version":"old","build_number":"0"}
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

cat > "$FAKE_TOOLS/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
result="$(/usr/bin/mktemp "$@")"
printf '%s => %s\n' "$*" "$result" >> "$MKTEMP_LOG"
printf '%s\n' "$result"
EOF
chmod +x "$FAKE_TOOLS/mktemp"

cat > "$FAKE_TOOLS/git" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${1:-}" == "-C" && "${2:-}" == *"project root with spaces"* && "${3:-}" == "rev-parse" && "${4:-}" == "--short" && "${5:-}" == "HEAD" ]]; then
  echo feedface
  exit 0
fi
echo "unexpected git invocation: $*" >&2
exit 1
EOF
chmod +x "$FAKE_TOOLS/git"

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$LOG_FILE"
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
printf '%s\n' "$0 $*" >> "$LOG_FILE"
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
mkdir -p "$proj_root/dist/linux"
printf '%s\n' 'appimage' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
printf '%s\n' 'checksum' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage.sha256"
exit 0
EOF
chmod +x "$FAKE_BUILD_APPIMAGE"

TMPDIR='/' \
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
VERSION_MANAGER_SCRIPT="$FAKE_VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_APPIMAGE" \
"$TARGET_SCRIPT" --skip-increment >"$WORK_DIR/output.log" 2>&1

APPIMAGE_FILE="$FAKE_DIST_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage"
APPIMAGE_SHA="$APPIMAGE_FILE.sha256"

if [[ ! -f "$APPIMAGE_FILE" ]]; then
  echo "Expected AppImage at $APPIMAGE_FILE" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if [[ ! -f "$APPIMAGE_SHA" ]]; then
  echo "Expected AppImage checksum at $APPIMAGE_SHA" >&2
  cat "$WORK_DIR/output.log" >&2
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

if ! grep -Fq '/tmp/package-backup.' "$MKTEMP_LOG"; then
  echo "Expected TMPDIR=/ to normalize package backup files under /tmp" >&2
  cat "$MKTEMP_LOG" >&2
  exit 1
fi

while IFS= read -r tmpfile; do
  [[ -n "$tmpfile" ]] || continue
  if [[ -e "$tmpfile" ]]; then
    echo "Expected temp file cleanup after success: $tmpfile" >&2
    cat "$MKTEMP_LOG" >&2
    exit 1
  fi
done < <(awk -F ' => ' '{print $2}' "$MKTEMP_LOG")

if find "$FAKE_ROOT" -maxdepth 1 -type d -name 'package-backup.*' | grep -q .; then
  echo "Expected package backup dirs to be cleaned up after success" >&2
  find "$FAKE_ROOT" -maxdepth 1 -type d -name 'package-backup.*' >&2
  exit 1
fi

if ! grep -Fq 'build linux --release' "$LOG_FILE"; then
  echo "Expected fake flutter build to run" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'build appimage.sh' "$LOG_FILE"; then
  echo "Expected fake build_appimage to run" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_build_all_packages_project_root_spaces_tmpdir_root_fallback] Passed"
