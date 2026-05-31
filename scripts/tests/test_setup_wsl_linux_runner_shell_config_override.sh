#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-linux-runner.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
PROFILE_FILE="$WORKDIR/config/shell/custom.profile"
RUNNER_DIR="$WORKDIR/custom-runner"
INPUT_FILE="$WORKDIR/input.txt"
LOG_FILE="$WORKDIR/script.log"
mkdir -p "$BIN_DIR" "$HOME_DIR"

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

make_stub yes 'exit 0'
make_stub pacman 'exit 0'
make_stub git 'exit 0'
make_stub npm 'exit 0'
make_stub yay 'exit 0'
make_stub ollama 'exit 0'
make_stub systemctl 'if [[ "${1:-}" == "--version" ]]; then echo "systemd 255"; exit 0; fi; exit 0'
make_stub getent 'exit 1'
make_stub flutter 'case "${1:-}" in --version|config|doctor) exit 0 ;; *) exit 0 ;; esac'
make_stub curl 'outfile=""; while [[ $# -gt 0 ]]; do case "$1" in -o) outfile="$2"; shift 2 ;; -L) shift ;; *) shift ;; esac; done; : > "$outfile"'
make_stub tar 'printf "%s\n" "#!/bin/bash" "set -euo pipefail" "touch .runner" "exit 0" > "$PWD/config.sh"; chmod +x "$PWD/config.sh"; printf "%s\n" "#!/bin/bash" "set -euo pipefail" "exit 0" > "$PWD/svc.sh"; chmod +x "$PWD/svc.sh"; printf "%s\n" "#!/bin/bash" "set -euo pipefail" "exit 0" > "$PWD/run.sh"; chmod +x "$PWD/run.sh"'
make_stub sudo 'exit 0'

printf 'y\nrunner-token\n' > "$INPUT_FILE"
set +e
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
PROFILE_FILE="$PROFILE_FILE" \
RUNNER_DIR="$RUNNER_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter" \
USER="$(id -un)" \
bash "$TARGET_SCRIPT" < "$INPUT_FILE" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "setup-wsl-linux-runner.sh failed unexpectedly (exit $status)" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "Expected custom BASHRC_FILE to be created" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Expected custom PROFILE_FILE to be created" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'export PATH="$HOME/flutter/bin:$PATH"' "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected Flutter PATH export once in custom bashrc" >&2
  cat "$BASHRC_FILE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'export PATH="$HOME/flutter/bin:$PATH"' "$PROFILE_FILE") -ne 1 ]]; then
  echo "Expected Flutter PATH export once in custom profile" >&2
  cat "$PROFILE_FILE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  echo "Expected custom RUNNER_DIR to be configured" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_setup_wsl_linux_runner_shell_config_override] Passed"
