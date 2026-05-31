#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/setup-opencode-mcp.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
HOME_DIR="$WORK_DIR/home"
BASHRC_FILE="$HOME_DIR/.bashrc"
PATH_LINE="export PATH=\"$HOME_DIR/.local/bin:\$PATH\""
LOG_FILE="$WORK_DIR/npm.log"
mkdir -p "$FAKE_BIN" "$HOME_DIR/.config/opencode" "$HOME_DIR/.local/bin"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/npm" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "npm $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/npm"

cat > "$FAKE_BIN/npx" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "npx $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/npx"

HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" OPENCODE_DIR="$HOME_DIR/.config/opencode" BIN_DIR="$HOME_DIR/.local/bin" BASHRC="$BASHRC_FILE" NPM_CMD=npm NPX_CMD=npx LOG_FILE="$LOG_FILE" "$TARGET_SCRIPT"
HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" OPENCODE_DIR="$HOME_DIR/.config/opencode" BIN_DIR="$HOME_DIR/.local/bin" BASHRC="$BASHRC_FILE" NPM_CMD=npm NPX_CMD=npx LOG_FILE="$LOG_FILE" "$TARGET_SCRIPT"

[[ -f "$HOME_DIR/.local/bin/mcp-sequentialthinking" ]]
[[ -f "$HOME_DIR/.local/bin/mcp-context7" ]]
[[ -f "$HOME_DIR/.local/bin/mcp-memory" ]]
grep -Fq 'exec "npx" -y @modelcontextprotocol/server-sequential-thinking "${@}"' "$HOME_DIR/.local/bin/mcp-sequentialthinking"
grep -Fq 'exec "npx" -y @upstash/context7-mcp "${@}"' "$HOME_DIR/.local/bin/mcp-context7"
grep -Fq 'exec "npx" -y @modelcontextprotocol/server-memory "${@}"' "$HOME_DIR/.local/bin/mcp-memory"
[[ $(grep -Fc "$PATH_LINE" "$BASHRC_FILE") -eq 1 ]]
grep -Fq 'npm install @modelcontextprotocol/server-sequential-thinking @upstash/context7-mcp @modelcontextprotocol/server-memory' "$LOG_FILE"

echo "[test_setup_opencode_mcp] Passed"
