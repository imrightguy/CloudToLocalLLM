#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project root with spaces"
TMPDIR_ROOT="$WORK_DIR/tmp dir with spaces/base/inner"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
FAKE_DPKG_DEB="$WORK_DIR/dpkg deb wrapper.sh"
OUTPUT_DEB="$FAKE_ROOT/dist dir with spaces/linux packages/cloudtolocalllm_2.3.4_amd64.deb"
DPKG_LOG="$WORK_DIR/dpkg.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$FAKE_ROOT/assets/images" "$TMPDIR_ROOT"
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

cat > "$FAKE_DPKG_DEB" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$DPKG_LOG"
out="${@: -1}"
mkdir -p "$(dirname "$out")"
printf '%s\n' 'fake-deb' > "$out"
EOF
chmod +x "$FAKE_DPKG_DEB"

PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
TMPDIR="$TMPDIR_ROOT////" \
OUTPUT_DEB="$OUTPUT_DEB" \
DPKG_DEB_CMD="$FAKE_DPKG_DEB" \
bash "$PROJECT_ROOT/scripts/packaging/build_deb.sh" >/tmp/test_build_deb_project_root_and_tmpdir_spaces.log 2>&1

if [[ ! -f "$OUTPUT_DEB" ]]; then
  echo "Expected Debian output at $OUTPUT_DEB" >&2
  cat /tmp/test_build_deb_project_root_and_tmpdir_spaces.log >&2
  exit 1
fi

if ! grep -Fq "$FAKE_DPKG_DEB" "$DPKG_LOG"; then
  echo "Expected DPKG_DEB_CMD override to be invoked" >&2
  cat "$DPKG_LOG" >&2
  exit 1
fi

if find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'cloudtolocalllm-deb.*' | grep -q .; then
  echo "Expected temporary package root cleanup under spaced TMPDIR root" >&2
  find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'cloudtolocalllm-deb.*' >&2
  exit 1
fi

echo "[test_build_deb_project_root_and_tmpdir_spaces] Passed"
