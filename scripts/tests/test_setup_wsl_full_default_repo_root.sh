#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_full.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
LOG_FILE="$WORKDIR/script.log"
FLUTTER_INSTALL_DIR="$WORKDIR/flutter-install"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$HOME_DIR/flutter" "$FLUTTER_INSTALL_DIR" "$PROJECT_ROOT/services/api-backend"

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

make_stub sudo 'exit 0'
make_stub apt-get 'exit 0'
make_stub curl 'exit 0'
make_stub git 'exit 0'
make_stub node 'echo "v24.0.0"'
make_stub ollama 'echo "ollama 0.0.0"'
make_stub kubectl 'echo "kubectl client"'
make_stub npm 'echo "npm:$PWD:$*" >> "${LOG_FILE:?missing LOG_FILE}"'
make_stub flutter-custom 'echo "flutter-custom:$PWD:$*" >> "${LOG_FILE:?missing LOG_FILE}"'

cat > "$HOME_DIR/.nvm/nvm.sh" <<'EOF'
#!/bin/bash
nvm() { :; }
EOF
chmod +x "$HOME_DIR/.nvm/nvm.sh"

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC="$BASHRC_FILE" \
FLUTTER_INSTALL_DIR="$FLUTTER_INSTALL_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter-custom" \
LOG_FILE="$LOG_FILE" \
bash "$TARGET_SCRIPT" >"$WORKDIR/output.log" 2>&1

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC file to be created" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq "flutter-custom:$PROJECT_ROOT:pub get" "$LOG_FILE"; then
  echo "Expected flutter pub get to run from the repo root by default" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "npm:$PROJECT_ROOT:install" "$LOG_FILE"; then
  echo "Expected root npm install to run from the repo root by default" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "npm:$PROJECT_ROOT/services/api-backend:install" "$LOG_FILE"; then
  echo "Expected backend npm install to run from the repo root by default" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

expected_path='export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"'
if [[ $(grep -Fxc "$expected_path" "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected Flutter PATH export once in custom bashrc" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

echo "PASS: scripts/setup/setup_wsl_full.sh resolves the default repo root from its location"
