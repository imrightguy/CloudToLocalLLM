#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/installer-template.sh"
WORK_DIR="$(mktemp -d)"
TMPDIR_ROOT="/"
INSTALL_DIR="$WORK_DIR/install/root-fallback"
FAKE_BIN="$WORK_DIR/bin"
CURL_LOG="$WORK_DIR/curl.log"
mkdir -p "$FAKE_BIN" "$INSTALL_DIR"
export CURL_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$CURL_LOG"
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
printf 'appimage-binary' > "$out"
EOF
chmod +x "$FAKE_BIN/curl"

TMPDIR="$TMPDIR_ROOT" \
PATH="$FAKE_BIN:$PATH" \
INSTALL_VERSION="10.1.200" \
CLOUDTOLOCALLLM_DIR="$INSTALL_DIR" \
"$TARGET_SCRIPT" --no-daemon >/tmp/test_installer_template_tmpdir_slash_fallback.log 2>&1

if [[ ! -f "$INSTALL_DIR/cloudtolocalllm" ]]; then
  echo "Expected installer to place cloudtolocalllm into the custom install dir" >&2
  cat /tmp/test_installer_template_tmpdir_slash_fallback.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/.cloudtolocalllm-download.' "$CURL_LOG"; then
  echo "Expected installer download temp file to fall back to /tmp" >&2
  cat "$CURL_LOG" >&2
  exit 1
fi

echo "[test_installer_template_tmpdir_slash_fallback] Passed"
