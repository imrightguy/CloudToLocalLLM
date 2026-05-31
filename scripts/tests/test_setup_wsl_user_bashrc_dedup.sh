#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_user.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
BASHRC="$WORK_DIR/.bashrc"
LOG_FILE="$WORK_DIR/install.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN" "$WORK_DIR/project/services/api-backend" "$WORK_DIR/.nvm" "$WORK_DIR/flutter"
: > "$BASHRC"

cat > "$WORK_DIR/.nvm/nvm.sh" <<'EOF'
nvm() {
  printf '%s\n' "nvm $*" >> "$HOME/nvm.log"
}
EOF

for cmd in curl git flutter npm node ollama kubectl; do
  cat > "$FAKE_BIN/$cmd" <<EOF
#!/bin/bash
printf '%s\n' "$cmd \$*" >> "$WORK_DIR/$cmd.log"
exit 0
EOF
  chmod +x "$FAKE_BIN/$cmd"
done

cat > "$WORK_DIR/project/package.json" <<'EOF'
{}
EOF
cat > "$WORK_DIR/project/services/api-backend/package.json" <<'EOF'
{}
EOF

PATH="$FAKE_BIN:$PATH" HOME="$WORK_DIR" PROJECT_DIR="$WORK_DIR/project" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_user_bashrc_dedup.log 2>&1
PATH="$FAKE_BIN:$PATH" HOME="$WORK_DIR" PROJECT_DIR="$WORK_DIR/project" bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_user_bashrc_dedup.log 2>&1

if [[ ! -f "$BASHRC" ]]; then
  echo "Expected .bashrc to be created" >&2
  cat /tmp/test_setup_wsl_user_bashrc_dedup.log >&2
  exit 1
fi

expected='export PATH="$HOME/flutter/bin:$PATH"'
if [[ $(grep -Fxc "$expected" "$BASHRC") -ne 1 ]]; then
  echo "Expected Flutter PATH export to appear exactly once" >&2
  cat "$BASHRC" >&2
  cat /tmp/test_setup_wsl_user_bashrc_dedup.log >&2
  exit 1
fi

if [[ $(grep -Fxc 'flutter config --enable-linux-desktop' "$WORK_DIR/flutter.log") -lt 1 ]]; then
  echo "Expected flutter config command to run" >&2
  cat /tmp/test_setup_wsl_user_bashrc_dedup.log >&2
  exit 1
fi

echo "[test_setup_wsl_user_bashrc_dedup] Passed"
