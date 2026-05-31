#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home dir with spaces"
FAKE_ROOT="$WORKDIR/fake repo root with spaces"
BASHRC_FILE="$HOME_DIR/config/custom bashrc"
LOG_FILE="$WORKDIR/script.log"
NPM_LOG="$WORKDIR/npm.log"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$FAKE_ROOT/scripts" "$FAKE_ROOT/services/api-backend" "$FAKE_ROOT/services/streaming-proxy" "$FAKE_ROOT/services/sdk" "$FAKE_ROOT/backend/auth"
export NPM_LOG

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
make_stub systemctl 'exit 0'
make_stub yay 'exit 0'
make_stub ollama 'exit 0'
make_stub kubectl 'exit 0'

cat > "$BIN_DIR/npm" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'cwd:%s %s\n' "$PWD" "$*" >> "$NPM_LOG"
exit 0
EOF
chmod +x "$BIN_DIR/npm"

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  --version)
    echo "Flutter 3.99.0"
    exit 0
    ;;
  pub|clean|build|config|doctor)
    echo "fake-root-flutter:$PWD:$*"
    exit 0
    ;;
  *)
    echo "fake-root-flutter:$PWD:$*"
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

mkdir -p "$(dirname "$BASHRC_FILE")"

env -u USER \
  HOME="$HOME_DIR" \
  PATH="$BIN_DIR:$PATH" \
  BASHRC_FILE="$BASHRC_FILE" \
  PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
  bash "$TARGET_SCRIPT" >"$LOG_FILE" 2>&1

if ! grep -Fq "Target directory: $FAKE_ROOT" "$LOG_FILE"; then
  echo "Expected the script to target the spaced PROJECT_ROOT_OVERRIDE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'fake-root-flutter:' "$LOG_FILE"; then
  echo "Expected the fake flutter wrapper under the spaced project root to be used" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if grep -Fq 'unexpected-system-flutter' "$LOG_FILE"; then
  echo "Expected the system flutter stub to remain unused" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected the custom bashrc file to be created under the spaced home directory" >&2
  exit 1
fi

if [[ ! -f "$NPM_LOG" ]]; then
  echo "Expected npm invocations to be logged" >&2
  exit 1
fi

for expected in \
  "cwd:$FAKE_ROOT install" \
  "cwd:$FAKE_ROOT/services/api-backend install" \
  "cwd:$FAKE_ROOT/services/streaming-proxy install" \
  "cwd:$FAKE_ROOT/services/sdk install" \
  "cwd:$FAKE_ROOT/backend/auth install"; do
  if ! grep -Fq "$expected" "$NPM_LOG"; then
    echo "Missing expected npm invocation: $expected" >&2
    cat "$NPM_LOG" >&2
    exit 1
  fi
 done

if ! grep -Fq 'Setup complete! Please restart your terminal' "$LOG_FILE"; then
  echo "Expected setup completion message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_setup_development_environment_project_root_spaces] Passed"
