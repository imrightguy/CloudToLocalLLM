#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/generate-changelog.sh"
WORK_DIR="$(mktemp -d)"
REPO_DIR="$WORK_DIR/repo"
FAKE_BIN="$WORK_DIR/bin"
TMP_LOG="$WORK_DIR/mktemp.log"
mkdir -p "$REPO_DIR" "$FAKE_BIN"
export TMP_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$REPO_DIR/generate-changelog.sh"
chmod +x "$REPO_DIR/generate-changelog.sh"

cat > "$REPO_DIR/CHANGELOG.md" <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-01-01
- Initial release
EOF

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_LOG"
/usr/bin/mktemp "$@"
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/git" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$1" == "describe" && "$2" == "--tags" && "$3" == "--abbrev=0" ]]; then
  printf '%s\n' 'v1.0.0'
elif [[ "$1" == "log" && "$2" == --pretty=format:*\ %s\ \(%h\) && "$3" == "--no-merges" && "${4:-}" == "" ]]; then
  printf '%s\n' '* Add changelog temp file hardening (abc123)'
elif [[ "$1" == "log" && "$2" == --pretty=format:*\ %s\ \(%h\) && "$3" == "--no-merges" && "$4" == "v1.0.0..HEAD" ]]; then
  printf '%s\n' '* Add changelog temp file hardening (abc123)'
else
  echo "Unexpected git invocation: $*" >&2
  exit 1
fi
EOF
chmod +x "$FAKE_BIN/git"

set +e
TMPDIR='/' PROJECT_ROOT_OVERRIDE="$REPO_DIR" PATH="$FAKE_BIN:$PATH" bash "$REPO_DIR/generate-changelog.sh" 1.1.0 > /tmp/test_generate_changelog_tmpdir_root_fallback.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected generate-changelog.sh to succeed with TMPDIR=/" >&2
  cat /tmp/test_generate_changelog_tmpdir_root_fallback.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/changelog.' "$TMP_LOG"; then
  echo "Expected changelog temp file to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if [[ ! -f "$REPO_DIR/CHANGELOG.md" ]]; then
  echo "Expected CHANGELOG.md to be updated" >&2
  exit 1
fi

if ! grep -Fq '## [1.1.0] - ' "$REPO_DIR/CHANGELOG.md"; then
  echo "Expected new changelog header" >&2
  cat "$REPO_DIR/CHANGELOG.md" >&2
  exit 1
fi

if ! grep -Fq '* Add changelog temp file hardening (abc123)' "$REPO_DIR/CHANGELOG.md"; then
  echo "Expected changelog entry content to be preserved" >&2
  cat "$REPO_DIR/CHANGELOG.md" >&2
  exit 1
fi

echo "[test_generate_changelog_tmpdir_root_fallback] Passed"
