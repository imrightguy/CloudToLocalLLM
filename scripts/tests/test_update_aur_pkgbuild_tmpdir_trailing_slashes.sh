#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_TOOLS="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/makepkg.log"
TMP_OUTPUT_DIR="$FAKE_ROOT/dist/aur"
TMPDIR_BASE="$WORK_DIR/trailing/tmpdir/base"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_ROOT/build-tools/packaging/aur" "$FAKE_ROOT/dist/linux" "$TMP_OUTPUT_DIR" "$FAKE_TOOLS"
export LOG_FILE

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 1.2.3+9
EOF

cat > "$FAKE_ROOT/build-tools/packaging/aur/PKGBUILD" <<'EOF'
pkgname=cloudtolocalllm-appimage
pkgver=VERSION
sha256sums=('SKIP')
EOF

printf 'appimage' > "$FAKE_ROOT/dist/linux/cloudtolocalllm-1.2.3-x86_64.AppImage"

cat > "$FAKE_TOOLS/makepkg" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'makepkg %s\n' "$*" >> "$LOG_FILE"
cat <<'SRC' > .SRCINFO
pkgname = cloudtolocalllm-appimage
SRC
exit 0
EOF
chmod +x "$FAKE_TOOLS/makepkg"

TMPDIR="$TMPDIR_BASE////" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
MAKEPKG_CMD="$FAKE_TOOLS/makepkg" \
bash "$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh" >/tmp/test_update_aur_pkgbuild_tmpdir_trailing_slashes.log 2>&1

if [[ ! -d "$TMP_OUTPUT_DIR" ]]; then
  echo "Expected AUR output directory at $TMP_OUTPUT_DIR" >&2
  cat /tmp/test_update_aur_pkgbuild_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if ! grep -Fq 'pkgver=1.2.3' "$TMP_OUTPUT_DIR/PKGBUILD"; then
  echo "Expected updated PKGBUILD version in AUR output" >&2
  cat /tmp/test_update_aur_pkgbuild_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if ! grep -Fq 'sha256sums=' "$TMP_OUTPUT_DIR/PKGBUILD"; then
  echo "Expected checksum replacement in AUR output" >&2
  cat /tmp/test_update_aur_pkgbuild_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if ! grep -Fq 'makepkg --printsrcinfo' "$LOG_FILE"; then
  echo "Expected makepkg to be invoked for .SRCINFO generation" >&2
  cat /tmp/test_update_aur_pkgbuild_tmpdir_trailing_slashes.log >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_tmpdir_trailing_slashes] Passed"
