#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
mkdir -p "$TMP_ROOT/dist/linux"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_ROOT/pubspec.yaml" <<'EOF'
name: fake_app
version: 10.1.200+4200
EOF

PROJECT_ROOT_OVERRIDE="$TMP_ROOT" bash "$TARGET_SCRIPT" >/tmp/test_build_installer_project_root_override.log 2>&1

OUTPUT_FILE="$TMP_ROOT/dist/linux/install.sh"
if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "build_installer.sh did not write install.sh to the override root" >&2
  cat /tmp/test_build_installer_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'INSTALL_VERSION="10.1.200"' "$OUTPUT_FILE"; then
  echo "install.sh did not include the override-root version" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "PASS: scripts/packaging/build_installer.sh respects PROJECT_ROOT_OVERRIDE"
