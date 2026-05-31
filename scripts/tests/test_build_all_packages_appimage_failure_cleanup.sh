#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake root"
FAKE_TOOLS="$WORK_DIR/bin"
VERSION_MANAGER="$WORK_DIR/version_manager.sh"
FLUTTER_LOG="$WORK_DIR/flutter.log"
BUILD_APPIMAGE_LOG="$WORK_DIR/build_appimage.log"
ORIGINAL_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''0.0.0'\'';\n}\n'
EXPECTED_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''10.1.200'\'';\n}\n'
ORIGINAL_VERSION_JSON='{"version":"0.0.0","build_number":"0"}\n'
EXPECTED_VERSION_JSON='{"version": "10.1.200",'
mkdir -p "$FAKE_TOOLS" "$FAKE_ROOT/lib/config" "$FAKE_ROOT/assets" "$FAKE_ROOT/build/linux/x64/release/bundle" "$FAKE_ROOT/dist/linux"
export FLUTTER_LOG BUILD_APPIMAGE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

printf '%s' "$ORIGINAL_APP_CONFIG" > "$FAKE_ROOT/lib/config/app_config.dart"
printf '%s' "$ORIGINAL_VERSION_JSON" > "$FAKE_ROOT/assets/version.json"

cat > "$FAKE_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_ROOT/build/linux/x64/release/bundle/cloudtolocalllm"

cat > "$VERSION_MANAGER" <<'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  get-semantic) echo 10.1.200 ;;
  get) echo 10.1.200+4200 ;;
  get-build) echo 4200 ;;
  validate) exit 0 ;;
  increment) exit 0 ;;
  *) echo "unexpected version_manager call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$VERSION_MANAGER"

cat > "$FAKE_TOOLS/flutter.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter %s\n' "$*" >> "$FLUTTER_LOG"
case "${1:-}" in
  clean|pub)
    exit 0
    ;;
  build)
    if [[ "${2:-}" == "linux" ]]; then
      mkdir -p "$PROJECT_ROOT_OVERRIDE/build/linux/x64/release/bundle"
      cat > "$PROJECT_ROOT_OVERRIDE/build/linux/x64/release/bundle/cloudtolocalllm" <<'APP'
#!/bin/sh
exit 0
APP
      chmod +x "$PROJECT_ROOT_OVERRIDE/build/linux/x64/release/bundle/cloudtolocalllm"
      exit 0
    fi
    ;;
  config|doctor)
    exit 0
    ;;
esac
exit 0
EOF
chmod +x "$FAKE_TOOLS/flutter.sh"

cat > "$FAKE_TOOLS/build_appimage.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'build_appimage %s\n' "$*" >> "$BUILD_APPIMAGE_LOG"
exit 1
EOF
chmod +x "$FAKE_TOOLS/build_appimage.sh"

set +e
TMPDIR='/' \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_TOOLS/flutter.sh" \
BUILD_APPIMAGE_CMD="$FAKE_TOOLS/build_appimage.sh" \
"$PROJECT_ROOT/scripts/packaging/build_all_packages.sh" --packages appimage --skip-increment >"$WORK_DIR/output.log" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when build_appimage exits non-zero" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'build_appimage ' "$BUILD_APPIMAGE_LOG"; then
  echo "Expected fake build_appimage command to be invoked" >&2
  cat "$BUILD_APPIMAGE_LOG" >&2
  exit 1
fi

if [[ "$(cat "$FAKE_ROOT/lib/config/app_config.dart")" != "$ORIGINAL_APP_CONFIG" ]]; then
  echo "Expected app_config.dart to be restored after failure" >&2
  cat "$FAKE_ROOT/lib/config/app_config.dart" >&2
  exit 1
fi

if [[ "$(cat "$FAKE_ROOT/assets/version.json")" != "$ORIGINAL_VERSION_JSON" ]]; then
  echo "Expected version.json to be restored after failure" >&2
  cat "$FAKE_ROOT/assets/version.json" >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/.tmp.package-backup.*" > /dev/null; then
  echo "Expected package backup temp files to be cleaned up after failure" >&2
  ls -1 "$FAKE_ROOT"/.tmp.package-backup.* >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/lib/config/.tmp.app-config.*" > /dev/null; then
  echo "Expected app config temp files to be cleaned up after failure" >&2
  ls -1 "$FAKE_ROOT/lib/config"/.tmp.app-config.* >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/assets/.version.json.*" > /dev/null; then
  echo "Expected version.json temp files to be cleaned up after failure" >&2
  ls -1 "$FAKE_ROOT/assets"/.version.json.* >&2
  exit 1
fi

if [[ -e "$FAKE_ROOT/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Expected no final AppImage output after failure" >&2
  exit 1
fi

echo "[test_build_all_packages_appimage_failure_cleanup] Passed"
