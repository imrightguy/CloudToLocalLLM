#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
DIST_DIR="$WORK_DIR/dist"
DPKG_LOG="$WORK_DIR/dpkg.log"
OUTPUT_DEB="$DIST_DIR/cloudtolocalllm_10.1.200_amd64.deb"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$DIST_DIR"
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

cat > "$FAKE_TOOLS_DIR/fake-dpkg-deb" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$DPKG_LOG"
out="${@: -1}"
mkdir -p "$(dirname "$out")"
printf '%s\n' 'fake-deb' > "$out"
EOF
chmod +x "$FAKE_TOOLS_DIR/fake-dpkg-deb"

PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
DPKG_DEB_CMD="$FAKE_TOOLS_DIR/fake-dpkg-deb" \
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml" \
bash "$TARGET_SCRIPT" >/tmp/test_build_deb_cmd_override.log 2>&1

if [[ ! -f "$OUTPUT_DEB" ]]; then
  echo "Expected Debian output at $OUTPUT_DEB" >&2
  cat /tmp/test_build_deb_cmd_override.log >&2
  exit 1
fi

if ! grep -q "$FAKE_TOOLS_DIR/fake-dpkg-deb" "$DPKG_LOG"; then
  echo "Expected DPKG_DEB_CMD override to be invoked" >&2
  cat /tmp/test_build_deb_cmd_override.log >&2
  exit 1
fi

if grep -q 'Required command not found: dpkg-deb' /tmp/test_build_deb_cmd_override.log; then
  echo "Expected DPKG_DEB_CMD override to skip default command lookup" >&2
  cat /tmp/test_build_deb_cmd_override.log >&2
  exit 1
fi

echo "[test_build_deb_cmd_override] Passed"
