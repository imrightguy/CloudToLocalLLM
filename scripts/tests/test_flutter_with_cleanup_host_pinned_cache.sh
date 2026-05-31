#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/build/linux/x64/release"
BACKUP_ROOT="$(mktemp -d)"
WRAPPER_DIR="$(mktemp -d)"
WRAPPER_COPY="$WRAPPER_DIR/flutter_with_cleanup.sh"
HAD_ORIGINAL=0

restore_original() {
  rm -rf "$TARGET_DIR"
  if [[ "$HAD_ORIGINAL" -eq 1 ]]; then
    mv "$BACKUP_ROOT/original" "$TARGET_DIR"
  fi
  rm -rf "$BACKUP_ROOT" "$WRAPPER_DIR"
}

trap restore_original EXIT

if [[ -e "$TARGET_DIR" ]]; then
  mv "$TARGET_DIR" "$BACKUP_ROOT/original"
  HAD_ORIGINAL=1
fi

mkdir -p "$TARGET_DIR"
cat > "$TARGET_DIR/CMakeCache.txt" <<EOF
CMAKE_CACHEFILE_DIR:INTERNAL=$TARGET_DIR
CMAKE_HOME_DIRECTORY:INTERNAL=$PROJECT_ROOT/linux
GTK_INCLUDE_DIRS:INTERNAL=/usr/include/gtk-3.0;/usr/include/pango-1.0
EOF

cp "$PROJECT_ROOT/scripts/flutter_with_cleanup.sh" "$WRAPPER_COPY"
chmod +x "$WRAPPER_COPY"

echo "[test_flutter_with_cleanup_host_pinned_cache] Seeded host-pinned Linux CMake cache"
FLUTTER_BIN=/usr/bin/true "$WRAPPER_COPY" --version

test ! -e "$TARGET_DIR/CMakeCache.txt"
test ! -d "$TARGET_DIR"

echo "[test_flutter_with_cleanup_host_pinned_cache] Passed"
