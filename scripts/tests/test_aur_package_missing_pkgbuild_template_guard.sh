#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/tests/test_aur_package.sh"
WORK_DIR="$(mktemp -d)"
OUTPUT_FILE="$WORK_DIR/stderr.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR"
cp "$TARGET_SCRIPT" "$WORK_DIR/test_aur_package.sh"
chmod +x "$WORK_DIR/test_aur_package.sh"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$WORK_DIR/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$WORK_DIR/flutter_with_cleanup.sh"

cat > "$WORK_DIR/makepkg-wrapper" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$WORK_DIR/makepkg-wrapper"

if PROJECT_ROOT_OVERRIDE="$WORK_DIR" FLUTTER_CMD="$WORK_DIR/flutter_with_cleanup.sh" MAKEPKG_CMD="$WORK_DIR/makepkg-wrapper" bash "$WORK_DIR/test_aur_package.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "test_aur_package.sh unexpectedly succeeded with missing PKGBUILD template" >&2
  exit 1
fi

if ! grep -q "AUR PKGBUILD template not found" "$OUTPUT_FILE"; then
  echo "Expected missing PKGBUILD template error message" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_aur_package_missing_pkgbuild_template_guard] Passed"
