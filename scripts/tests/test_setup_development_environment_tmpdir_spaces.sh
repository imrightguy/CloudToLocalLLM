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
CALLS_LOG="$WORKDIR/calls.log"
TMPDIR_RAW="$WORKDIR/nested tmp/dir with spaces////"
TMPDIR_EXPECTED="$WORKDIR/nested tmp/dir with spaces"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$FAKE_ROOT/scripts" "$FAKE_ROOT/services/api-backend" "$FAKE_ROOT/services/streaming-proxy" "$FAKE_ROOT/services/sdk" "$FAKE_ROOT/backend/auth" "$TMPDIR_EXPECTED"
export CALLS_LOG
export BIN_DIR

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
make_stub npm 'exit 0'
make_stub systemctl 'exit 0'
make_stub ollama 'echo "ollama-stub $*"'
make_stub kubectl 'echo "kubectl-stub $*"'
make_stub getent 'exit 1'
make_stub id 'if [[ "$1" == "-un" ]]; then echo "rook"; elif [[ "$1" == "-gn" ]]; then echo "rook"; else echo "rook"; fi'
make_stub makepkg 'echo "makepkg-stub $*" >> "$CALLS_LOG"; exit 0'
make_stub git 'printf "git:%s\n" "$*" >> "$CALLS_LOG"; if [[ "$1" == "clone" ]]; then mkdir -p "$3"; printf "#!/bin/bash\nset -euo pipefail\necho \"yay-stub $*\" >> \"$CALLS_LOG\"\nexit 0\n" > "$BIN_DIR/yay"; chmod +x "$BIN_DIR/yay"; fi; exit 0'

cat > "$FAKE_ROOT/scripts/flutter_with_cleanup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "fake-root-flutter $*"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/flutter_with_cleanup.sh"

set +e
env -u USER \
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
TMPDIR="$TMPDIR_RAW" \
"$TARGET_SCRIPT" >"$WORKDIR/output.log" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected setup-development-environment.sh to succeed with spaced TMPDIR" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq "git:clone https://aur.archlinux.org/yay.git $TMPDIR_EXPECTED/yay-install." "$CALLS_LOG"; then
  echo "Expected yay build dir to use normalized TMPDIR root with spaces" >&2
  cat "$CALLS_LOG" >&2
  exit 1
fi

if find "$TMPDIR_EXPECTED" -maxdepth 1 -type d -name 'yay-install.*' | grep -q .; then
  echo "Expected yay build directory cleanup under spaced TMPDIR root" >&2
  find "$TMPDIR_EXPECTED" -maxdepth 1 -type d -name 'yay-install.*' >&2
  exit 1
fi

if ! grep -Fq 'fake-root-flutter pub get' "$WORKDIR/output.log"; then
  echo "Expected PROJECT_ROOT_OVERRIDE to route FLUTTER_CMD to the fake repo root" >&2
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

echo "[test_setup_development_environment_tmpdir_spaces] Passed"
