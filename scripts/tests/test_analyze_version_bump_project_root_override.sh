#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/analyze-version-bump.sh"
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
mkdir -p assets
cat > assets/version.json <<'EOF'
{"version":"10.1.200"}
EOF
printf '%s\n' 'alpha' > file.txt
git add assets/version.json file.txt
GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@example.com GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@example.com git commit -qm 'init'

cat > "$BIN_DIR/gemini-cli" <<'EOF'
#!/bin/bash
set -euo pipefail
cat <<'JSON'
{"bump_type":"patch","new_version":"10.1.201","reasoning":"override root test"}
JSON
EOF
chmod +x "$BIN_DIR/gemini-cli"

cd /tmp
output=$(PROJECT_ROOT_OVERRIDE="$TMP_ROOT" PATH="$BIN_DIR:$PATH" KILOCODE_TOKEN=1 bash "$TARGET_SCRIPT")

if ! grep -Fq 'Current version: 10.1.200' <<<"$output"; then
  echo "analyze-version-bump.sh did not read version.json from the override root" >&2
  echo "$output" >&2
  exit 1
fi

if ! grep -Fq 'New version: 10.1.201' <<<"$output"; then
  echo "analyze-version-bump.sh did not surface the gemini response" >&2
  echo "$output" >&2
  exit 1
fi

if ! grep -Fq 'Type:    patch' <<<"$output"; then
  echo "analyze-version-bump.sh did not expose the bump type" >&2
  echo "$output" >&2
  exit 1
fi

echo "PASS: scripts/analyze-version-bump.sh respects PROJECT_ROOT_OVERRIDE"
