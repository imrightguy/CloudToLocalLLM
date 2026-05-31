#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
OUTPUT_DIR="$WORK_DIR/dist/aur"
STAGING_DIR="$WORK_DIR/tmp/staging-dir"
BACKUP_DIR="$WORK_DIR/tmp/backup-dir"
APPIMAGE_DIR="$WORK_DIR/dist/linux"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$APPIMAGE_DIR" "$OUTPUT_DIR" "$WORK_DIR/build-tools/packaging/aur" "$WORK_DIR/scripts/packaging"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"
chmod +x "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$WORK_DIR/build-tools/packaging/aur/PKGBUILD"
echo 'keep-me' > "$OUTPUT_DIR/original.txt"
: > "$APPIMAGE_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage"

cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
case "\$*" in
  *cloudtolocalllm-aur.XXXXXX*)
    mkdir -p "$STAGING_DIR"
    printf '%s\n' "$STAGING_DIR"
    ;;
  *\.aur-backup.XXXXXX*)
    mkdir -p "$BACKUP_DIR"
    printf '%s\n' "$BACKUP_DIR"
    ;;
  *)
    echo "Unexpected mktemp invocation: \$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$BIN_DIR/mktemp"

cat > "$BIN_DIR/makepkg" <<'EOF'
#!/bin/bash
printf '.SRCINFO for 10.1.200\n'
EOF
chmod +x "$BIN_DIR/makepkg"

PATH="$BIN_DIR:$PATH" bash "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh" >"$WORK_DIR/output.log" 2>&1

if [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "Expected final AUR output directory to exist after success" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if [[ -e "$BACKUP_DIR" ]]; then
  echo "Expected backup directory cleanup after success, but $BACKUP_DIR still exists" >&2
  ls -ld "$BACKUP_DIR" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if [[ -e "$OUTPUT_DIR/original.txt" ]]; then
  echo "Expected stale AUR contents to be replaced on success" >&2
  ls -l "$OUTPUT_DIR" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'pkgver=10.1.200' "$OUTPUT_DIR/PKGBUILD"; then
  echo "Expected PKGBUILD to contain updated version" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq '.SRCINFO for 10.1.200' "$OUTPUT_DIR/.SRCINFO"; then
  echo "Expected .SRCINFO to be generated in final output" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_success_cleanup] Passed"
