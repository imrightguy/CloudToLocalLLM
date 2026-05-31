#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_wsl_full.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
PROJECT_ROOT_OVERRIDE_DIR="$WORKDIR/project-root"
FLUTTER_INSTALL_DIR="$WORKDIR/flutter-install"
LOG_FILE="$WORKDIR/calls.log"
mkdir -p "$BIN_DIR" "$HOME_DIR/.nvm" "$FLUTTER_INSTALL_DIR" "$PROJECT_ROOT_OVERRIDE_DIR/services/api-backend"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$HOME_DIR/.nvm/nvm.sh" <<'EOF'
#!/bin/bash
nvm() { :; }
EOF

for tool in sudo apt-get curl git node ollama kubectl; do
  cat > "$BIN_DIR/$tool" <<'EOF'
#!/bin/bash
exit 0
EOF
done

cat > "$BIN_DIR/npm" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'npm %s | %s\n' "$*" "$PWD" >> "${LOG_FILE:?missing LOG_FILE}"
exit 0
EOF

cat > "$BIN_DIR/flutter" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter %s | %s\n' "$*" "$PWD" >> "${LOG_FILE:?missing LOG_FILE}"
exit 0
EOF

cat > "$BIN_DIR/flutter-custom" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter-custom %s | %s\n' "$*" "$PWD" >> "${LOG_FILE:?missing LOG_FILE}"
exit 0
EOF

chmod +x "$BIN_DIR"/*

cat > "$PROJECT_ROOT_OVERRIDE_DIR/package.json" <<'EOF'
{"name":"test-repo"}
EOF

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
PROJECT_ROOT_OVERRIDE="$PROJECT_ROOT_OVERRIDE_DIR" \
BASHRC="$HOME_DIR/.bashrc" \
FLUTTER_INSTALL_DIR="$FLUTTER_INSTALL_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter-custom" \
LOG_FILE="$LOG_FILE" \
bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_full_project_root_override.log 2>&1

if [[ ! -f "$HOME_DIR/.bashrc" ]]; then
  echo "setup_wsl_full.sh did not create the bashrc file" >&2
  cat /tmp/test_setup_wsl_full_project_root_override.log >&2
  exit 1
fi

expected_path='export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"'
expected_config="flutter-custom config --enable-linux-desktop | $PROJECT_ROOT"
expected_version="flutter-custom --version | $PROJECT_ROOT"
expected_pubget="flutter-custom pub get | $PROJECT_ROOT_OVERRIDE_DIR"
expected_npm="npm install | $PROJECT_ROOT_OVERRIDE_DIR"
expected_backend_npm="npm install | $PROJECT_ROOT_OVERRIDE_DIR/services/api-backend"

if [[ $(grep -Fxc "$expected_path" "$HOME_DIR/.bashrc") -ne 1 ]]; then
  echo "Expected custom Flutter PATH export once in bashrc" >&2
  cat "$HOME_DIR/.bashrc" >&2
  cat /tmp/test_setup_wsl_full_project_root_override.log >&2
  exit 1
fi

if ! grep -Fqx "$expected_config" "$LOG_FILE"; then
  echo "setup_wsl_full.sh did not use FLUTTER_CMD for config" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fqx "$expected_version" "$LOG_FILE"; then
  echo "setup_wsl_full.sh did not use FLUTTER_CMD for version verification" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fqx "$expected_pubget" "$LOG_FILE"; then
  echo "setup_wsl_full.sh did not run flutter pub get in the override root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fqx "$expected_npm" "$LOG_FILE"; then
  echo "setup_wsl_full.sh did not run npm install in the override root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fqx "$expected_backend_npm" "$LOG_FILE"; then
  echo "setup_wsl_full.sh did not run backend npm install in the override root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "PASS: scripts/setup/setup_wsl_full.sh respects PROJECT_ROOT_OVERRIDE"
