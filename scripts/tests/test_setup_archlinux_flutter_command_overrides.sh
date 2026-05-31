#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup/setup_archlinux_flutter.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
HOME_DIR="$WORKDIR/home"
BASHRC_FILE="$WORKDIR/config/shell/custom.bashrc"
LOG_FILE="$WORKDIR/calls.log"
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

make_stub sudo 'exit 0'
make_stub pacman 'exit 0'
make_stub wget 'exit 0'
make_stub git 'exit 0'
make_stub dart 'echo "dart-stub $*" >> "$LOG_FILE"'
make_stub flutter 'echo "flutter-stub $*" >> "$LOG_FILE"'

FLUTTER_INSTALL_DIR="$WORKDIR/custom/flutter"

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
BASHRC_FILE="$BASHRC_FILE" \
FLUTTER_INSTALL_DIR="$FLUTTER_INSTALL_DIR" \
FLUTTER_CMD="$BIN_DIR/flutter" \
DART_CMD="$BIN_DIR/dart" \
LOG_FILE="$LOG_FILE" \
bash "$TARGET_SCRIPT" >/tmp/test_setup_archlinux_flutter_project_root_override.log 2>&1 || true

if [[ ! -f "$BASHRC_FILE" ]]; then
  echo "setup_archlinux_flutter.sh did not create the custom bashrc file" >&2
  cat /tmp/test_setup_archlinux_flutter_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq "export PATH=\"$FLUTTER_INSTALL_DIR/bin:\$PATH\"" "$BASHRC_FILE"; then
  echo "setup_archlinux_flutter.sh did not write the custom Flutter install dir to bashrc" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

if ! grep -Fq 'flutter-stub doctor --android-licenses' "$LOG_FILE"; then
  echo "setup_archlinux_flutter.sh did not use the FLUTTER_CMD override for doctor" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'flutter-stub --version' "$LOG_FILE"; then
  echo "setup_archlinux_flutter.sh did not use the FLUTTER_CMD override for version checks" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'dart-stub --version' "$LOG_FILE"; then
  echo "setup_archlinux_flutter.sh did not use the DART_CMD override" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "PASS: scripts/setup/setup_archlinux_flutter.sh respects command overrides"
