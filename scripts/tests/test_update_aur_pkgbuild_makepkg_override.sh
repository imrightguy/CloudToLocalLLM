#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh"
WORK_DIR="$(mktemp -d)"
MAKEPKG_LOG="$WORK_DIR/makepkg.log"

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

cat > "$WORK_DIR/makepkg-wrapper" <<EOF
#!/bin/bash
echo "makepkg-wrapper invoked: \$*" >> "$MAKEPKG_LOG"
printf '.SRCINFO from wrapper for 10.1.200\n'
EOF
chmod +x "$WORK_DIR/makepkg-wrapper"

if PROJECT_ROOT_OVERRIDE="$WORK_DIR" MAKEPKG_CMD="$WORK_DIR/makepkg-wrapper" bash "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh" > "$WORK_DIR/output.log" 2>&1; then
  :
else
  echo "update_aur_pkgbuild.sh unexpectedly failed with MAKEPKG_CMD override" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'makepkg-wrapper invoked:' "$MAKEPKG_LOG"; then
  echo "Expected makepkg wrapper invocation to be logged" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq '.SRCINFO from wrapper for 10.1.200' "$WORK_DIR/dist/aur/.SRCINFO"; then
  echo "Expected .SRCINFO generated via override wrapper" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'pkgver=10.1.200' "$WORK_DIR/dist/aur/PKGBUILD"; then
  echo "Expected PKGBUILD version substitution to succeed" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_makepkg_override] Passed"
