#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_user.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
PROJECT_DIR="$WORKDIR/project"
LOG_FILE="$WORKDIR/script.log"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$PROJECT_DIR" "$PROJECT_DIR/services/api-backend"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

make_stub() {
  local name="$1"
  local body="$2"
  cat > "$BIN_DIR/$name" <<EOF
#!/bin/bash
set -euo pipefail
$body
EOF
  chmod +x "$BIN_DIR/$name"
}

make_stub curl 'exit 0'
make_stub git 'exit 0'
make_stub npm 'exit 0'
make_stub flutter 'case "${1:-}" in config|pub|get|--version|version) exit 0 ;; *) exit 0 ;; esac'
make_stub node 'echo "v24.0.0"'
make_stub ollama 'echo "ollama 0.0.0"'
make_stub kubectl 'echo "kubectl client"'

cat > "$BIN_DIR/flutter-wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "flutter-wrapper $*"
exit 0
EOF
chmod +x "$BIN_DIR/flutter-wrapper"

cat > "$HOME_DIR/.nvm/nvm.sh" <<'EOF'
#!/bin/bash
nvm() {
  case "${1:-}" in
    install|use) return 0 ;;
    *) return 0 ;;
  esac
}
EOF
chmod +x "$HOME_DIR/.nvm/nvm.sh"

printf '%s\n' '{"name":"cloudtolocalllm"}' > "$PROJECT_DIR/package.json"

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
PROJECT_DIR="$PROJECT_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter-wrapper" \
bash "$TARGET_SCRIPT" >"$LOG_FILE" 2>&1

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC_FILE to be created" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'export PATH="$HOME/flutter/bin:$PATH"' "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected Flutter PATH export once in custom bashrc" >&2
  cat "$BASHRC_FILE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "Installing Project Dependencies..." "$LOG_FILE"; then
  echo "Expected project dependency phase output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "flutter-wrapper pub get" "$LOG_FILE"; then
  echo "Expected custom FLUTTER_CMD wrapper invocation" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "Node: v24.0.0" "$LOG_FILE"; then
  echo "Expected node verification output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "NPM:" "$LOG_FILE"; then
  echo "Expected npm verification output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_setup_wsl_user_bashrc_override] Passed"
