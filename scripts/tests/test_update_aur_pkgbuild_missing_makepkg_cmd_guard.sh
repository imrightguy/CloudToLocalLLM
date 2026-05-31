#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh"
WORK_DIR="$(mktemp -d)"
OUTPUT_FILE="$WORK_DIR/stderr.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/build-tools/packaging/aur" "$WORK_DIR/dist/linux" "$WORK_DIR/scripts/packaging"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"
chmod +x "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$WORK_DIR/build-tools/packaging/aur/PKGBUILD" <<'EOF'
pkgname=cloudtolocalllm
pkgver=VERSION
sha256sums=('SKIP')
EOF

: > "$WORK_DIR/dist/linux/cloudtolocalllm-10.1.200-x86_64.AppImage"

cat > "$WORK_DIR/makepkg-wrapper" <<'EOF'
#!/bin/bash
echo "makepkg should not be invoked when executable check fails" >&2
exit 42
EOF
chmod 644 "$WORK_DIR/makepkg-wrapper"

if PROJECT_ROOT_OVERRIDE="$WORK_DIR" MAKEPKG_CMD="$WORK_DIR/makepkg-wrapper" bash "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "update_aur_pkgbuild.sh unexpectedly succeeded with non-executable MAKEPKG_CMD" >&2
  exit 1
fi

if ! grep -q "makepkg not found or not executable" "$OUTPUT_FILE"; then
  echo "Expected non-executable makepkg command error message" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

if grep -q "makepkg should not be invoked" "$OUTPUT_FILE"; then
  echo "Expected executable check to fail before invoking makepkg" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_missing_makepkg_cmd_guard] Passed"
