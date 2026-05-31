#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
STAGING_DIR="$WORK_DIR/staging"
OUTPUT_DIR="$WORK_DIR/dist/aur"
APPIMAGE_DIR="$WORK_DIR/dist/linux"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$APPIMAGE_DIR" "$WORK_DIR/build-tools/packaging/aur" "$WORK_DIR/scripts/packaging"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"
chmod +x "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$WORK_DIR/build-tools/packaging/aur/PKGBUILD"
: > "$APPIMAGE_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage"

cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
mkdir -p "$STAGING_DIR"
printf '%s\n' "$STAGING_DIR"
EOF
chmod +x "$BIN_DIR/mktemp"

cat > "$BIN_DIR/makepkg" <<'EOF'
#!/bin/bash
exit 7
EOF
chmod +x "$BIN_DIR/makepkg"

if PATH="$BIN_DIR:$PATH" bash "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh" >"$WORK_DIR/output.log" 2>&1; then
  echo "update_aur_pkgbuild.sh unexpectedly succeeded in failure-path harness" >&2
  exit 1
fi

if [[ -e "$STAGING_DIR" ]]; then
  echo "Expected staging cleanup, but $STAGING_DIR still exists" >&2
  exit 1
fi

if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Expected no final AUR output directory after failure, but $OUTPUT_DIR exists" >&2
  exit 1
fi

if ! grep -Fq 'Generating .SRCINFO' "$WORK_DIR/output.log"; then
  echo "Expected makepkg stage to be reached before failure" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_cleanup] Passed"
