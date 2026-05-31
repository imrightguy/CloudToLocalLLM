#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
DPKG_DIR="$WORK_DIR/dpkg tools"
DIST_DIR="$WORK_DIR/dist with spaces/output"
DPKG_LOG="$WORK_DIR/dpkg.log"
OUTPUT_DEB="$DIST_DIR/cloudtolocalllm_10.1.200_amd64.deb"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$DPKG_DIR" "$DIST_DIR"
export DPKG_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$DPKG_DIR/dpkg-deb wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$DPKG_LOG"
out="${@: -1}"
mkdir -p "$(dirname "$out")"
printf '%s\n' 'fake-deb' > "$out"
EOF
chmod +x "$DPKG_DIR/dpkg-deb wrapper"

PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
DPKG_DEB_CMD="$DPKG_DIR/dpkg-deb wrapper" \
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml" \
bash "$TARGET_SCRIPT" >/tmp/test_build_deb_cmd_path_spaces.log 2>&1

if [[ ! -f "$OUTPUT_DEB" ]]; then
  echo "Expected Debian output at $OUTPUT_DEB" >&2
  cat /tmp/test_build_deb_cmd_path_spaces.log >&2
  exit 1
fi

if ! grep -Fq "$DPKG_DIR/dpkg-deb wrapper" "$DPKG_LOG"; then
  echo "Expected spaced DPKG_DEB_CMD path to be invoked" >&2
  cat "$DPKG_LOG" >&2
  exit 1
fi

if grep -Fq 'Required command not found: dpkg-deb wrapper' /tmp/test_build_deb_cmd_path_spaces.log; then
  echo "Expected DPKG_DEB_CMD path lookup to accept spaced executable paths" >&2
  cat /tmp/test_build_deb_cmd_path_spaces.log >&2
  exit 1
fi

echo "[test_build_deb_cmd_path_spaces] Passed"
