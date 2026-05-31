#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
SCRIPT_DIR="$TMP_ROOT/scripts/packaging"
FAKE_SCRIPT_DIR="$TMP_ROOT/scripts"
VERSION_MANAGER="$TMP_ROOT/version_manager.sh"
FAKE_BUILD_SCRIPT="$TMP_ROOT/fake_build_appimage.sh"
ORIGINAL_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''0.0.0'\'';\n}\n'
EXPECTED_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''0.0.0'\'';\n}\n'
ORIGINAL_VERSION_JSON='{"version":"0.0.0","build_number":"0"}\n'

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$SCRIPT_DIR" "$FAKE_SCRIPT_DIR" "$TMP_ROOT/lib/config" "$TMP_ROOT/assets" "$TMP_ROOT/build/linux/x64/release/bundle" "$TMP_ROOT/dist/linux"
printf '%s\n' 'name: cloudtolocalllm' > "$TMP_ROOT/pubspec.yaml"
cp "$PROJECT_ROOT/scripts/packaging/build_all_packages.sh" "$SCRIPT_DIR/build_all_packages.sh"
chmod +x "$SCRIPT_DIR/build_all_packages.sh"

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

cat > "$FAKE_BUILD_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF
chmod +x "$FAKE_BUILD_SCRIPT"

printf '%s' "$ORIGINAL_APP_CONFIG" > "$TMP_ROOT/lib/config/app_config.dart"
printf '%s' "$ORIGINAL_VERSION_JSON" > "$TMP_ROOT/assets/version.json"

set +e
SCRIPT_DIR_OVERRIDE="$SCRIPT_DIR" \
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$TMP_ROOT/fake_flutter.sh" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_SCRIPT" \
"$SCRIPT_DIR/build_all_packages.sh" --packages appimage >/tmp/test_build_all_packages_missing_appimage_artifact.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when AppImage artifact is missing" >&2
  cat /tmp/test_build_all_packages_missing_appimage_artifact.log >&2
  exit 1
fi

if ! grep -Fq "AppImage package not found" /tmp/test_build_all_packages_missing_appimage_artifact.log; then
  echo "Expected missing AppImage artifact error" >&2
  cat /tmp/test_build_all_packages_missing_appimage_artifact.log >&2
  exit 1
fi

if [[ "$(cat "$TMP_ROOT/lib/config/app_config.dart")" != "$EXPECTED_APP_CONFIG" ]]; then
  echo "Expected app_config.dart to be restored after validation failure" >&2
  cat /tmp/test_build_all_packages_missing_appimage_artifact.log >&2
  exit 1
fi

if [[ "$(cat "$TMP_ROOT/assets/version.json")" != "$ORIGINAL_VERSION_JSON" ]]; then
  echo "Expected version.json to be restored after validation failure" >&2
  cat /tmp/test_build_all_packages_missing_appimage_artifact.log >&2
  exit 1
fi

echo "[test_build_all_packages_missing_appimage_artifact] Passed"
