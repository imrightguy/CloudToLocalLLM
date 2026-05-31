#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_TOOLS="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/invocations.log"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_DIST_DIR="$FAKE_ROOT/dist/linux"
mkdir -p "$FAKE_ROOT/lib/config" "$FAKE_ROOT/assets" "$FAKE_BUILD_DIR" "$FAKE_DIST_DIR" "$FAKE_TOOLS"
export LOG_FILE FAKE_BUILD_DIR FAKE_DIST_DIR

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 2.3.4+5
EOF

cat > "$FAKE_ROOT/lib/config/app_config.dart" <<'EOF'
class AppConfig {
  static const String appVersion = 'old';
}
EOF

cat > "$FAKE_ROOT/assets/version.json" <<'EOF'
{"version":"old","build_number":"0"}
EOF

cat > "$FAKE_TOOLS/mv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
if [[ "$*" == *"lib/config/app_config.dart"* ]]; then
  exit 1
fi
exec /bin/mv "$@"
EOF
chmod +x "$FAKE_TOOLS/mv"

cat > "$FAKE_TOOLS/version_manager.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  get-semantic) printf '%s\n' '2.3.4' ;;
  get) printf '%s\n' '2.3.4+5' ;;
  get-build) printf '%s\n' '5' ;;
  validate) exit 0 ;;
  increment) exit 0 ;;
  *) echo "unexpected version_manager call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$FAKE_TOOLS/version_manager.sh"

cat > "$FAKE_TOOLS/flutter.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter %s\n' "$*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_TOOLS/flutter.sh"

cat > "$FAKE_TOOLS/build_appimage.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'build_appimage %s\n' "$*" >> "$LOG_FILE"
mkdir -p "$FAKE_DIST_DIR"
printf 'appimage\n' > "$FAKE_DIST_DIR/cloudtolocalllm-2.3.4-x86_64.AppImage"
printf 'checksum\n' > "$FAKE_DIST_DIR/cloudtolocalllm-2.3.4-x86_64.AppImage.sha256"
EOF
chmod +x "$FAKE_TOOLS/build_appimage.sh"

set +e
TMPDIR='/' PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
VERSION_MANAGER_SCRIPT="$FAKE_TOOLS/version_manager.sh" \
FLUTTER_CMD="$FAKE_TOOLS/flutter.sh" \
BUILD_APPIMAGE_CMD="$FAKE_TOOLS/build_appimage.sh" \
"$TARGET_SCRIPT" --packages appimage >/tmp/test_build_all_packages_tmpdir_mv_failure_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when mv fails" >&2
  cat /tmp/test_build_all_packages_tmpdir_mv_failure_cleanup.log >&2
  exit 1
fi

if ! grep -Fxq "  static const String appVersion = 'old';" "$FAKE_ROOT/lib/config/app_config.dart"; then
  echo "Expected app_config.dart to be restored after mv failure" >&2
  cat /tmp/test_build_all_packages_tmpdir_mv_failure_cleanup.log >&2
  cat "$FAKE_ROOT/lib/config/app_config.dart" >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/lib/config/.tmp.app-config.*" > /dev/null; then
  echo "Expected app config temp file cleanup after mv failure" >&2
  ls -1 "$FAKE_ROOT/lib/config" >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/assets/.version.json.*" > /dev/null; then
  echo "Version.json temp file should not exist after early mv failure" >&2
  ls -1 "$FAKE_ROOT/assets" >&2
  exit 1
fi

if ! grep -Fq 'lib/config/app_config.dart' "$LOG_FILE"; then
  echo "Expected mv failure path to be exercised for app_config.dart" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_build_all_packages_tmpdir_mv_failure_cleanup] Passed"
