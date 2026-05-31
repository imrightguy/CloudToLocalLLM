#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-wsl-runner-autostart.sh"
WORKDIR="$(mktemp -d)"
HOME_DIR="$WORKDIR/home"
RUNNER_DIR="$WORKDIR/runner dir/with spaces"
BASHRC_FILE="$WORKDIR/config/bashrc"
PROFILE_FILE="$WORKDIR/config/profile"
START_COMMAND="$WORKDIR/custom scripts/start-runner.sh"
mkdir -p "$HOME_DIR" "$RUNNER_DIR" "$WORKDIR/config" "$WORKDIR/custom scripts"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$RUNNER_DIR/config.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$RUNNER_DIR/config.sh"

cat > "$START_COMMAND" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$START_COMMAND"

RUNNER_DIR="$RUNNER_DIR" \
BASHRC_FILE="$BASHRC_FILE" \
PROFILE_FILE="$PROFILE_FILE" \
START_COMMAND="$START_COMMAND" \
HOME="$HOME_DIR" \
bash "$TARGET_SCRIPT" >/tmp/test_setup_wsl_runner_autostart_project_root_override.log 2>&1

expected_line="if [ -f \"$RUNNER_DIR/start-runner.sh\" ]; then \"$START_COMMAND\" & fi"

if ! grep -Fqx "# Auto-start GitHub Actions Runner" "$BASHRC_FILE"; then
  echo "Missing auto-start marker in bashrc" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

if ! grep -Fqx "$expected_line" "$BASHRC_FILE"; then
  echo "Bashrc did not use the overridden start command with quotes" >&2
  cat "$BASHRC_FILE" >&2
  exit 1
fi

if ! grep -Fqx "$expected_line" "$PROFILE_FILE"; then
  echo "Profile did not use the overridden start command with quotes" >&2
  cat "$PROFILE_FILE" >&2
  exit 1
fi

echo "PASS: scripts/setup-wsl-runner-autostart.sh respects START_COMMAND and shell file overrides"
