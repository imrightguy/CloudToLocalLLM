#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/release/create_github_release.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_BIN="$WORK_DIR/bin"
TMPDIR_OVERRIDE="$WORK_DIR/nested/tmp/release"
LOG_FILE="/tmp/test_create_github_release_nested_tmpdir.commands.log"
mkdir -p "$FAKE_ROOT/scripts/release" "$FAKE_ROOT/dist/windows" "$FAKE_ROOT/dist/linux" "$FAKE_BIN"
export LOG_FILE
rm -f "$LOG_FILE"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$FAKE_ROOT/scripts/release/create_github_release.sh"
chmod +x "$FAKE_ROOT/scripts/release/create_github_release.sh"

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
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
  "dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage" \
  "dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage.sha256"; do
  printf 'artifact\n' > "$FAKE_ROOT/$file"
done

cat > "$FAKE_BIN/fake-gh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "gh:$*" >> "$LOG_FILE"
if [[ "$1 $2" == 'release view' ]]; then
  exit 1
fi
if [[ "$1 $2 $3" == 'release create v2.3.4' ]]; then
  exit 0
fi
if [[ "$1 $2 $3" == 'release delete v2.3.4' ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "$FAKE_BIN/fake-gh"

cat > "$FAKE_BIN/fake-git" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "git:$*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/fake-git"

set +e
( cd "$FAKE_ROOT" && PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" TMPDIR="$TMPDIR_OVERRIDE" PATH="$FAKE_BIN:/usr/bin:/bin" GH_CMD="$FAKE_BIN/fake-gh" GIT_CMD="$FAKE_BIN/fake-git" bash scripts/release/create_github_release.sh ) > /tmp/test_create_github_release_nested_tmpdir.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected create_github_release.sh to succeed with a nested TMPDIR override" >&2
  cat /tmp/test_create_github_release_nested_tmpdir.log >&2
  exit 1
fi

if ! grep -Fq 'GitHub release created successfully!' /tmp/test_create_github_release_nested_tmpdir.log; then
  echo "Missing success output" >&2
  cat /tmp/test_create_github_release_nested_tmpdir.log >&2
  exit 1
fi

if ! grep -Fq 'gh:release create v2.3.4' "$LOG_FILE"; then
  echo "Expected gh override to create the release" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_create_github_release_nested_tmpdir] Passed"
