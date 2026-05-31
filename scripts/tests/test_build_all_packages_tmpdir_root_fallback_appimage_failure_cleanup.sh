#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
FAKE_TOOLS="$WORK_DIR/bin"
VERSION_MANAGER="$WORK_DIR/version manager.sh"
MKTEMP_LOG="$WORK_DIR/mktemp.log"
FLUTTER_LOG="$WORK_DIR/flutter.log"
BUILD_APPIMAGE_LOG="$WORK_DIR/build_appimage.log"
mkdir -p "$FAKE_ROOT/lib/config" "$FAKE_ROOT/assets" "$FAKE_ROOT/build/linux/x64/release/bundle" "$FAKE_ROOT/dist/linux" "$FAKE_TOOLS"
export MKTEMP_LOG FLUTTER_LOG BUILD_APPIMAGE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$FAKE_ROOT/lib/config/app_config.dart" <<'EOF'
class AppConfig {
  static const String appVersion = 'old';
}
EOF

cat > "$FAKE_ROOT/assets/version.json" <<'EOF'
{"version":"old","build_number":"0"}
EOF

cat > "$FAKE_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_ROOT/build/linux/x64/release/bundle/cloudtolalllm" 2>/dev/null || true
chmod +x "$FAKE_ROOT/build/linux/x64/release/bundle/cloudtolocalllm"

cat > "$VERSION_MANAGER" <<'EOF'
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
chmod +x "$VERSION_MANAGER"

cat > "$FAKE_TOOLS/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
result="$(/usr/bin/mktemp "$@")"
printf '%s => %s\n' "$*" "$result" >> "$MKTEMP_LOG"
printf '%s\n' "$result"
EOF
chmod +x "$FAKE_TOOLS/mktemp"

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
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
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
  echo "Expected build_appimage override to be invoked" >&2
  cat "$BUILD_APPIMAGE_LOG" >&2
  exit 1
fi

if ! grep -Fxq "  static const String appVersion = 'old';" "$FAKE_ROOT/lib/config/app_config.dart"; then
  echo "Expected app_config.dart to be restored after failure" >&2
  cat "$FAKE_ROOT/lib/config/app_config.dart" >&2
  exit 1
fi

if ! grep -Fxq '{"version":"old","build_number":"0"}' "$FAKE_ROOT/assets/version.json"; then
  echo "Expected version.json to be restored after failure" >&2
  cat "$FAKE_ROOT/assets/version.json" >&2
  exit 1
fi

if ! grep -Fq '/tmp/package-backup.' "$MKTEMP_LOG"; then
  echo "Expected TMPDIR=/ to normalize backup temp files under /tmp" >&2
  cat "$MKTEMP_LOG" >&2
  exit 1
fi

while IFS= read -r tmpfile; do
  [[ -n "$tmpfile" ]] || continue
  if [[ -e "$tmpfile" ]]; then
    echo "Expected temp file cleanup after failure: $tmpfile" >&2
    cat "$MKTEMP_LOG" >&2
    exit 1
  fi
done < <(awk -F ' => ' '{print $2}' "$MKTEMP_LOG")

if compgen -G "$FAKE_ROOT/.tmp.package-backup.*" > /dev/null; then
  echo "Expected package backup temp files to be cleaned up after failure" >&2
  ls -1 "$FAKE_ROOT"/.tmp.package-backup.* >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/lib/config/.tmp.app-config.*" > /dev/null; then
  echo "Expected app_config temp files to be cleaned up after failure" >&2
  ls -1 "$FAKE_ROOT/lib/config"/.tmp.app-config.* >&2
  exit 1
fi

if compgen -G "$FAKE_ROOT/assets/.version.json.*" > /dev/null; then
  echo "Expected version.json temp files to be cleaned up after failure" >&2
  ls -1 "$FAKE_ROOT/assets"/.version.json.* >&2
  exit 1
fi

echo "[test_build_all_packages_tmpdir_root_fallback_appimage_failure_cleanup] Passed"
