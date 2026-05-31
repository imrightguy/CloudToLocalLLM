#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
TMPDIR_ROOT="$WORK_DIR/tmp dir with spaces/base/inner"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
DPKG_DIR="$WORK_DIR/dpkg tools with spaces"
OUTPUT_DEB="$FAKE_ROOT/dist dir with spaces/linux packages/cloudtolocalllm_2.3.4_amd64.deb"
DPKG_LOG="$WORK_DIR/dpkg.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$DPKG_DIR" "$TMPDIR_ROOT" "$(dirname "$OUTPUT_DEB")" "$FAKE_ROOT/assets/images"
export DPKG_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 2.3.4+5
EOF

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

printf '%s\n' 'fake-icon' > "$FAKE_ROOT/assets/images/app_icon.png"

cat > "$DPKG_DIR/dpkg-deb wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$DPKG_LOG"
out="${@: -1}"
mkdir -p "$(dirname "$out")"
printf '%s\n' 'fake-deb' > "$out"
EOF
chmod +x "$DPKG_DIR/dpkg-deb wrapper"

PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
TMPDIR="$TMPDIR_ROOT////" \
OUTPUT_DEB="$OUTPUT_DEB" \
DPKG_DEB_CMD="$DPKG_DIR/dpkg-deb wrapper" \
BUILD_DIR="$FAKE_BUILD_DIR" \
bash "$PROJECT_ROOT/scripts/packaging/build_deb.sh" >/tmp/test_build_deb_project_root_tmpdir_cmd_spaces.log 2>&1

if [[ ! -f "$OUTPUT_DEB" ]]; then
  echo "Expected Debian output at $OUTPUT_DEB" >&2
  cat /tmp/test_build_deb_project_root_tmpdir_cmd_spaces.log >&2
  exit 1
fi

if ! grep -Fq "$DPKG_DIR/dpkg-deb wrapper" "$DPKG_LOG"; then
  echo "Expected spaced DPKG_DEB_CMD path to be invoked" >&2
  cat "$DPKG_LOG" >&2
  exit 1
fi

if find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'cloudtolocalllm-deb.*' | grep -q .; then
  echo "Expected temporary package root cleanup under spaced TMPDIR root" >&2
  find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'cloudtolocalllm-deb.*' >&2
  exit 1
fi

echo "[test_build_deb_project_root_tmpdir_cmd_spaces] Passed"
