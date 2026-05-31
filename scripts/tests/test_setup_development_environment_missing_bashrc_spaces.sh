#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home with spaces"
mkdir -p "$BIN_DIR" "$HOME_DIR"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$BIN_DIR/yes" <<'EOF'
#!/bin/bash
echo y
exit 0
EOF

for tool in sudo pacman yay npm ollama systemctl chown flutter git kubectl; do
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
REPO_ROOT="$PROJECT_ROOT" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1 || {
  status=$?
  echo "setup script failed with missing ~/.bashrc and spaced HOME harness (exit $status)" >&2
  exit "$status"
}

if [[ ! -f "$HOME_DIR/.bashrc" ]]; then
  echo "Expected spaced HOME to create ~/.bashrc" >&2
  exit 1
fi

path_count=$(grep -Fxc 'export PATH="$PATH:/opt/flutter/bin"' "$HOME_DIR/.bashrc")
chrome_count=$(grep -Fxc 'export CHROME_EXECUTABLE=/usr/bin/chromium' "$HOME_DIR/.bashrc")

if [[ "$path_count" -ne 1 ]]; then
  echo "Expected exactly one Flutter PATH export line in created bashrc under spaced HOME, found $path_count" >&2
  cat "$HOME_DIR/.bashrc" >&2
  exit 1
fi

if [[ "$chrome_count" -ne 1 ]]; then
  echo "Expected exactly one CHROME_EXECUTABLE export line in created bashrc under spaced HOME, found $chrome_count" >&2
  cat "$HOME_DIR/.bashrc" >&2
  exit 1
fi

echo "[test_setup_development_environment_missing_bashrc_spaces] Passed"
