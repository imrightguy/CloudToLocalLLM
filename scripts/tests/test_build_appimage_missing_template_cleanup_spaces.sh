#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
APPIMAGE_WORKDIR="$WORK_DIR/appimage workdir with spaces"
APPIMAGE_OUTPUT="$WORK_DIR/output dir with spaces/cloudtolocalllm-missing-template.AppImage"
APPIMAGETOOL_LOG="$WORK_DIR/appimagetool.log"
mkdir -p "$FAKE_ROOT/scripts" "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$APPIMAGE_WORKDIR" "$(dirname "$APPIMAGE_OUTPUT")"
export APPIMAGETOOL_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 9.8.7+6
EOF

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter:%s\n' "$*" >> "${APPIMAGETOOL_LOG:?missing APPIMAGETOOL_LOG}"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

cat > "$FAKE_TOOLS/fake-appimagetool" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "$0" "$*" >> "${APPIMAGETOOL_LOG:?missing APPIMAGETOOL_LOG}"
exit 1
EOF
chmod +x "$FAKE_TOOLS/fake-appimagetool"

set +e
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
APPIMAGE_WORKDIR="$APPIMAGE_WORKDIR" \
APPIMAGE_OUTPUT="$APPIMAGE_OUTPUT" \
APPIMAGETOOL_CMD="$FAKE_TOOLS/fake-appimagetool" \
FLUTTER_CMD="$FAKE_ROOT/scripts/flutter_with_cleanup.sh" \
bash "$PROJECT_ROOT/scripts/build-appimage.sh" >/tmp/test_build_appimage_missing_template_cleanup_spaces.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when the desktop template is missing" >&2
  cat /tmp/test_build_appimage_missing_template_cleanup_spaces.log >&2
  exit 1
fi

if [[ -d "$APPIMAGE_WORKDIR" ]]; then
  echo "Expected APPIMAGE_WORKDIR cleanup when the desktop template is missing" >&2
  find "$APPIMAGE_WORKDIR" -maxdepth 2 -print >&2
  exit 1
fi

if [[ -e "$APPIMAGE_OUTPUT" ]]; then
  echo "Expected missing-template failure to leave no AppImage output" >&2
  cat /tmp/test_build_appimage_missing_template_cleanup_spaces.log >&2
  exit 1
fi

if ! grep -Fq 'Desktop entry template not found' /tmp/test_build_appimage_missing_template_cleanup_spaces.log; then
  echo "Expected missing desktop template error" >&2
  cat /tmp/test_build_appimage_missing_template_cleanup_spaces.log >&2
  exit 1
fi

echo "[test_build_appimage_missing_template_cleanup_spaces] Passed"
