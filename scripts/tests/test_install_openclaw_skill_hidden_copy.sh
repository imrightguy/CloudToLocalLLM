#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/install-openclaw-skill.sh"
WORK_DIR="$(mktemp -d)"
SCRIPT_COPY="$WORK_DIR/scripts/install-openclaw-skill.sh"
HOME_DIR="$WORK_DIR/home"
BIN_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/run.log"
SKILL_DIR="$HOME_DIR/.openclaw/skills/cloudtolocallm/avatar_personality"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/scripts" "$WORK_DIR/openclaw_skills/avatar_personality" "$HOME_DIR" "$BIN_DIR"
cp "$TARGET_SCRIPT" "$SCRIPT_COPY"
chmod +x "$SCRIPT_COPY"

cat > "$WORK_DIR/openclaw_skills/avatar_personality/skill.yaml" <<'EOF'
name: avatar_personality
version: 1.0.0
EOF
cat > "$WORK_DIR/openclaw_skills/avatar_personality/.hidden-marker" <<'EOF'
secret
EOF
cat > "$WORK_DIR/openclaw_skills/avatar_personality/personality.md" <<'EOF'
# personality
EOF
cat > "$WORK_DIR/openclaw_skills/avatar_personality/helper.sh" <<'EOF'
#!/bin/bash
echo helper
EOF
chmod +x "$WORK_DIR/openclaw_skills/avatar_personality/helper.sh"

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$BIN_DIR/curl"

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
bash "$SCRIPT_COPY" >"$LOG_FILE" 2>&1

if [[ ! -f "$SKILL_DIR/.hidden-marker" ]]; then
  echo "Expected hidden marker to be copied into OpenClaw skill directory" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$SKILL_DIR/helper.sh" ]]; then
  echo "Expected helper.sh to be copied into OpenClaw skill directory" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$SKILL_DIR/helper.sh")" != "644" ]]; then
  echo "Expected copied helper.sh to be normalized to 644 permissions" >&2
  stat -c '%a %n' "$SKILL_DIR/helper.sh" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$SKILL_DIR")" != "755" ]]; then
  echo "Expected skill directory to retain 755 permissions" >&2
  stat -c '%a %n' "$SKILL_DIR" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_install_openclaw_skill_hidden_copy] Passed"
