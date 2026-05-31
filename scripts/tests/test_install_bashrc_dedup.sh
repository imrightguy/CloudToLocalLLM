#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
BASHRC="$WORK_DIR/.bashrc"
NPM_LOG="$WORK_DIR/npm.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN"
: > "$BASHRC"

cat > "$FAKE_BIN/node" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$FAKE_BIN/node"

cat > "$FAKE_BIN/npm" <<EOF
#!/bin/bash
printf '%s\n' "npm \$*" >> "$NPM_LOG"
exit 0
EOF
chmod +x "$FAKE_BIN/npm"

PATH="$FAKE_BIN:$PATH" HOME="$WORK_DIR" SHELL=/bin/bash bash "$INSTALL_SCRIPT" >/tmp/test_install_bashrc_dedup.log 2>&1
PATH="$FAKE_BIN:$PATH" HOME="$WORK_DIR" SHELL=/bin/bash bash "$INSTALL_SCRIPT" >/tmp/test_install_bashrc_dedup.log 2>&1

if [[ ! -f "$BASHRC" ]]; then
  echo "Expected .bashrc to be created" >&2
  cat /tmp/test_install_bashrc_dedup.log >&2
  exit 1
fi

if [[ $(grep -Fx "export PATH=\"\$PATH:$WORK_DIR/.local/bin\"" "$BASHRC" | wc -l) -ne 1 ]]; then
  echo "Expected PATH line to be appended exactly once" >&2
  cat "$BASHRC" >&2
  cat /tmp/test_install_bashrc_dedup.log >&2
  exit 1
fi

if [[ $(grep -Fxc "export PATH=\"\$PATH:$WORK_DIR/.local/bin\"" "$BASHRC") -ne 1 ]]; then
  echo "Expected a single exact PATH line in .bashrc" >&2
  cat "$BASHRC" >&2
  exit 1
fi

if [[ $(wc -l < "$NPM_LOG") -ne 2 ]]; then
  echo "Expected fake npm to be invoked on both runs" >&2
  cat "$NPM_LOG" >&2
  exit 1
fi

echo "[test_install_bashrc_dedup] Passed"
