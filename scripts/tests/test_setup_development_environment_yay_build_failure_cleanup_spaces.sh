#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home with spaces"
FAKE_ROOT="$WORKDIR/project root with spaces"
CALLS_LOG="$WORKDIR/calls.log"
TMPDIR_RAW="$WORKDIR/nested tmp/dir////"
TMPDIR_EXPECTED="$WORKDIR/nested tmp/dir"
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
make_stub flutter 'echo "flutter-stub $*"'
make_stub kubectl 'echo "kubectl-stub $*"'
make_stub getent 'exit 1'
make_stub id 'if [[ "$1" == "-un" ]]; then echo "rook"; elif [[ "$1" == "-gn" ]]; then echo "rook"; else echo "rook"; fi'
make_stub ollama 'printf "ollama:%s\n" "$*" >> "$CALLS_LOG"; exit 1'
make_stub makepkg 'printf "makepkg:%s\n" "$*" >> "$CALLS_LOG"; exit 1'
make_stub git 'printf "git:%s\n" "$*" >> "$CALLS_LOG"; if [[ "$1" == "clone" ]]; then mkdir -p "$3"; fi; exit 0'

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
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
TMPDIR="$TMPDIR_RAW" \
OLLAMA_CMD=ollama \
"$TARGET_SCRIPT" >"$WORKDIR/output.log" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected setup-development-environment.sh to fail when makepkg fails" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'makepkg:' "$CALLS_LOG"; then
  echo "Expected makepkg failure to be exercised" >&2
  cat "$CALLS_LOG" >&2
  exit 1
fi

yay_build_dir="$(sed -n 's#^git:clone https://aur.archlinux.org/yay.git \(.*yay-install\.[^ ]*\)$#\1#p' "$CALLS_LOG" | tail -n 1)"
if [[ -z "$yay_build_dir" ]]; then
  echo "Failed to capture yay build dir from git log" >&2
  cat "$CALLS_LOG" >&2
  exit 1
fi

if [[ -d "$yay_build_dir" ]]; then
  echo "Expected yay build directory cleanup after makepkg failure" >&2
  printf '%s\n' "$yay_build_dir" >&2
  exit 1
fi

if ! grep -Fq "git:clone https://aur.archlinux.org/yay.git $TMPDIR_EXPECTED/yay-install." "$CALLS_LOG"; then
  echo "Expected yay build dir to use normalized TMPDIR root" >&2
  cat "$CALLS_LOG" >&2
  exit 1
fi

if ! grep -Fq 'Required command not found: ollama' "$WORKDIR/output.log" && ! grep -Fq 'makepkg' "$WORKDIR/output.log"; then
  :
fi

echo "[test_setup_development_environment_yay_build_failure_cleanup_spaces] Passed"
