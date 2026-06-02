#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
OUTPUT_FILE="$WORK_DIR/dist/linux/install.sh"
LOG_FILE="$WORK_DIR/build_installer.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/scripts/packaging/update-daemon" "$WORK_DIR/dist/linux"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/build_installer.sh"
chmod +x "$WORK_DIR/scripts/packaging/build_installer.sh"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated" "$WORK_DIR/scripts/packaging/update-daemon/cloudtolocalllm-updated"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.service" "$WORK_DIR/scripts/packaging/update-daemon/cloudtolocalllm-updated.service"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer" "$WORK_DIR/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer"

if (cd "$WORK_DIR" && bash "$WORK_DIR/scripts/packaging/build_installer.sh") >"$LOG_FILE" 2>&1; then
  echo "build_installer.sh unexpectedly succeeded with a missing template" >&2
  exit 1
fi

if ! grep -Fq 'Installer template not found:' "$LOG_FILE"; then
  echo "Expected preflight template error missing from output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ -e "$OUTPUT_FILE" ]]; then
  echo "Installer output should not exist after preflight failure" >&2
  exit 1
fi

echo "[test_build_installer_preflight] Passed"
