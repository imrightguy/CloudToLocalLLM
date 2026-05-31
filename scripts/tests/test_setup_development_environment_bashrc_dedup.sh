#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
mkdir -p "$BIN_DIR" "$HOME_DIR"

cat > "$BIN_DIR/yes" <<'EOF'
#!/bin/bash
echo y
exit 0
EOF

for tool in sudo pacman yay npm ollama systemctl chown flutter yes; do
  cat > "$BIN_DIR/$tool" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$BIN_DIR/$tool"
done

cat > "$HOME_DIR/.bashrc" <<'EOF'
# preexisting shell config
export CHROME_EXECUTABLE=/usr/bin/chromium
export PATH="$HOME/.local/bin:$PATH"
# mention CHROME_EXECUTABLE in a comment should not count as the exact line below
# CHROME_EXECUTABLE is managed by setup tooling
EOF

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
USER="$(id -un)" \
FLUTTER_CMD="$BIN_DIR/flutter" \
REPO_ROOT="$PROJECT_ROOT" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1 || {
  status=$?
  echo "setup script failed during bashrc dedup smoke harness (exit $status)" >&2
  exit "$status"
}

chrome_count=$(grep -Fxc 'export CHROME_EXECUTABLE=/usr/bin/chromium' "$HOME_DIR/.bashrc")
path_count=$(grep -Fxc 'export PATH="$PATH:/opt/flutter/bin"' "$HOME_DIR/.bashrc")
comment_count=$(grep -Fc 'CHROME_EXECUTABLE' "$HOME_DIR/.bashrc")

if [[ "$chrome_count" -ne 1 ]]; then
  echo "Expected exactly one CHROME_EXECUTABLE export line, found $chrome_count" >&2
  exit 1
fi

if [[ "$path_count" -ne 1 ]]; then
  echo "Expected exactly one Flutter PATH export line, found $path_count" >&2
  exit 1
fi

if [[ "$comment_count" -lt 2 ]]; then
  echo "Expected comments and exact exports to remain present" >&2
  exit 1
fi

echo "[test_setup_development_environment_bashrc_dedup] Passed"
