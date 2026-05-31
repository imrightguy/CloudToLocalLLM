#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/release/create_github_release.sh"
WORK_DIR="$(mktemp -d)"
REPO_DIR="$WORK_DIR/repo"
TMP_DIR="$WORK_DIR/tmp"
FAKE_BIN="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/commands.log"
mkdir -p "$REPO_DIR/scripts/release" "$REPO_DIR/dist/windows" "$REPO_DIR/dist/linux" "$FAKE_BIN" "$TMP_DIR"
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

for file in \
  "dist/windows/cloudtolocalllm-2.3.4-portable.zip" \
  "dist/windows/cloudtolocalllm-2.3.4-portable.zip.sha256" \
  "dist/windows/CloudToLocalLLM-Windows-2.3.4-Setup.exe" \
  "dist/windows/CloudToLocalLLM-Windows-2.3.4-Setup.exe.sha256" \
  "dist/linux/cloudtolocalllm_2.3.4_amd64.deb" \
  "dist/linux/cloudtolocalllm_2.3.4_amd64.deb.sha256" \
  "dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage" \
  "dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage.sha256"; do
  printf 'artifact\n' > "$REPO_DIR/$file"
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
chmod +x "$FAKE_BIN/fake-git"

set +e
( cd "$REPO_DIR" && TMPDIR="$TMP_DIR" PATH="$FAKE_BIN:/usr/bin:/bin" GH_CMD="$FAKE_BIN/fake-gh" GIT_CMD="$FAKE_BIN/fake-git" bash scripts/release/create_github_release.sh ) > /tmp/test_create_github_release_cmd_override.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected create_github_release.sh to succeed with command overrides" >&2
  cat /tmp/test_create_github_release_cmd_override.log >&2
  exit 1
fi

if ! grep -Fq 'GitHub release created successfully!' /tmp/test_create_github_release_cmd_override.log; then
  echo "Missing success output" >&2
  cat /tmp/test_create_github_release_cmd_override.log >&2
  exit 1
fi

if ! grep -Fq 'gh:release create v2.3.4' "$LOG_FILE"; then
  echo "Expected gh override to create the release" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

for asset in \
  'dist/windows/cloudtolocalllm-2.3.4-portable.zip' \
  'dist/windows/cloudtolocalllm-2.3.4-portable.zip.sha256' \
  'dist/windows/CloudToLocalLLM-Windows-2.3.4-Setup.exe' \
  'dist/windows/CloudToLocalLLM-Windows-2.3.4-Setup.exe.sha256' \
  'dist/linux/cloudtolocalllm_2.3.4_amd64.deb' \
  'dist/linux/cloudtolocalllm_2.3.4_amd64.deb.sha256' \
  'dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage' \
  'dist/linux/cloudtolocalllm-2.3.4-x86_64.AppImage.sha256'; do
  if ! grep -Fq "$asset" "$LOG_FILE"; then
    echo "Expected gh override to include asset: $asset" >&2
    cat "$LOG_FILE" >&2
    exit 1
  fi
done

if ! grep -Fq 'git:tag -a v2.3.4 -m CloudToLocalLLM v2.3.4' "$LOG_FILE"; then
  echo "Expected git override to create the tag" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_create_github_release_cmd_override] Passed"
