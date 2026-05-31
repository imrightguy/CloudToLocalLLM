#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/release/create_github_release.sh"
WORK_DIR="$(mktemp -d)"
REPO_DIR="$WORK_DIR/repo"
FAKE_BIN="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/commands.log"
TMP_ROOT="$WORK_DIR/tmp-root-fallback"
TMP_PREFIX_LOG="$WORK_DIR/mktemp.log"
mkdir -p "$REPO_DIR/scripts/release" "$REPO_DIR/dist/windows" "$REPO_DIR/dist/linux" "$FAKE_BIN" "$TMP_ROOT"
export LOG_FILE TMP_PREFIX_LOG TMP_ROOT

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

for file in \
  "dist/windows/cloudtolocalllm-2.3.4-portable.zip" \
  "dist/windows/cloudtolocalllm-2.3.4-portable.zip.sha256" \
  "dist/windows/CloudToLocalLLM-Windows-2.3.4-Setup.exe" \
  "dist/windows/CloudToLocalLLM-Windows-2.3.4-Setup.exe.sha256" \
  "dist/linux/cloudtolocalllm_2.3.4_amd64.deb" \
  "dist/linux/cloudtolocalllm_2.3.4_amd64.deb.sha256" \
  "dist/linux/cloudtolocalllm-2.3.4-amd64.deb" \
  "dist/linux/cloudtolocalllm-2.3.4-amd64.deb.sha256" \
  "dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage" \
  "dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage.sha256"; do
  printf 'artifact\n' > "$REPO_DIR/$file"
done

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_PREFIX_LOG"
case "$1" in
  /tmp/release_notes.2.3.4.*.md)
    file="$TMP_ROOT/release_notes.2.3.4.mock.md"
    : > "$file"
    printf '%s\n' "$file"
    ;;
  *)
    echo "Unexpected mktemp template: $1" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/gh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
case "$1 $2 $3" in
  release\ view\ *)
    exit 1
    ;;
  release\ create\ *)
    exit 1
    ;;
  release\ delete\ *)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_BIN/gh"

cat > "$FAKE_BIN/git" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
case "$1" in
  tag)
    if [[ "$2" == "-l" ]]; then
      exit 0
    fi
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
( cd "$REPO_DIR" && TMPDIR='/' PATH="$FAKE_BIN:$PATH" bash scripts/release/create_github_release.sh ) > /tmp/test_create_github_release_tmpdir_root_fallback_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected create_github_release.sh to fail when gh release create fails" >&2
  cat /tmp/test_create_github_release_tmpdir_root_fallback_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/release_notes.2.3.4.' "$TMP_PREFIX_LOG"; then
  echo "Expected release notes temp file template to fall back to /tmp" >&2
  cat "$TMP_PREFIX_LOG" >&2
  exit 1
fi

if find "$TMP_ROOT" -type f | grep -q .; then
  echo "Expected release notes temp file cleanup for TMPDIR=/" >&2
  find "$TMP_ROOT" -type f -print >&2
  exit 1
fi

if ! grep -Fq 'Creating GitHub release with multi-platform assets...' /tmp/test_create_github_release_tmpdir_root_fallback_cleanup.log; then
  echo "Missing expected release flow output" >&2
  cat /tmp/test_create_github_release_tmpdir_root_fallback_cleanup.log >&2
  exit 1
fi

echo "[test_create_github_release_tmpdir_root_fallback_cleanup] Passed"
