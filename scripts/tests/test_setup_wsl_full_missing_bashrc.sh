#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_full.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
REPO_ROOT="$WORKDIR/repo"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$HOME_DIR/flutter" "$REPO_ROOT/services/api-backend"

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

export HOME="$HOME_DIR"
export PATH="$BIN_DIR:$PATH"
export REPO_ROOT="$REPO_ROOT"
export BASHRC="$HOME_DIR/.bashrc"

bash "$TARGET_SCRIPT" >/dev/null 2>&1

test -f "$BASHRC"
grep -q 'export PATH="$HOME/flutter/bin:$PATH"' "$BASHRC"

echo "[test_setup_wsl_full_missing_bashrc] Passed"
