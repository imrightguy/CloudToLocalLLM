#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/install.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/custom/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/bashrc"
ZSHRC_FILE="$WORKDIR/config/zshrc"
LOG_FILE="$WORKDIR/calls.log"
mkdir -p "$WORKDIR/config" "$BIN_DIR" "$HOME_DIR"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

make_stub() {
  local name="$1"
  local body="$2"
  cat > "$WORKDIR/$name" <<EOF
#!/bin/bash
set -euo pipefail
$body
EOF
  chmod +x "$WORKDIR/$name"
}

make_stub node 'echo "v22.8.0"'
make_stub npm 'printf "npm:%s:%s\n" "$PWD" "$*" >> "$LOG_FILE"'

HOME="$HOME_DIR" \
PATH="$WORKDIR:$PATH" \
BIN_DIR="$BIN_DIR" \
BASHRC_FILE="$BASHRC_FILE" \
ZSHRC_FILE="$ZSHRC_FILE" \
LOG_FILE="$LOG_FILE" \
env -u SHELL bash "$TARGET_SCRIPT" > "$WORKDIR/output.log" 2>&1

expected_line="export PATH=\"\$PATH:$BIN_DIR\""

if [[ ! -d "$BIN_DIR" ]]; then
  echo "Expected custom BIN_DIR to be created" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected fallback bashrc file to be created when SHELL is unset" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if [[ $(grep -Fxc "$expected_line" "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected PATH export to be appended to the custom bashrc file" >&2
  cat "$BASHRC_FILE" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if grep -Fq "$ZSHRC_FILE" "$WORKDIR/output.log"; then
  echo "Unexpected zshrc path usage when SHELL is unset" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq "install -g openclaw-gateway" "$LOG_FILE"; then
  echo "Expected npm install -g openclaw-gateway to be routed through the stub" >&2
  cat "$LOG_FILE" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

echo "PASS: scripts/install.sh respects BIN_DIR/BASHRC_FILE and SHELL fallback"
