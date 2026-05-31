#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
TMPDIR_BASE="$WORK_DIR/trailing/tmpdir/base"
FAKE_HOME="$WORK_DIR/home"
FAKE_GIT="$WORK_DIR/git"
LOG_FILE="$WORK_DIR/invocations.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR_BASE" "$FAKE_HOME" "$WORK_DIR/bin"
export LOG_FILE

cat > "$FAKE_GIT" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'git %s\n' "$*" >> "$LOG_FILE"
case "$1" in
  clone)
    mkdir -p "$3"
    ;;
  rm)
    ;;
  config)
    ;;
  commit)
    ;;
  push)
    ;;
esac
exit 0
EOF
chmod +x "$FAKE_GIT"

TMPDIR="$TMPDIR_BASE////" \
HOME="$FAKE_HOME" \
PATH="$WORK_DIR:/usr/bin:/bin" \
"$PROJECT_ROOT/scripts/packaging/remove_ur_appimage.sh" >/tmp/test_remove_ur_appimage_tmpdir_trailing_slashes.log 2>&1

if ! grep -Fq 'git clone ssh://aur@aur.archlinux.org/cloudtolocalllm-appimage.git aur-remove' "$LOG_FILE"; then
  echo "Expected remove_ur_appimage.sh to clone the AUR repo" >&2
  cat /tmp/test_remove_ur_appimage_tmpdir_trailing_slashes.log >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_remove_ur_appimage_tmpdir_trailing_slashes] Passed"
