#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
TMP_ROOT="$(mktemp -d)"
SCRIPT_COPY="$TMP_ROOT/build_all_packages.sh"
VERSION_MANAGER="$TMP_ROOT/version_manager.sh"
FAKE_FLUTTER="$TMP_ROOT/flutter.sh"
FAKE_BUILD_SCRIPT="$TMP_ROOT/build_appimage.sh"
LOG_FILE="$TMP_ROOT/run.log"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TMP_ROOT/lib/config" "$TMP_ROOT/assets" "$TMP_ROOT/build/linux/x64/release/bundle" "$TMP_ROOT/dist/linux" "$TMP_ROOT/scripts/packaging"
cp "$TARGET_SCRIPT" "$SCRIPT_COPY"
chmod +x "$SCRIPT_COPY"

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
version="$(grep '^version:' "$proj_root/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)"
dist_dir="$proj_root/dist/linux"
mkdir -p "$dist_dir"
package="$dist_dir/cloudtolocalllm-${version}-x86_64.AppImage"
printf 'appimage' > "$package"
chmod +x "$package"
sha256sum "$package" > "$package.sha256"
EOF
chmod +x "$FAKE_BUILD_SCRIPT"

cat > "$TMP_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF
printf '%s' "class AppConfig {\n  static const String appVersion = '0.0.0';\n}\n" > "$TMP_ROOT/lib/config/app_config.dart"
printf '%s' '{"version":"0.0.0","build_number":"0"}\n' > "$TMP_ROOT/assets/version.json"

SCRIPT_DIR_OVERRIDE="$TMP_ROOT/scripts/packaging" \
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_SCRIPT" \
"$SCRIPT_COPY" --packages appimage > "$LOG_FILE" 2>&1

if find "$TMP_ROOT" -name '.tmp.package-backup.*' | grep -q .; then
  echo "Expected temporary package backup files to be cleaned up on success" >&2
  find "$TMP_ROOT" -name '.tmp.package-backup.*' >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if find "$TMP_ROOT" \( -name '.tmp.app-config.*' -o -name '.version.json.*' \) | grep -q .; then
  echo "Expected temporary version files to be cleaned up on success" >&2
  find "$TMP_ROOT" \( -name '.tmp.app-config.*' -o -name '.version.json.*' \) >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$TMP_ROOT/lib/config/app_config.dart" ]]; then
  echo "app_config.dart missing after successful build" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$TMP_ROOT/assets/version.json" ]]; then
  echo "version.json missing after successful build" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_build_all_packages_backup_cleanup] Passed"
