#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_full.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
REPO_ROOT="$WORKDIR/repo"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$HOME_DIR/flutter" "$REPO_ROOT/services/api-backend"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$HOME_DIR/.nvm/nvm.sh" <<'EOF'
#!/bin/bash
nvm() { :; }
EOF

for tool in sudo apt-get curl git node npm flutter ollama kubectl; do
  cat > "$BIN_DIR/$tool" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$BIN_DIR/$tool"
done

cat > "$BIN_DIR/nvm" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/nvm"

cat > "$REPO_ROOT/package.json" <<'EOF'
{"name":"test-repo"}
EOF

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
REPO_ROOT="$REPO_ROOT" \
BASHRC="$BASHRC_FILE" \
FLUTTER_CMD="$BIN_DIR/flutter" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1 || {
  status=$?
  echo "setup_wsl_full.sh failed during nested bashrc override harness (exit $status)" >&2
  exit "$status"
}

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected nested BASHRC override to be created" >&2
  exit 1
fi

if ! grep -Fqx 'export PATH="$HOME/flutter/bin:$PATH"' "$BASHRC_FILE"; then
  echo "Expected PATH export in nested bashrc override" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

if ! grep -Fqx 'export NVM_DIR="$HOME/.nvm"' "$BASHRC_FILE"; then
  echo "Expected NVM_DIR export in nested bashrc override" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

echo "[test_setup_wsl_full_bashrc_override] Passed"
