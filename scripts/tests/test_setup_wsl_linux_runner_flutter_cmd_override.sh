#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-linux-runner.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
RUNNER_DIR="$WORKDIR/runner"
FLUTTER_INSTALL_DIR="$WORKDIR/flutter-root"
LOG_FILE="$WORKDIR/calls.log"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$RUNNER_DIR" "$FLUTTER_INSTALL_DIR"

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
make_stub git 'echo "git $*" >> "$LOG_FILE"; exit 0'
make_stub hostname 'echo runner-host'
make_stub systemctl 'exit 1'
make_stub curl 'echo "curl $*" >> "$LOG_FILE";
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -n "$out" ]]; then
  tmpdir="$(mktemp -d)"
  cat > "$tmpdir/config.sh" <<'EOF'
#!/bin/bash
echo config:$*
exit 0
EOF
  cat > "$tmpdir/svc.sh" <<'EOF'
#!/bin/bash
echo svc:$*
exit 0
EOF
  cat > "$tmpdir/run.sh" <<'EOF'
#!/bin/bash
echo run:$*
exit 0
EOF
  chmod +x "$tmpdir"/*
  tar -czf "$out" -C "$tmpdir" config.sh svc.sh run.sh
  rm -rf "$tmpdir"
fi
exit 0'
make_stub flutter-custom 'echo "flutter-custom $*" >> "$LOG_FILE";
case "${1:-}" in
  --version)
    echo "Flutter 3.24.0 • channel stable"
    ;;
  doctor)
    echo "Doctor summary"
    ;;
  *)
    echo "ok"
    ;;
esac
exit 0'

printf 'token-123\n' | \
HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
WSL_CHECK_SKIP=1 \
FLUTTER_INSTALL_DIR="$FLUTTER_INSTALL_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter-custom" \
RUNNER_DIR="$RUNNER_DIR" \
LOG_FILE="$LOG_FILE" \
bash "$TARGET_SCRIPT" > "$WORKDIR/output.log" 2>&1

if ! grep -Fq 'flutter-custom --version' "$LOG_FILE"; then
  echo "Expected Flutter version check to use FLUTTER_CMD" >&2
  cat "$LOG_FILE" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq 'flutter-custom doctor' "$LOG_FILE"; then
  echo "Expected flutter doctor to use FLUTTER_CMD" >&2
  cat "$LOG_FILE" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if [[ ! -f "$HOME_DIR/.bashrc" || ! -f "$HOME_DIR/.bash_profile" ]]; then
  echo "Expected shell config files to be updated" >&2
  ls -la "$HOME_DIR" >&2
  cat "$WORKDIR/output.log" >&2
  exit 1
fi

if ! grep -Fq "export PATH=\"$FLUTTER_INSTALL_DIR/bin:\$PATH\"" "$HOME_DIR/.bashrc"; then
  echo "Expected custom Flutter install dir to be persisted in .bashrc" >&2
  cat "$HOME_DIR/.bashrc" >&2
  exit 1
fi

if ! grep -Fq "export PATH=\"$FLUTTER_INSTALL_DIR/bin:\$PATH\"" "$HOME_DIR/.bash_profile"; then
  echo "Expected custom Flutter install dir to be persisted in .bash_profile" >&2
  cat "$HOME_DIR/.bash_profile" >&2
  exit 1
fi

echo "PASS: scripts/setup-wsl-linux-runner.sh respects FLUTTER_CMD and WSL_CHECK_SKIP"
