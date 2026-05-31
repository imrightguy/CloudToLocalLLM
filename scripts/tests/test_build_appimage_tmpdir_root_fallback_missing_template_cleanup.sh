#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project-root"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
MKTEMP_LOG="$WORK_DIR/mktemp.log"
OUTPUT_LOG="$WORK_DIR/output.log"
mkdir -p "$FAKE_ROOT/scripts" "$FAKE_BUILD_DIR" "$FAKE_TOOLS"
export MKTEMP_LOG

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
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

cat > "$FAKE_TOOLS/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
result="$(/usr/bin/mktemp "$@")"
printf '%s => %s\n' "$*" "$result" >> "$MKTEMP_LOG"
printf '%s\n' "$result"
EOF
chmod +x "$FAKE_TOOLS/mktemp"

set +e
TMPDIR='/' \
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
FLUTTER_CMD="$FAKE_ROOT/scripts/flutter_with_cleanup.sh" \
"$PROJECT_ROOT/scripts/build-appimage.sh" >"$OUTPUT_LOG" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build-appimage.sh to fail when the desktop template is missing" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudtolocalllm-appimage.' "$MKTEMP_LOG"; then
  echo "Expected APPIMAGE_WORKDIR to fall back to /tmp" >&2
  cat "$MKTEMP_LOG" >&2
  exit 1
fi

workdir_path="$(awk -F ' => ' '/cloudtolocalllm-appimage/ {print $2; exit}' "$MKTEMP_LOG")"
if [[ -z "$workdir_path" ]]; then
  echo "Expected to capture AppImage workdir path" >&2
  cat "$MKTEMP_LOG" >&2
  exit 1
fi

if [[ -d "$workdir_path" ]]; then
  echo "Expected APPIMAGE_WORKDIR cleanup after missing template failure" >&2
  printf '%s\n' "$workdir_path" >&2
  exit 1
fi

if grep -Fq 'appimagetool' "$MKTEMP_LOG"; then
  echo "Expected missing-template failure before appimagetool download/selection" >&2
  cat "$MKTEMP_LOG" >&2
  exit 1
fi

if ! grep -Fq 'Desktop entry template not found' "$OUTPUT_LOG"; then
  echo "Expected missing desktop template error" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

echo "[test_build_appimage_tmpdir_root_fallback_missing_template_cleanup] Passed"
