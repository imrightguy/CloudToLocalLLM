#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/remove_ur_appimage.sh"
WORK_DIR="$(mktemp -d)"
TMPDIR_ROOT="$WORK_DIR/nested/tmp/dir"
FAKE_BIN="$WORK_DIR/bin"
GIT_LOG="$WORK_DIR/git.log"
mkdir -p "$FAKE_BIN" "$TMPDIR_ROOT"
export GIT_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/git" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s|%s|%s\n' "$PWD" "${1:-}" "${*:2}" >> "$GIT_LOG"
case "${1:-}" in
  clone)
    mkdir -p aur-remove
    cd aur-remove
    : > PKGBUILD
    : > .SRCINFO
    ;;
  rm)
    shift
    rm -f "$@"
    ;;
  config|commit|push)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_BIN/git"

TMPDIR="$TMPDIR_ROOT" PATH="$FAKE_BIN:$PATH" bash "$TARGET_SCRIPT" >/tmp/test_remove_ur_appimage_nested_tmpdir.log 2>&1

if [[ ! -d "$TMPDIR_ROOT" ]]; then
  echo "Expected nested TMPDIR root to exist" >&2
  cat /tmp/test_remove_ur_appimage_nested_tmpdir.log >&2
  exit 1
fi

if find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'remove-ur-appimage.*' | grep -q .; then
  echo "Expected temporary workdir cleanup under nested TMPDIR" >&2
  find "$TMPDIR_ROOT" -maxdepth 1 -type d -name 'remove-ur-appimage.*' >&2
  cat /tmp/test_remove_ur_appimage_nested_tmpdir.log >&2
  exit 1
fi

if ! grep -Fq '|clone|ssh://aur@aur.archlinux.org/cloudtolocalllm-appimage.git aur-remove' "$GIT_LOG"; then
  echo "Expected git clone to be invoked" >&2
  cat "$GIT_LOG" >&2
  exit 1
fi

echo "[test_remove_ur_appimage_nested_tmpdir] Passed"
