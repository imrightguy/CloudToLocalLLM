#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/setup_env.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
HOME_DIR="$WORK_DIR/home"
SOURCE_DIR="$WORK_DIR/source"
LOG_FILE="$WORK_DIR/commands.log"
OUTPUT_FILE="$WORK_DIR/output.log"
mkdir -p "$FAKE_BIN" "$HOME_DIR" "$SOURCE_DIR/.ssh"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/sudo" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "sudo $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/sudo"

cat > "$FAKE_BIN/paru" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "paru $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/paru"

cat > "$FAKE_BIN/fvm" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "fvm $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/fvm"

cat > "$SOURCE_DIR/.gitconfig" <<'EOF'
[user]
	email = test@example.com
EOF

cat > "$SOURCE_DIR/.ssh/id_rsa" <<'EOF'
PRIVATE-KEY
EOF
chmod 600 "$SOURCE_DIR/.ssh/id_rsa"

cat > "$SOURCE_DIR/.ssh/id_rsa.pub" <<'EOF'
PUBLIC-KEY
EOF
chmod 644 "$SOURCE_DIR/.ssh/id_rsa.pub"

cat > "$SOURCE_DIR/.ssh/.secret-config" <<'EOF'
HIDDEN-CONTENT
EOF
chmod 644 "$SOURCE_DIR/.ssh/.secret-config"

set +e
HOME="$HOME_DIR" SOURCE_DIR="$SOURCE_DIR" PATH="$FAKE_BIN:$PATH" bash "$SOURCE_SCRIPT" > "$OUTPUT_FILE" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "setup_env.sh failed unexpectedly" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

FISH_CONFIG="$HOME_DIR/.config/fish/config.fish"
if [[ ! -f "$FISH_CONFIG" ]]; then
  echo "fish config was not created" >&2
  exit 1
fi

for expected in \
  'set -gx PATH $HOME/fvm/default/bin $PATH' \
  'set -gx CHROME_EXECUTABLE /usr/bin/google-chrome-stable' \
  'set -gx ANDROID_HOME /opt/android-sdk'
do
  if ! grep -Fqx -- "$expected" "$FISH_CONFIG"; then
    echo "missing expected fish config line: $expected" >&2
    cat "$FISH_CONFIG" >&2
    exit 1
  fi
done

if [[ ! -f "$HOME_DIR/.gitconfig" ]]; then
  echo "gitconfig was not copied" >&2
  exit 1
fi

if [[ ! -f "$HOME_DIR/.ssh/id_rsa" || ! -f "$HOME_DIR/.ssh/id_rsa.pub" || ! -f "$HOME_DIR/.ssh/.secret-config" ]]; then
  echo "ssh files were not copied" >&2
  ls -la "$HOME_DIR/.ssh" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$HOME_DIR/.ssh")" != "700" ]]; then
  echo "ssh directory permissions are incorrect" >&2
  stat -c '%a %n' "$HOME_DIR/.ssh" >&2
  exit 1
fi

for copied_file in "$HOME_DIR/.ssh/id_rsa" "$HOME_DIR/.ssh/id_rsa.pub" "$HOME_DIR/.ssh/.secret-config"; do
  if [[ "$(stat -c '%a' "$copied_file")" != "600" ]]; then
    echo "ssh file permissions are incorrect: $copied_file" >&2
    stat -c '%a %n' "$copied_file" >&2
    exit 1
  fi
done

if ! grep -Fqx -- 'HIDDEN-CONTENT' "$HOME_DIR/.ssh/.secret-config"; then
  echo "hidden ssh file content was not preserved" >&2
  cat "$HOME_DIR/.ssh/.secret-config" >&2
  exit 1
fi

if ! grep -Fq "Setup update complete!" "$OUTPUT_FILE"; then
  echo "missing completion output" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_setup_env_bootstrap_config] Passed"
