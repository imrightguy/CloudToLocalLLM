#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_full.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
REPO_ROOT="$WORKDIR/repo"
LOG_FILE="$WORKDIR/calls.log"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$HOME_DIR/flutter" "$REPO_ROOT/services/api-backend"

cat > "$HOME_DIR/.nvm/nvm.sh" <<'EOF'
#!/bin/bash
nvm() { :; }
EOF

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/apt-get" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/git" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/node" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/npm" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/ollama" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/kubectl" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/flutter" <<'EOF'
#!/bin/bash
echo "flutter $*" >> "$LOG_FILE"
exit 0
EOF

for tool in sudo apt-get curl git node npm ollama kubectl flutter; do
  chmod +x "$BIN_DIR/$tool"
done

cat > "$REPO_ROOT/package.json" <<'EOF'
{"name":"test-repo"}
EOF

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
REPO_ROOT="$REPO_ROOT" \
BASHRC="$HOME_DIR/.bashrc" \
FLUTTER_CMD="$BIN_DIR/flutter" \
LOG_FILE="$LOG_FILE" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1

test -f "$HOME_DIR/.bashrc"
grep -q 'export PATH="$HOME/flutter/bin:$PATH"' "$HOME_DIR/.bashrc"
grep -q '^flutter pub get$' "$LOG_FILE"

echo "[test_setup_wsl_full_flutter_cmd_override] Passed"