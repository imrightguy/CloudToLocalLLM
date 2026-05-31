#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/custom.bashrc"
CALLS_LOG="$WORKDIR/calls.log"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$HOME_DIR/.config/opencode"
export CALLS_LOG

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
make_stub pacman 'exit 0'
make_stub git 'exit 0'
make_stub npm 'exit 0'
make_stub systemctl 'exit 0'
make_stub yay 'exit 0'
make_stub node 'echo "v24.0.0"'
make_stub flutter 'echo "flutter-stub $*"'

cat > "$BIN_DIR/flutter-wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "flutter-wrapper $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/flutter-wrapper"

cat > "$BIN_DIR/ollama-wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ollama-wrapper $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/ollama-wrapper"

cat > "$BIN_DIR/kubectl-wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "kubectl-wrapper $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/kubectl-wrapper"

env -u USER \
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
FLUTTER_INSTALL_DIR="$WORKDIR/flutter-install" \
FLUTTER_CMD="$BIN_DIR/flutter-wrapper" \
OLLAMA_CMD="$BIN_DIR/ollama-wrapper" \
KUBECTL_CMD="$BIN_DIR/kubectl-wrapper" \
bash "$TARGET_SCRIPT" >"$WORKDIR/output.log" 2>&1

if ! grep -Fq 'flutter-wrapper --version' "$CALLS_LOG"; then
  echo "Expected custom FLUTTER_CMD version check" >&2
  cat "$CALLS_LOG" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'flutter-wrapper pub get' "$CALLS_LOG"; then
  echo "Expected custom FLUTTER_CMD wrapper invocation" >&2
  cat "$CALLS_LOG" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'ollama-wrapper pull gemma3' "$CALLS_LOG"; then
  echo "Expected custom OLLAMA_CMD wrapper invocation" >&2
  cat "$CALLS_LOG" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'kubectl-wrapper version --client' "$CALLS_LOG"; then
  echo "Expected custom KUBECTL_CMD wrapper invocation" >&2
  cat "$CALLS_LOG" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'Setup complete! Please restart your terminal' "$WORKDIR/output.log"; then
  echo "Expected setup completion message" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC_FILE to be created" >&2
  exit 1
fi

if [[ $(grep -Fxc "export PATH=\"\$PATH:$WORKDIR/flutter-install/bin\"" "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected custom flutter install PATH export once in custom bashrc" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

echo "[test_setup_development_environment_command_overrides] Passed"
