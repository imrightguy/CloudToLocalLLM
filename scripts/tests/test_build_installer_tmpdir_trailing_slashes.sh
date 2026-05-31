#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
OUTPUT_FILE="$WORK_DIR/nested/output/install.sh"
TMPDIR_BASE="$WORK_DIR/trailing/tmpdir/base"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_ROOT" "$(dirname "$OUTPUT_FILE")" "$TMPDIR_BASE"
cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 1.2.3+9
EOF

TMPDIR="$TMPDIR_BASE////" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
OUTPUT_FILE="$OUTPUT_FILE" \
"$PROJECT_ROOT/scripts/packaging/build_installer.sh" >/tmp/test_build_installer_tmpdir_trailing_slashes.log 2>&1

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "Expected installer output at $OUTPUT_FILE" >&2
  cat /tmp/test_build_installer_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if [[ ! -x "$OUTPUT_FILE" ]]; then
  echo "Expected installer output to be executable" >&2
  cat /tmp/test_build_installer_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if ! grep -Fq 'INSTALL_VERSION="1.2.3"' "$OUTPUT_FILE"; then
  echo "Expected installer output to include normalized semantic version" >&2
  cat /tmp/test_build_installer_tmpdir_trailing_slashes.log >&2
  exit 1
fi

echo "[test_build_installer_tmpdir_trailing_slashes] Passed"
