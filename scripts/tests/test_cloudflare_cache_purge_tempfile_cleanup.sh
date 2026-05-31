#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/cloudflare-cache-purge.sh"
WORK_DIR="$(mktemp -d)"
TMP_DIR="$WORK_DIR/tmp"
FAKE_BIN="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/curl.log"
mkdir -p "$TMP_DIR" "$FAKE_BIN"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
url=""
out=""
headers=""
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    --dump-header)
      headers="$2"
      shift 2
      ;;
    -X|-w|--data|--data-binary|-H)
      shift 2
      ;;
    -s|-I)
      shift 1
      ;;
    http://*|https://*)
      url="$1"
      shift 1
      ;;
    *)
      shift 1
      ;;
  esac
done
printf '%s\n' "$url $out $headers" >> "$LOG_FILE"
case "$url" in
  *"/user/tokens/verify")
    printf '{"success":true}\n'
    ;;
  *"/purge_cache")
    if [[ -n "$headers" ]]; then
      printf 'HTTP/1.1 403 Forbidden\n' > "$headers"
    fi
    if [[ -n "$out" ]]; then
      printf '{"success":false}\n' > "$out"
    fi
    printf '403'
    ;;
  *)
    printf '{"success":true,"result":[{"id":"zone123"}]}\n'
    ;;
esac
EOF
chmod +x "$FAKE_BIN/curl"

set +e
TMPDIR="$TMP_DIR" PATH="$FAKE_BIN:$PATH" CLOUDFLARE_API_TOKEN='token123' CLOUDFLARE_ZONE_ID='zone123' CLOUDFLARE_EMAIL='' bash "$TARGET_SCRIPT" >/tmp/test_cloudflare_cache_purge_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected cloudflare-cache-purge.sh to fail on the simulated purge error" >&2
  cat /tmp/test_cloudflare_cache_purge_cleanup.log >&2
  exit 1
fi

if ! grep -Fq 'Cache purge failed after' /tmp/test_cloudflare_cache_purge_cleanup.log; then
  echo "Expected failure message from cache purge script" >&2
  cat /tmp/test_cloudflare_cache_purge_cleanup.log >&2
  exit 1
fi

if find "$TMP_DIR" -type f | grep -q .; then
  echo "Expected temporary purge files to be cleaned up" >&2
  find "$TMP_DIR" -type f -print >&2
  exit 1
fi

echo "[test_cloudflare_cache_purge_tempfile_cleanup] Passed"
