#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
SCRIPT_DIR="$TMP_ROOT/scripts/packaging"
FAKE_SCRIPT_DIR="$TMP_ROOT/scripts"
VERSION_MANAGER="$TMP_ROOT/version_manager.sh"
FAKE_BUILD_SCRIPT="$TMP_ROOT/fake_build_appimage.sh"
ORIGINAL_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''0.0.0'\'';\n}\n'
EXPECTED_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''10.1.200'\'';\n}\n'
ORIGINAL_VERSION_JSON='{"version":"0.0.0","build_number":"0"}\n'
EXPECTED_VERSION_JSON='{"version":"10.1.200","build_number":"4200","build_date":"2026-05-10T11:47:25Z","git_commit":"deadbeef"}\n'

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$SCRIPT_DIR" "$FAKE_SCRIPT_DIR" "$TMP_ROOT/lib/config" "$TMP_ROOT/assets" "$TMP_ROOT/build/linux/x64/release/bundle" "$TMP_ROOT/dist/linux"
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
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
mkdir -p "$proj_root/dist/linux"
printf '%s\n' 'appimage-built' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
printf '%s\n' 'checksum-built' > "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage.sha256"
chmod +x "$proj_root/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"
exit 0
EOF
chmod +x "$FAKE_BUILD_SCRIPT"

printf '%s' "$ORIGINAL_APP_CONFIG" > "$TMP_ROOT/lib/config/app_config.dart"
printf '%s' "$ORIGINAL_VERSION_JSON" > "$TMP_ROOT/assets/version.json"

SCRIPT_DIR_OVERRIDE="$SCRIPT_DIR" \
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$TMP_ROOT/fake_flutter.sh" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_SCRIPT" \
"$SCRIPT_DIR/build_all_packages.sh" --packages appimage >/tmp/test_build_all_packages_success_cleanup.log 2>&1

if [[ "$(cat "$TMP_ROOT/lib/config/app_config.dart")" != "$EXPECTED_APP_CONFIG" ]]; then
  echo "app_config.dart did not retain the expected version update on success" >&2
  cat /tmp/test_build_all_packages_success_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '"version": "10.1.200"' "$TMP_ROOT/assets/version.json"; then
  echo "version.json did not retain the expected version field on success" >&2
  cat /tmp/test_build_all_packages_success_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '"build_number": "4200"' "$TMP_ROOT/assets/version.json"; then
  echo "version.json did not retain the expected build number on success" >&2
  cat /tmp/test_build_all_packages_success_cleanup.log >&2
  exit 1
fi

if compgen -G "$TMP_ROOT/.tmp.package-backup.*" > /dev/null; then
  echo "Temporary package backup files were not cleaned up after success" >&2
  ls -1 "$TMP_ROOT"/.tmp.package-backup.* >&2
  exit 1
fi

if compgen -G "$TMP_ROOT/lib/config/.tmp.app-config.*" > /dev/null; then
  echo "Temporary app config files were not cleaned up after success" >&2
  ls -1 "$TMP_ROOT/lib/config"/.tmp.app-config.* >&2
  exit 1
fi

if compgen -G "$TMP_ROOT/assets/.version.json.*" > /dev/null; then
  echo "Temporary version.json files were not cleaned up after success" >&2
  ls -1 "$TMP_ROOT/assets"/.version.json.* >&2
  exit 1
fi

if [[ ! -f "$TMP_ROOT/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Expected final AppImage artifact on success" >&2
  cat /tmp/test_build_all_packages_success_cleanup.log >&2
  exit 1
fi

echo "[test_build_all_packages_success_cleanup] Passed"
