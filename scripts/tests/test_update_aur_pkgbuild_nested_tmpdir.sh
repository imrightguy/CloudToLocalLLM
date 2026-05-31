#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
TMPDIR_OVERRIDE="$WORK_DIR/nested/tmp/aur"
mkdir -p "$FAKE_ROOT/build-tools/packaging/aur" "$FAKE_ROOT/dist" "$FAKE_ROOT/dist/linux"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: fake_app
version: 10.1.200+4200
EOF

cat > "$FAKE_ROOT/build-tools/packaging/aur/PKGBUILD" <<'EOF'
pkgname=cloudtolocalllm
pkgver=VERSION
sha256sums=('SKIP')
EOF

PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" TMPDIR="$TMPDIR_OVERRIDE" MAKEPKG_CMD= bash "$TARGET_SCRIPT" >/tmp/test_update_aur_pkgbuild_nested_tmpdir.log 2>&1

if [[ ! -d "$TMPDIR_OVERRIDE" ]]; then
  echo "Expected nested TMPDIR override to be created" >&2
  cat /tmp/test_update_aur_pkgbuild_nested_tmpdir.log >&2
  exit 1
fi

if [[ ! -d "$FAKE_ROOT/dist/aur" ]]; then
  echo "Expected AUR output directory to be created" >&2
  cat /tmp/test_update_aur_pkgbuild_nested_tmpdir.log >&2
  exit 1
fi

if ! grep -Fq 'pkgver=10.1.200' "$FAKE_ROOT/dist/aur/PKGBUILD"; then
  echo "PKGBUILD version was not updated" >&2
  cat "$FAKE_ROOT/dist/aur/PKGBUILD" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_nested_tmpdir] Passed"
