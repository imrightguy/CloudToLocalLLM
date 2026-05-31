#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/installer-template.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
INSTALL_DIR="$WORK_DIR/install/mv-cleanup"
CURL_LOG="$WORK_DIR/curl.log"
MV_LOG="$WORK_DIR/mv.log"
mkdir -p "$FAKE_BIN" "$INSTALL_DIR"
export CURL_LOG MV_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
out=''
url=''
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -L|-s|-S|-f|-fs|-fS|-fsS|-fsSL)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
printf '%s %s\n' "$url" "$out" >> "$CURL_LOG"
printf 'downloaded-but-not-moved' > "$out"
exit 0
EOF
chmod +x "$FAKE_BIN/curl"

cat > "$FAKE_BIN/mv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$MV_LOG"
exit 1
EOF
chmod +x "$FAKE_BIN/mv"

set +e
TMPDIR='/' PATH="$FAKE_BIN:$PATH" INSTALL_VERSION='10.1.200' CLOUDTOLOCALLLM_DIR="$INSTALL_DIR" SKIP_DAEMON=true bash "$TARGET_SCRIPT" >/tmp/test_installer_template_tmpdir_mv_failure_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected installer-template.sh to fail when mv fails" >&2
  cat /tmp/test_installer_template_tmpdir_mv_failure_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/.cloudtolocalllm-download.' "$CURL_LOG"; then
  echo "Expected installer download temp file to fall back to /tmp" >&2
  cat "$CURL_LOG" >&2
  exit 1
fi

temp_path="$(sed -n 's#^.* \(/tmp/\.cloudtolocalllm-download\.[^ ]*\)$#\1#p' "$CURL_LOG" | head -n 1)"
if [[ -z "$temp_path" ]]; then
  echo "Failed to capture installer download temp path" >&2
  cat "$CURL_LOG" >&2
  exit 1
fi

if [[ -e "$temp_path" ]]; then
  echo "Expected installer download temp file cleanup on mv failure" >&2
  printf '%s\n' "$temp_path" >&2
  exit 1
fi

if [[ -e "$INSTALL_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Expected installer output file cleanup on mv failure" >&2
  exit 1
fi

if ! grep -Fq "$INSTALL_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage" "$MV_LOG"; then
  echo "Expected mv failure path to be exercised" >&2
  cat "$MV_LOG" >&2
  exit 1
fi

echo "[test_installer_template_tmpdir_mv_failure_cleanup] Passed"
