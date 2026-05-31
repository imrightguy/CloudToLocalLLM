#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
FAKE_ROOT="$WORKDIR/fake-root"
BASHRC_FILE="$WORKDIR/config/custom.bashrc"
LOG_FILE="$WORKDIR/script.log"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$FAKE_ROOT/scripts" "$FAKE_ROOT/services/api-backend" "$FAKE_ROOT/services/streaming-proxy" "$FAKE_ROOT/services/sdk" "$FAKE_ROOT/backend/auth"

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
cat > "$BIN_DIR/npm" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "cwd:\$PWD \$*" >> "$WORKDIR/npm.log"
exit 0
EOF
chmod +x "$BIN_DIR/npm"
make_stub systemctl 'exit 0'
make_stub yay 'exit 0'
make_stub flutter 'echo "unexpected-system-flutter $*"'
make_stub ollama 'echo "ollama-stub $*"'
make_stub kubectl 'echo "kubectl-stub $*"'

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "fake-root-flutter $*"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

env -u USER \
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
bash "$TARGET_SCRIPT" >"$LOG_FILE" 2>&1

if ! grep -Fq 'fake-root-flutter pub get' "$LOG_FILE"; then
  echo "Expected PROJECT_ROOT_OVERRIDE to route FLUTTER_CMD to the fake repo root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if grep -Fq 'unexpected-system-flutter' "$LOG_FILE"; then
  echo "Expected the script to avoid the system flutter stub when PROJECT_ROOT_OVERRIDE is set" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'Setup complete! Please restart your terminal' "$LOG_FILE"; then
  echo "Expected setup completion message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC_FILE to be created" >&2
  exit 1
fi

if [[ ! -f "$WORKDIR/npm.log" ]]; then
  echo "Expected npm log to be created" >&2
  exit 1
fi

for expected in \
  "cwd:$FAKE_ROOT install" \
  "cwd:$FAKE_ROOT/services/api-backend install" \
  "cwd:$FAKE_ROOT/services/streaming-proxy install" \
  "cwd:$FAKE_ROOT/services/sdk install" \
  "cwd:$FAKE_ROOT/backend/auth install"; do
  if ! grep -Fq "$expected" "$WORKDIR/npm.log"; then
    echo "Missing expected npm invocation: $expected" >&2
    cat "$WORKDIR/npm.log" >&2
    exit 1
  fi
done

echo "[test_setup_development_environment_project_root_override] Passed"
