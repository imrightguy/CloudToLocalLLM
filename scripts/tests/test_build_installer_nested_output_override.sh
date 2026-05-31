#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
OUTPUT_FILE="$FAKE_ROOT/dist/linux/nested/install.sh"
mkdir -p "$FAKE_ROOT/scripts/packaging/update-daemon" "$FAKE_ROOT/dist/linux/nested"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: fake_app
version: 10.1.200+4200
EOF

cp "$PROJECT_ROOT/scripts/packaging/installer-template.sh" "$FAKE_ROOT/scripts/packaging/installer-template.sh"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated" "$FAKE_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.service" "$FAKE_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.service"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer" "$FAKE_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer"

PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" OUTPUT_FILE="$OUTPUT_FILE" MAKEPKG_CMD=/bin/true bash "$TARGET_SCRIPT" >/tmp/test_build_installer_nested_output_override.log 2>&1

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "build_installer.sh did not write install.sh to the nested override path" >&2
  cat /tmp/test_build_installer_nested_output_override.log >&2
  exit 1
fi

if ! grep -Fq 'INSTALL_VERSION="10.1.200"' "$OUTPUT_FILE"; then
  echo "install.sh did not include the override-root version" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_build_installer_nested_output_override] Passed"
