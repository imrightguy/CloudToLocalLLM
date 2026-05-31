#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/tests/test_aur_package.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
KNOWN_STAGING_DIR="$WORK_DIR/staging-dir"
OUTPUT_FILE="$WORK_DIR/stderr.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$WORK_DIR/build/linux/x64/release/bundle" "$WORK_DIR/build-tools/packaging/aur"
cp "$TARGET_SCRIPT" "$WORK_DIR/test_aur_package.sh"
chmod +x "$WORK_DIR/test_aur_package.sh"
cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$WORK_DIR/build-tools/packaging/aur/PKGBUILD"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$WORK_DIR/build/linux/x64/release/bundle/app" <<'EOF'
content
EOF

cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
if [[ "\$1" == "-d" ]]; then
  mkdir -p "$KNOWN_STAGING_DIR"
  printf '%s\n' "$KNOWN_STAGING_DIR"
  exit 0
fi
echo "Unexpected mktemp invocation: \$*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/mktemp"

cat > "$BIN_DIR/tar" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$BIN_DIR/tar"

cat > "$BIN_DIR/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/flutter_with_cleanup.sh"

cat > "$BIN_DIR/makepkg-wrapper" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/makepkg-wrapper"

if PATH="$BIN_DIR:$PATH" PROJECT_ROOT_OVERRIDE="$WORK_DIR" FLUTTER_CMD="$BIN_DIR/flutter_with_cleanup.sh" MAKEPKG_CMD="$BIN_DIR/makepkg-wrapper" bash "$WORK_DIR/test_aur_package.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "test_aur_package.sh unexpectedly succeeded when tar failed" >&2
  exit 1
fi

if [[ -d "$KNOWN_STAGING_DIR" ]]; then
  echo "Expected staging directory cleanup after tar failure, but $KNOWN_STAGING_DIR still exists" >&2
  exit 1
fi

echo "[test_aur_package_staging_cleanup_on_tar_failure] Passed"
