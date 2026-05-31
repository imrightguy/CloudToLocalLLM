#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/tests/test_aur_package.sh"
WORK_DIR="$(mktemp -d)"
OUTPUT_FILE="$WORK_DIR/stderr.txt"
BIN_DIR="$WORK_DIR/bin"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/build/linux/x64/release/bundle" "$WORK_DIR/build-tools/packaging/aur" "$BIN_DIR"
cp "$TARGET_SCRIPT" "$WORK_DIR/test_aur_package.sh"
chmod +x "$WORK_DIR/test_aur_package.sh"
cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$WORK_DIR/build-tools/packaging/aur/PKGBUILD"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 10.1.200+4200
EOF

cat > "$WORK_DIR/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$WORK_DIR/flutter_with_cleanup.sh"

cat > "$BIN_DIR/mktemp" <<'EOF'
#!/bin/bash
if [[ "$1" == "-d" ]]; then
  dir="/tmp/cloudtolocalllm-empty-bundle.$$"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
  exit 0
fi
echo "Unexpected mktemp invocation: $*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/mktemp"

cat > "$BIN_DIR/tar" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/tar"

cat > "$WORK_DIR/makepkg-wrapper" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$WORK_DIR/makepkg-wrapper"

if PATH="$BIN_DIR:$PATH" PROJECT_ROOT_OVERRIDE="$WORK_DIR" FLUTTER_CMD="$WORK_DIR/flutter_with_cleanup.sh" MAKEPKG_CMD="$WORK_DIR/makepkg-wrapper" bash "$WORK_DIR/test_aur_package.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "test_aur_package.sh unexpectedly succeeded with empty build bundle" >&2
  exit 1
fi

if ! grep -q "Flutter Linux build bundle is empty" "$OUTPUT_FILE"; then
  echo "Expected empty build bundle error message" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_aur_package_empty_build_bundle_guard] Passed"
