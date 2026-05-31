#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
SCRIPT_DIR="$TMP_ROOT/scripts/packaging"
FAKE_SCRIPT_DIR="$TMP_ROOT/scripts"
WORKFLOW_ROOT="$TMP_ROOT"
FAKE_BUILD_SCRIPT="$TMP_ROOT/fake_build_appimage.sh"
FAKE_FLUTTER="$TMP_ROOT/fake_flutter.sh"
VERSION_MANAGER="$TMP_ROOT/version_manager.sh"
ORIGINAL_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''0.0.0'\'';\n}\n'
ORIGINAL_VERSION_JSON='{"version":"0.0.0","build_number":"0"}\n'
EXPECTED_APP_CONFIG='class AppConfig {\n  static const String appVersion = '\''10.1.200'\'';\n}\n'
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

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
case "${1:-}" in
  clean|pub|build)
    ;;
  *)
    ;;
esac
mkdir -p "$proj_root/build/linux/x64/release/bundle"
printf '%s\n' '#!/bin/sh' 'echo bundle-ok' > "$proj_root/build/linux/x64/release/bundle/cloudtolocalllm"
chmod +x "$proj_root/build/linux/x64/release/bundle/cloudtolocalllm"
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

cat > "$FAKE_BUILD_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail
proj_root="${PROJECT_ROOT_OVERRIDE:?missing PROJECT_ROOT_OVERRIDE}"
printf '%s' "class AppConfig {\n  static const String appVersion = 'mutated';\n}\n" > "$proj_root/lib/config/app_config.dart"
printf '%s' '{"version":"mutated","build_number":"0"}\n' > "$proj_root/assets/version.json"
exit 1
EOF
chmod +x "$FAKE_BUILD_SCRIPT"

printf '%s' "$ORIGINAL_APP_CONFIG" > "$TMP_ROOT/lib/config/app_config.dart"
printf '%s' "$ORIGINAL_VERSION_JSON" > "$TMP_ROOT/assets/version.json"

set +e
SCRIPT_DIR_OVERRIDE="$SCRIPT_DIR" \
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_SCRIPT" \
"$SCRIPT_DIR/build_all_packages.sh" --packages appimage >/tmp/test_build_all_packages_restore.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when build_appimage fails" >&2
  cat /tmp/test_build_all_packages_restore.log >&2
  exit 1
fi

if [[ "$(cat "$TMP_ROOT/lib/config/app_config.dart")" != "$ORIGINAL_APP_CONFIG" ]]; then
  echo "app_config.dart was not restored after failure" >&2
  cat /tmp/test_build_all_packages_restore.log >&2
  exit 1
fi

if [[ "$(cat "$TMP_ROOT/assets/version.json")" != "$ORIGINAL_VERSION_JSON" ]]; then
  echo "version.json was not restored after failure" >&2
  cat /tmp/test_build_all_packages_restore.log >&2
  exit 1
fi

if compgen -G "$TMP_ROOT/.tmp.package-backup.*" > /dev/null; then
  echo "Temporary package backup files were not cleaned up after failure" >&2
  ls -1 "$TMP_ROOT"/.tmp.package-backup.* >&2
  exit 1
fi

if compgen -G "$TMP_ROOT/lib/config/.tmp.app-config.*" > /dev/null; then
  echo "Temporary app config files were not cleaned up after failure" >&2
  ls -1 "$TMP_ROOT/lib/config"/.tmp.app-config.* >&2
  exit 1
fi

if compgen -G "$TMP_ROOT/assets/.version.json.*" > /dev/null; then
  echo "Temporary version.json files were not cleaned up after failure" >&2
  ls -1 "$TMP_ROOT/assets"/.version.json.* >&2
  exit 1
fi

echo "[test_build_all_packages_restore] Passed"
