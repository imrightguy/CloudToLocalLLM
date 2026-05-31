#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_user.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
FAKE_ROOT="$WORKDIR/fake-root"
FLUTTER_INSTALL_DIR="$WORKDIR/flutter-install"
LOG_FILE="$WORKDIR/script.log"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$FAKE_ROOT/services/api-backend" "$FLUTTER_INSTALL_DIR"

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
make_stub node 'echo "v24.0.0"'
make_stub ollama 'echo "ollama 0.0.0"'
make_stub kubectl 'echo "kubectl client"'
make_stub npm 'echo "npm:$PWD:$*"'
make_stub flutter-wrapper 'echo "flutter-wrapper:$PWD:$*"'

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

printf '%s\n' '{"name":"cloudtolocalllm"}' > "$FAKE_ROOT/package.json"

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
BASHRC_FILE="$BASHRC_FILE" \
FLUTTER_INSTALL_DIR="$FLUTTER_INSTALL_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter-wrapper" \
bash "$TARGET_SCRIPT" >"$LOG_FILE" 2>&1

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC_FILE to be created" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"' "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected Flutter PATH export once in custom bashrc" >&2
  cat "$BASHRC_FILE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "flutter-wrapper:$FAKE_ROOT:pub get" "$LOG_FILE"; then
  echo "Expected custom FLUTTER_CMD wrapper invocation in override root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "npm:$FAKE_ROOT:install" "$LOG_FILE"; then
  echo "Expected root npm install to run in override root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "npm:$FAKE_ROOT/services/api-backend:install" "$LOG_FILE"; then
  echo "Expected backend npm install to run in override root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "Node: v24.0.0" "$LOG_FILE"; then
  echo "Expected node verification output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "PASS: scripts/setup/setup_wsl_user.sh respects PROJECT_ROOT_OVERRIDE"
