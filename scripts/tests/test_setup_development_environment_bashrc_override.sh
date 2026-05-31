#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/custom.bashrc"
mkdir -p "$BIN_DIR" "$HOME_DIR"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

for tool in yes sudo pacman yay npm ollama systemctl chown flutter git; do
  cat > "$BIN_DIR/$tool" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$BIN_DIR/$tool"
done

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
USER="$(id -un)" \
FLUTTER_CMD="$BIN_DIR/flutter" \
BASHRC_FILE="$BASHRC_FILE" \
REPO_ROOT="$PROJECT_ROOT" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1 || {
  status=$?
  echo "setup script failed during custom bashrc override harness (exit $status)" >&2
  exit "$status"
}

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC_FILE to be created" >&2
  exit 1
fi

path_count=$(grep -Fxc 'export PATH="$PATH:/opt/flutter/bin"' "$BASHRC_FILE")
chrome_count=$(grep -Fxc 'export CHROME_EXECUTABLE=/usr/bin/chromium' "$BASHRC_FILE")

if [[ "$path_count" -ne 1 ]]; then
  echo "Expected exactly one Flutter PATH export line in custom bashrc, found $path_count" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

if [[ "$chrome_count" -ne 1 ]]; then
  echo "Expected exactly one CHROME_EXECUTABLE export line in custom bashrc, found $chrome_count" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

echo "[test_setup_development_environment_bashrc_override] Passed"
