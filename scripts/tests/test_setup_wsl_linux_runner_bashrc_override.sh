#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-linux-runner.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
RUNNER_DIR="$WORKDIR/custom-runner"
LOG_FILE="$WORKDIR/script.log"
INPUT_FILE="$WORKDIR/input.txt"
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
make_stub tar 'dest="$PWD";
printf "%s\n" "#!/bin/bash" "set -euo pipefail" "script_dir=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"" "printf \"%s\\n\" \"\$0 \$*\" > \"\$script_dir/config.invoked\"" "touch \"\$script_dir/.runner\"" "exit 0" > "$dest/config.sh";
chmod +x "$dest/config.sh";
printf "%s\n" "#!/bin/bash" "set -euo pipefail" "script_dir=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"" "echo \"svc:\$*\" > \"\$script_dir/svc.invoked\"" "exit 0" > "$dest/svc.sh";
chmod +x "$dest/svc.sh";
printf "%s\n" "#!/bin/bash" "exit 0" > "$dest/run.sh";
chmod +x "$dest/run.sh"'
make_stub sudo 'case "${1:-}" in sed|pacman|apt-get|dnf|chown|usermod|systemctl) exit 0 ;; ./svc.sh|*/svc.sh) script="$1"; shift; exec "$script" "$@" ;; *) exec "$@" ;; esac'

printf 'y\nrunner-token\n' > "$INPUT_FILE"
set +e
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
RUNNER_DIR="$RUNNER_DIR" \
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

if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  echo "Expected custom RUNNER_DIR to be configured" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'export PATH="$HOME/flutter/bin:$PATH"' "$BASHRC_FILE") -ne 1 ]]; then
  echo "Expected Flutter PATH export once in custom bashrc" >&2
  cat "$BASHRC_FILE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "cd $RUNNER_DIR" "$LOG_FILE"; then
  echo "Expected runner instructions to reference the overridden runner directory" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_setup_wsl_linux_runner_bashrc_override] Passed"
