#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
BUILD_DIR="$WORK_DIR/build/linux/x64/release/bundle"
DIST_DIR="$WORK_DIR/dist/linux"
OUTPUT_DEB_DIR="$WORK_DIR/output"
PUBSPEC_FILE="$WORK_DIR/pubspec.yaml"
LOG_FILE="$WORK_DIR/dpkg.log"
mkdir -p "$FAKE_TOOLS_DIR" "$BUILD_DIR" "$OUTPUT_DEB_DIR" "$DIST_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$PUBSPEC_FILE" <<'EOF'
name: cloudtolocalllm
version: 1.2.3+4
EOF

cat > "$BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_TOOLS_DIR/dpkg-deb" <<EOF
#!/bin/bash
set -euo pipefail
echo "dpkg-deb \$*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_TOOLS_DIR/dpkg-deb"

set +e
PATH="$FAKE_TOOLS_DIR:/usr/bin:/bin" \
DPKG_DEB_CMD="$FAKE_TOOLS_DIR/dpkg-deb" \
PUBSPEC_FILE="$PUBSPEC_FILE" \
BUILD_DIR="$BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
OUTPUT_DEB="$OUTPUT_DEB_DIR" \
"$TARGET_SCRIPT" >/tmp/test_build_deb_output_deb_directory_guard.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_deb.sh to fail when OUTPUT_DEB is a directory" >&2
  cat /tmp/test_build_deb_output_deb_directory_guard.log >&2
  exit 1
fi

if ! grep -Fq 'OUTPUT_DEB must not be a directory' /tmp/test_build_deb_output_deb_directory_guard.log; then
  echo "Missing OUTPUT_DEB directory validation message" >&2
  cat /tmp/test_build_deb_output_deb_directory_guard.log >&2
  exit 1
fi

if [[ -e "$LOG_FILE" ]]; then
  echo "Expected dpkg-deb not to run when OUTPUT_DEB guard fails" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if find "$OUTPUT_DEB_DIR" -mindepth 1 -print -quit | grep -q .; then
  echo "Expected no deb artifact when OUTPUT_DEB guard fails" >&2
  find "$OUTPUT_DEB_DIR" -mindepth 1 -print >&2
  exit 1
fi

echo "[test_build_deb_output_deb_directory_guard] Passed"
