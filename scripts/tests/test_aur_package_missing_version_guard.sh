#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/tests/test_aur_package.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
OUTPUT_FILE="$WORK_DIR/stderr.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"
cp "$TARGET_SCRIPT" "$WORK_DIR/test_aur_package.sh"
chmod +x "$WORK_DIR/test_aur_package.sh"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
description: Missing version test
EOF

cat > "$BIN_DIR/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
echo "flutter should not be called for missing version guard" >&2
exit 42
EOF
chmod +x "$BIN_DIR/flutter_with_cleanup.sh"

if PATH="$BIN_DIR:$PATH" FLUTTER_CMD="$BIN_DIR/flutter_with_cleanup.sh" PROJECT_ROOT_OVERRIDE="$WORK_DIR" bash "$WORK_DIR/test_aur_package.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "test_aur_package.sh unexpectedly succeeded with missing version entry" >&2
  exit 1
fi

if ! grep -q "version entry not found in pubspec.yaml" "$OUTPUT_FILE"; then
  echo "Expected missing version entry error message" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

if grep -q "flutter should not be called" "$OUTPUT_FILE"; then
  echo "Expected version guard to fail before invoking flutter" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_aur_package_missing_version_guard] Passed"
