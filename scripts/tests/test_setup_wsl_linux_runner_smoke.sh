#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-linux-runner.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
HOME_DIR="$WORK_DIR/home"
LOG_DIR="$WORK_DIR/logs"
BASHRC="$HOME_DIR/.bashrc"
RUNNER_DIR="$HOME_DIR/actions-runner"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$HOME_DIR" "$LOG_DIR"

cat > "$BIN_DIR/grep" <<'EOF'
#!/bin/bash
if [[ "$*" == *"-qi microsoft /proc/version"* ]]; then
  exit 0
fi
exec /usr/bin/grep "$@"
EOF
chmod +x "$BIN_DIR/grep"

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/bash
shift 0
exec "$@"
EOF
chmod +x "$BIN_DIR/sudo"

cat > "$BIN_DIR/apt-get" <<EOF
#!/bin/bash
printf '%s\n' "apt-get \$*" >> "$LOG_DIR/apt-get.log"
exit 0
EOF
chmod +x "$BIN_DIR/apt-get"

cat > "$BIN_DIR/curl" <<EOF
#!/bin/bash
printf '%s\n' "curl \$*" >> "$LOG_DIR/curl.log"
if [[ "\$*" == *"actions-runner-linux-x64-2.317.0.tar.gz"* ]]; then
  out=""
  prev=""
  for arg in "\$@"; do
    if [[ "\$prev" == "-o" ]]; then
      out="\$arg"
      break
    fi
    prev="\$arg"
  done
  if [[ -n "\$out" ]]; then
    : > "\$out"
  fi
fi
exit 0
EOF
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/tar" <<'EOF'
#!/bin/bash
current_dir="$PWD"
cat > "$current_dir/config.sh" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "config.sh $*" >> "$PWD/config.log"
exit 0
SCRIPT
cat > "$current_dir/svc.sh" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "svc.sh $*" >> "$PWD/svc.log"
exit 0
SCRIPT
cat > "$current_dir/run.sh" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "run.sh $*" >> "$PWD/run.log"
exit 0
SCRIPT
chmod +x "$current_dir/config.sh" "$current_dir/svc.sh" "$current_dir/run.sh"
exit 0
EOF
chmod +x "$BIN_DIR/tar"

for tool in systemctl git flutter node npm ollama kubectl hostname mv; do
  cat > "$BIN_DIR/$tool" <<EOF
#!/bin/bash
case "$tool" in
  flutter)
    if [[ "\$1" == "--version" ]]; then
      echo 'Flutter 3.24.0'
    else
      echo 'flutter $*' >> "$LOG_DIR/flutter.log"
    fi
    ;;
  node)
    echo 'v24.0.0'
    ;;
  npm)
    echo '10.0.0'
    ;;
  ollama)
    echo 'ollama 0.1.0'
    ;;
  kubectl)
    echo 'kubectl v1.30.0'
    ;;
  hostname)
    echo 'rook-wsl'
    ;;
  systemctl)
    exit 0
    ;;
  git)
    exit 0
    ;;
  mv)
    exit 0
    ;;
esac
exit 0
EOF
  chmod +x "$BIN_DIR/$tool"
done

printf 'RUNNER_TOKEN_1\n' | PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_linux_runner_smoke.log 2>&1
printf 'RUNNER_TOKEN_2\n' | PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_linux_runner_smoke.log 2>&1

if [[ ! -f "$BASHRC" ]]; then
  echo "Expected .bashrc to be created" >&2
  cat /tmp/test_setup_wsl_linux_runner_smoke.log >&2
  exit 1
fi

if [[ $(grep -Fxc 'export PATH="$HOME/flutter/bin:$PATH"' "$BASHRC") -ne 1 ]]; then
  echo "Expected a single Flutter PATH export in .bashrc" >&2
  cat "$BASHRC" >&2
  cat /tmp/test_setup_wsl_linux_runner_smoke.log >&2
  exit 1
fi

if [[ ! -f "$RUNNER_DIR/config.sh" || ! -f "$RUNNER_DIR/svc.sh" || ! -f "$RUNNER_DIR/run.sh" ]]; then
  echo "Expected runner extraction stubs to be created" >&2
  ls -la "$RUNNER_DIR" >&2
  cat /tmp/test_setup_wsl_linux_runner_smoke.log >&2
  exit 1
fi

if ! grep -Fq 'config.sh --url https://github.com/CloudToLocalLLM-online/CloudToLocalLLM --token RUNNER_TOKEN_1' "$RUNNER_DIR/config.log"; then
  echo "Expected first configuration run to record the runner token" >&2
  cat "$RUNNER_DIR/config.log" >&2
  exit 1
fi

if ! grep -Fq 'config.sh --url https://github.com/CloudToLocalLLM-online/CloudToLocalLLM --token RUNNER_TOKEN_2' "$RUNNER_DIR/config.log"; then
  echo "Expected second configuration run to record the runner token" >&2
  cat "$RUNNER_DIR/config.log" >&2
  exit 1
fi

echo "[test_setup_wsl_linux_runner_smoke] Passed"
