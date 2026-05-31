#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_full.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$HOME_DIR/flutter/bin"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$HOME_DIR/.nvm/nvm.sh" <<'EOF'
nvm() {
  case "$1" in
    install|use) return 0 ;;
    *) return 0 ;;
  esac
}
EOF

for tool in sudo curl git npm ollama kubectl node flutter; do
  cat > "$BIN_DIR/$tool" <<'EOF'
#!/bin/bash
case "$(basename "$0")" in
  node) echo 'v24.0.0' ;;
  npm) echo '10.0.0' ;;
  flutter) echo 'Flutter 3.0.0' ;;
  ollama) echo 'ollama 0.1.0' ;;
  kubectl) echo 'kubectl v1.30.0' ;;
  *) exit 0 ;;
esac
exit 0
EOF
  chmod +x "$BIN_DIR/$tool"
done

cat > "$HOME_DIR/flutter/bin/flutter" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$HOME_DIR/flutter/bin/flutter"

cat > "$HOME_DIR/.bashrc" <<'EOF'
# existing config
export PATH="$HOME/flutter/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# unrelated comment mentioning PATH should not affect dedup
EOF

PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
BASHRC="$HOME_DIR/.bashrc" \
REPO_ROOT="$PROJECT_ROOT" \
FLUTTER_CMD="$BIN_DIR/flutter" \
bash "$TARGET_SCRIPT" >/dev/null 2>&1 || {
  status=$?
  echo "setup_wsl_full.sh failed in bashrc dedup harness (exit $status)" >&2
  exit "$status"
}

path_count=$(grep -Fxc 'export PATH="$HOME/flutter/bin:$PATH"' "$HOME_DIR/.bashrc")
if [[ "$path_count" -ne 1 ]]; then
  echo "Expected exactly one flutter PATH export line, found $path_count" >&2
  exit 1
fi

nvm_dir_count=$(grep -Fxc 'export NVM_DIR="$HOME/.nvm"' "$HOME_DIR/.bashrc")
if [[ "$nvm_dir_count" -ne 1 ]]; then
  echo "Expected exactly one NVM_DIR export line, found $nvm_dir_count" >&2
  exit 1
fi

nvm_source_count=$(grep -Fxc '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' "$HOME_DIR/.bashrc")
if [[ "$nvm_source_count" -ne 1 ]]; then
  echo "Expected exactly one nvm source line, found $nvm_source_count" >&2
  exit 1
fi

echo "[test_setup_wsl_full_bashrc_dedup] Passed"
