#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
TMPDIR_BASE="$WORK_DIR/nested/tmpdir/base"
TMPDIR_ROOT="$TMPDIR_BASE/inner"
SCRIPT_COPY_DIR="$WORK_DIR/scripts/packaging"
FAKE_PROJECT_ROOT="$WORK_DIR/project"
VERSION_MANAGER="$WORK_DIR/version_manager.sh"
FAKE_FLUTTER="$WORK_DIR/flutter.sh"
FAKE_BUILD_APPIMAGE="$WORK_DIR/build_appimage.sh"
LOG_FILE="$WORK_DIR/run.log"
mkdir -p "$SCRIPT_COPY_DIR" "$FAKE_PROJECT_ROOT/lib/config" "$FAKE_PROJECT_ROOT/assets" "$FAKE_PROJECT_ROOT/build/linux/x64/release/bundle" "$FAKE_PROJECT_ROOT/dist/linux"
cp "$TARGET_SCRIPT" "$SCRIPT_COPY_DIR/build_all_packages.sh"
chmod +x "$SCRIPT_COPY_DIR/build_all_packages.sh"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

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

cat > "$FAKE_BUILD_APPIMAGE" <<'EOF'
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
chmod +x "$FAKE_BUILD_APPIMAGE"

printf '%s' "class AppConfig {\n  static const String appVersion = '0.0.0';\n}\n" > "$FAKE_PROJECT_ROOT/lib/config/app_config.dart"
printf '%s' '{"version":"0.0.0","build_number":"0"}\n' > "$FAKE_PROJECT_ROOT/assets/version.json"
cat > "$FAKE_PROJECT_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

SCRIPT_DIR_OVERRIDE="$SCRIPT_COPY_DIR" \
PROJECT_ROOT_OVERRIDE="$FAKE_PROJECT_ROOT" \
TMPDIR="$TMPDIR_ROOT" \
VERSION_MANAGER_SCRIPT="$VERSION_MANAGER" \
FLUTTER_CMD="$FAKE_FLUTTER" \
BUILD_APPIMAGE_CMD="$FAKE_BUILD_APPIMAGE" \
"$SCRIPT_COPY_DIR/build_all_packages.sh" --packages appimage > "$LOG_FILE" 2>&1

if [[ ! -f "$FAKE_PROJECT_ROOT/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Expected AppImage package output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$FAKE_PROJECT_ROOT/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage.sha256" ]]; then
  echo "Expected AppImage checksum output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if find "$TMPDIR_ROOT" -name 'package-backup.*' -o -name 'app-config.*' -o -name 'version.json.*' | grep -q .; then
  echo "Expected TMPDIR temporary files to be cleaned up" >&2
  find "$TMPDIR_ROOT" -name 'package-backup.*' -o -name 'app-config.*' -o -name 'version.json.*' >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

grep -Fq 'All package builds completed successfully!' "$LOG_FILE"

echo "[test_build_all_packages_nested_tmpdir_cleanup] Passed"
