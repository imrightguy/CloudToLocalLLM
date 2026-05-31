#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/remove_ur_appimage.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
TEMP_DIR="$WORKDIR/aur-temp"
LOG_FILE="$WORKDIR/git.log"
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
if [[ "\$1" == "-d" ]]; then
  mkdir -p "$TEMP_DIR"
  printf '%s\n' "$TEMP_DIR"
  exit 0
fi
exit 1
EOF

cat > "$BIN_DIR/git" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "\$*" >> "$LOG_FILE"
if [[ "\$1" == "clone" ]]; then
  exit 1
fi
exit 0
EOF

chmod +x "$BIN_DIR/mktemp" "$BIN_DIR/git"

if HOME="$WORKDIR/home" PATH="$BIN_DIR:$PATH" bash "$TARGET_SCRIPT" >/dev/null 2>&1; then
  echo "remove_ur_appimage.sh unexpectedly succeeded in failure-path harness" >&2
  exit 1
fi

if [[ -d "$TEMP_DIR" ]]; then
  echo "Expected temp dir cleanup, but $TEMP_DIR still exists" >&2
  exit 1
fi

if ! grep -Fxq 'clone ssh://aur@aur.archlinux.org/cloudtolocalllm-appimage.git aur-remove' "$LOG_FILE"; then
  echo "Expected git clone to run before failure" >&2
  exit 1
fi

echo "[test_remove_ur_appimage_tempdir_cleanup] Passed"
