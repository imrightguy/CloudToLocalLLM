#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/generate-changelog.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
mkdir -p "$TMP_ROOT" "$BIN_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$TMP_ROOT"
git init -q
printf '%s\n' '# Changelog' '' 'All notable changes to this project will be documented in this file.' '' '## [0.0.1] - 2024-05-01' 'Existing entry' > CHANGELOG.md
git add CHANGELOG.md
git -c user.name=a -c user.email=a@example.com commit -qm 'seed'

cat > "$BIN_DIR/gemini-cli" <<'EOF'
#!/bin/bash
set -euo pipefail
cat <<'OUT'
### Features
- Root-aware changelog test
OUT
EOF
chmod +x "$BIN_DIR/gemini-cli"

output=$(PROJECT_ROOT_OVERRIDE="$TMP_ROOT" PATH="$BIN_DIR:$PATH" bash "$TARGET_SCRIPT" 10.1.201)

if ! grep -Fq '✅ CHANGELOG.md updated successfully' <<<"$output"; then
  echo "generate-changelog.sh did not report success" >&2
  echo "$output" >&2
  exit 1
fi

if ! grep -Fq '## [10.1.201]' "$TMP_ROOT/CHANGELOG.md"; then
  echo "CHANGELOG.md did not get the requested header" >&2
  cat "$TMP_ROOT/CHANGELOG.md" >&2
  exit 1
fi

if ! grep -Fq 'Root-aware changelog test' "$TMP_ROOT/CHANGELOG.md"; then
  echo "CHANGELOG.md did not include the AI-generated body from the override root" >&2
  cat "$TMP_ROOT/CHANGELOG.md" >&2
  exit 1
fi

if ! grep -Fq 'Existing entry' "$TMP_ROOT/CHANGELOG.md"; then
  echo "generate-changelog.sh did not preserve the existing changelog content" >&2
  cat "$TMP_ROOT/CHANGELOG.md" >&2
  exit 1
fi

echo "PASS: scripts/generate-changelog.sh respects PROJECT_ROOT_OVERRIDE"
