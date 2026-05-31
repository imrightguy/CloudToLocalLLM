#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/release/create_github_release.sh"
WORK_DIR="$(mktemp -d)"
REPO_DIR="$WORK_DIR/repo"
FAKE_BIN="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/commands.log"
mkdir -p "$REPO_DIR/scripts/release" "$REPO_DIR/dist/windows" "$REPO_DIR/dist/linux" "$FAKE_BIN"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$REPO_DIR/scripts/release/create_github_release.sh"
chmod +x "$REPO_DIR/scripts/release/create_github_release.sh"

cat > "$REPO_DIR/pubspec.yaml" <<'EOF'
name: temp_app
version: 2.3.4+5
EOF

cat > "$FAKE_BIN/gh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "$*" >> "$LOG_FILE"
if [[ "$1 $2" == 'release view' ]]; then
  exit 1
fi
exit 0
EOF
chmod +x "$FAKE_BIN/gh"

cat > "$FAKE_BIN/git" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
case "$1" in
  tag)
    exit 0
    ;;
  push)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_BIN/git"

set +e
( cd "$REPO_DIR" && TMPDIR="$WORK_DIR/tmp" PATH="$FAKE_BIN:$PATH" bash scripts/release/create_github_release.sh ) > /tmp/test_create_github_release_missing_assets.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected create_github_release.sh to fail when release assets are absent" >&2
  cat /tmp/test_create_github_release_missing_assets.log >&2
  exit 1
fi

for needle in \
  'Missing packages from Phase 3 builds:' \
  'Windows portable ZIP' \
  'Windows portable ZIP checksum' \
  'Windows installer' \
  'Windows installer checksum' \
  'Linux .deb package' \
  'Linux .deb checksum' \
  'Linux AppImage' \
  'Linux AppImage checksum' \
  'Please run Phase 3 (Multi-Platform Build) first'; do
  if ! grep -Fq "$needle" /tmp/test_create_github_release_missing_assets.log; then
    echo "Missing expected missing-assets error message: $needle" >&2
    cat /tmp/test_create_github_release_missing_assets.log >&2
    exit 1
  fi
done

if grep -Fq 'release create' "$LOG_FILE"; then
  echo "gh release create should not run when assets are absent" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_create_github_release_missing_assets_guard] Passed"
