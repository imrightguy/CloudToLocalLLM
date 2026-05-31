#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
FAKE_ROOT="$WORKDIR/fake-root"
BASHRC_FILE="$WORKDIR/config with spaces/custom bashrc"
CALLS_LOG="$WORKDIR/calls.log"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$HOME_DIR/.config/opencode" "$FAKE_ROOT/scripts" "$FAKE_ROOT/services/api-backend" "$FAKE_ROOT/services/streaming-proxy" "$FAKE_ROOT/services/sdk" "$FAKE_ROOT/backend/auth"
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
make_stub ollama 'echo "ollama-stub $*"'
make_stub kubectl 'echo "kubectl-stub $*"'

cat > "$BIN_DIR/flutter wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "flutter wrapper $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/flutter wrapper"

cat > "$BIN_DIR/ollama wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ollama wrapper $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/ollama wrapper"

cat > "$BIN_DIR/kubectl wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "kubectl wrapper $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/kubectl wrapper"

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "fake-root-flutter $*" >> "${CALLS_LOG:?missing CALLS_LOG}"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

set +e
env -u USER \
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
FLUTTER_CMD="$BIN_DIR/flutter wrapper" \
OLLAMA_CMD="$BIN_DIR/ollama wrapper" \
KUBECTL_CMD="$BIN_DIR/kubectl wrapper" \
"$TARGET_SCRIPT" >"$WORKDIR/output.log" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected setup-development-environment.sh to succeed with spaced command override paths" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'flutter wrapper --version' "$CALLS_LOG"; then
  echo "Expected spaced FLUTTER_CMD path to be invoked" >&2
  cat "$CALLS_LOG" >&2
  exit 1
fi

if ! grep -Fq 'ollama wrapper pull gemma3' "$CALLS_LOG"; then
  echo "Expected spaced OLLAMA_CMD path to be invoked" >&2
  cat "$CALLS_LOG" >&2
  exit 1
fi

if ! grep -Fq 'kubectl wrapper version --client' "$CALLS_LOG"; then
  echo "Expected spaced KUBECTL_CMD path to be invoked" >&2
  cat "$CALLS_LOG" >&2
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

echo "[test_setup_development_environment_command_paths_spaces] Passed"
