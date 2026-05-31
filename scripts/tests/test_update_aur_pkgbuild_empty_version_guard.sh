#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/update_aur_pkgbuild.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
OUTPUT_FILE="$WORK_DIR/stderr.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$WORK_DIR/build-tools/packaging/aur" "$WORK_DIR/dist/linux" "$WORK_DIR/scripts/packaging"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"
chmod +x "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh"
cp "$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD" "$WORK_DIR/build-tools/packaging/aur/PKGBUILD"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version:
description: Test pubspec with empty version
EOF

cat > "$BIN_DIR/mktemp" <<'EOF'
#!/bin/bash
if [[ "$1" == "-d" && "$2" == "-t" && "$3" == cloudtolocalllm-aur.XXXXXX ]]; then
  dir="/tmp/cloudtolocalllm-aur-test.$$"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
  exit 0
fi
if [[ "$1" == "-d" && "$2" == "-p" && "$3" == /tmp && "$4" == .aur-backup.XXXXXX ]]; then
  dir="/tmp/.aur-backup-test.$$"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
  exit 0
fi
echo "Unexpected mktemp invocation: $*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/mktemp"

if PATH="$BIN_DIR:$PATH" SCRIPT_DIR_OVERRIDE="$WORK_DIR/scripts/packaging" PROJECT_ROOT_OVERRIDE="$WORK_DIR" bash "$WORK_DIR/scripts/packaging/update_aur_pkgbuild.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "update_aur_pkgbuild.sh unexpectedly succeeded with empty version entry" >&2
  exit 1
fi

if ! grep -q "version entry is empty in pubspec.yaml" "$OUTPUT_FILE"; then
  echo "Expected empty version entry error message" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_update_aur_pkgbuild_empty_version_guard] Passed"
