#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPERS_DIR="/paperclip/.local-toolchain/wrappers"
LINKER_ROOT="/paperclip/.local-toolchain/root/usr/bin"
BACKUP_ROOT="$(mktemp -d)"
WRAPPER_DIR="$(mktemp -d)"
WRAPPER_COPY="$WRAPPER_DIR/flutter_with_cleanup.sh"
FAKE_BIN_DIR="$(mktemp -d)"
FAKE_FLUTTER="$FAKE_BIN_DIR/flutter"
HAD_LD=0
HAD_LD_LLD=0
HAD_LD_LLD_19=0
HAD_AR=0
HAD_LLVM_AR=0
HAD_RANLIB=0
HAD_LLVM_RANLIB=0
HAD_STRIP=0
HAD_LLVM_STRIP=0

cleanup() {
  rm -f "$WRAPPERS_DIR/ld" "$WRAPPERS_DIR/ld.lld" "$WRAPPERS_DIR/ld.lld-19" "$WRAPPERS_DIR/ar" "$WRAPPERS_DIR/llvm-ar" "$WRAPPERS_DIR/ranlib" "$WRAPPERS_DIR/llvm-ranlib" "$WRAPPERS_DIR/strip" "$WRAPPERS_DIR/llvm-strip"
  if [[ "$HAD_LD" -eq 1 ]]; then
    mv "$BACKUP_ROOT/ld" "$WRAPPERS_DIR/ld"
  fi
  if [[ "$HAD_LD_LLD" -eq 1 ]]; then
    mv "$BACKUP_ROOT/ld.lld" "$WRAPPERS_DIR/ld.lld"
  fi
  if [[ "$HAD_LD_LLD_19" -eq 1 ]]; then
    mv "$BACKUP_ROOT/ld.lld-19" "$WRAPPERS_DIR/ld.lld-19"
  fi
  if [[ "$HAD_AR" -eq 1 ]]; then
    mv "$BACKUP_ROOT/ar" "$WRAPPERS_DIR/ar"
  fi
  if [[ "$HAD_LLVM_AR" -eq 1 ]]; then
    mv "$BACKUP_ROOT/llvm-ar" "$WRAPPERS_DIR/llvm-ar"
  fi
  if [[ "$HAD_RANLIB" -eq 1 ]]; then
    mv "$BACKUP_ROOT/ranlib" "$WRAPPERS_DIR/ranlib"
  fi
  if [[ "$HAD_LLVM_RANLIB" -eq 1 ]]; then
    mv "$BACKUP_ROOT/llvm-ranlib" "$WRAPPERS_DIR/llvm-ranlib"
  fi
  if [[ "$HAD_STRIP" -eq 1 ]]; then
    mv "$BACKUP_ROOT/strip" "$WRAPPERS_DIR/strip"
  fi
  if [[ "$HAD_LLVM_STRIP" -eq 1 ]]; then
    mv "$BACKUP_ROOT/llvm-strip" "$WRAPPERS_DIR/llvm-strip"
  fi
  rm -rf "$BACKUP_ROOT" "$WRAPPER_DIR" "$FAKE_BIN_DIR"
}

trap cleanup EXIT

if [[ -e "$WRAPPERS_DIR/ld" ]]; then
  mv "$WRAPPERS_DIR/ld" "$BACKUP_ROOT/ld"
  HAD_LD=1
fi
if [[ -e "$WRAPPERS_DIR/ld.lld-19" ]]; then
  mv "$WRAPPERS_DIR/ld.lld-19" "$BACKUP_ROOT/ld.lld-19"
  HAD_LD_LLD_19=1
fi
if [[ -e "$WRAPPERS_DIR/ar" ]]; then
  mv "$WRAPPERS_DIR/ar" "$BACKUP_ROOT/ar"
  HAD_AR=1
fi
if [[ -e "$WRAPPERS_DIR/llvm-ar" ]]; then
  mv "$WRAPPERS_DIR/llvm-ar" "$BACKUP_ROOT/llvm-ar"
  HAD_LLVM_AR=1
fi
if [[ -e "$WRAPPERS_DIR/ranlib" ]]; then
  mv "$WRAPPERS_DIR/ranlib" "$BACKUP_ROOT/ranlib"
  HAD_RANLIB=1
fi
if [[ -e "$WRAPPERS_DIR/llvm-ranlib" ]]; then
  mv "$WRAPPERS_DIR/llvm-ranlib" "$BACKUP_ROOT/llvm-ranlib"
  HAD_LLVM_RANLIB=1
fi
if [[ -e "$WRAPPERS_DIR/strip" ]]; then
  mv "$WRAPPERS_DIR/strip" "$BACKUP_ROOT/strip"
  HAD_STRIP=1
fi
if [[ -e "$WRAPPERS_DIR/llvm-strip" ]]; then
  mv "$WRAPPERS_DIR/llvm-strip" "$BACKUP_ROOT/llvm-strip"
  HAD_LLVM_STRIP=1
fi

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
for name in ld ld.lld ld.lld-19 ar llvm-ar ranlib llvm-ranlib strip llvm-strip; do
  if [[ ! -e "/paperclip/.local-toolchain/wrappers/$name" ]]; then
    echo "Expected wrapper to create $name symlink" >&2
    exit 1
  fi
done
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

cp "$PROJECT_ROOT/scripts/flutter_with_cleanup.sh" "$WRAPPER_COPY"
chmod +x "$WRAPPER_COPY"

PATH="/usr/local/bin:/usr/bin:/bin" FLUTTER_BIN="$FAKE_FLUTTER" "$WRAPPER_COPY" build linux --debug

[[ -L "$WRAPPERS_DIR/ld" ]]
[[ -L "$WRAPPERS_DIR/ld.lld" ]]
[[ -L "$WRAPPERS_DIR/ld.lld-19" ]]
[[ "$(readlink -f "$WRAPPERS_DIR/ld")" == "$(readlink -f "$LINKER_ROOT/ld")" ]]
[[ "$(readlink -f "$WRAPPERS_DIR/ld.lld")" == "$(readlink -f "$WRAPPERS_DIR/ld")" || "$(readlink -f "$WRAPPERS_DIR/ld.lld")" == "$(readlink -f "$LINKER_ROOT/ld.lld")" ]]

echo "[test_flutter_with_cleanup_linker_wrappers] Passed"
