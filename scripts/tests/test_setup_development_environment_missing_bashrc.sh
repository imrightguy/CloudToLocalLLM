#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
LOG_FILE="$WORKDIR/calls.log"
mkdir -p "$BIN_DIR" "$HOME_DIR"

cat > "$BIN_DIR/yes" <<'EOF'
#!/bin/bash
echo y
exit 0
EOF

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/pacman" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/yay" <<'EOF'
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

cat > "$BIN_DIR/systemctl" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/chown" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$BIN_DIR/flutter" <<'EOF'
#!/bin/bash
cat >/dev/null
exit 0
EOF

for tool in yes sudo pacman yay npm ollama systemctl chown flutter; do
  chmod +x "$BIN_DIR/$tool"
done

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
USER="$(id -un)" \
LOG_FILE="$LOG_FILE" \
FLUTTER_CMD="$BIN_DIR/flutter" \
REPO_ROOT="$PROJECT_ROOT" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1 || {
  status=$?
  echo "setup script failed with missing ~/.bashrc smoke harness (exit $status)" >&2
  exit "$status"
}

test -f "$HOME_DIR/.bashrc"

path_count=$(grep -Fxc 'export PATH="$PATH:/opt/flutter/bin"' "$HOME_DIR/.bashrc")
chrome_count=$(grep -Fxc 'export CHROME_EXECUTABLE=/usr/bin/chromium' "$HOME_DIR/.bashrc")

if [[ "$path_count" -ne 1 ]]; then
  echo "Expected exactly one Flutter PATH export line in created bashrc, found $path_count" >&2
  exit 1
fi

if [[ "$chrome_count" -ne 1 ]]; then
  echo "Expected exactly one CHROME_EXECUTABLE export line in created bashrc, found $chrome_count" >&2
  exit 1
fi

echo "[test_setup_development_environment_missing_bashrc] Passed"
