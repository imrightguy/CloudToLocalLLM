#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/version_manager.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
mkdir -p "$TMP_ROOT"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_ROOT/pubspec.yaml" <<'EOF'
name: fake_app
version: 9.8.7+321
EOF

cd /tmp
output=$(PROJECT_ROOT_OVERRIDE="$TMP_ROOT" bash "$TARGET_SCRIPT" get)

if [[ "$output" != "9.8.7+321" ]]; then
  echo "version_manager.sh did not read pubspec.yaml from the override root" >&2
  echo "Output: $output" >&2
  exit 1
fi

echo "PASS: scripts/version_manager.sh respects PROJECT_ROOT_OVERRIDE"
