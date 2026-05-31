#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/cloudflare-cache-purge.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
TMP_LOG="$WORK_DIR/mktemp.log"
CURL_LOG="$WORK_DIR/curl.log"
mkdir -p "$FAKE_BIN"
export TMP_LOG CURL_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_LOG"
path="${1//XXXXXX/mock}"
: > "$path"
printf '%s\n' "$path"
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$CURL_LOG"
out=""
url=""
method="GET"
header_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -X)
      method="$2"
      shift 2
      ;;
    -o)
      out="$2"
      shift 2
      ;;
    -I)
      header_only=true
      shift
      ;;
    http*)
      url="$1"
      shift
      ;;
    --*)
      shift
      ;;
    -H|-s|-w|-m)
      shift
      [[ "$1" != "" && "$1" != -* ]] && shift || true
      ;;
    *)
      if [[ -z "$url" && "$1" == http* ]]; then
        url="$1"
      fi
      shift
      ;;
  esac
done

if [[ "$url" == *"/user/tokens/verify" ]]; then
  printf '%s\n' '{"success":true}'
  exit 0
fi

if [[ "$url" == *"/zones/"*"/purge_cache" ]]; then
  if [[ -n "$out" ]]; then
    printf '%s\n' '{"success":true}' > "$out"
  fi
  printf '200'
  exit 0
fi

if [[ "$header_only" == true ]]; then
  printf '%s\n' 'CF-Cache-Status: MISS'
  exit 0
fi

printf '%s\n' '{"success":true}'
EOF
chmod +x "$FAKE_BIN/curl"

set +e
TMPDIR='/' CLOUDFLARE_API_TOKEN='Bearer test-token' CLOUDFLARE_ZONE_ID='zone123' CLOUDFLARE_EMAIL='' PATH="$FAKE_BIN:$PATH" bash "$TARGET_SCRIPT" > /tmp/test_cloudflare_cache_purge_tmpdir_root_fallback.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected cloudflare-cache-purge.sh to succeed with TMPDIR=/" >&2
  cat /tmp/test_cloudflare_cache_purge_tmpdir_root_fallback.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudflare-purge.' "$TMP_LOG"; then
  echo "Expected purge temp file to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudflare-headers.' "$TMP_LOG"; then
  echo "Expected headers temp file to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if find /tmp -maxdepth 1 \( -name 'cloudflare-purge.mock' -o -name 'cloudflare-headers.mock' -o -name 'cloudflare-selective.mock' \) | grep -q .; then
  echo "Expected Cloudflare cache purge temp files to be cleaned up" >&2
  find /tmp -maxdepth 1 \( -name 'cloudflare-purge.mock' -o -name 'cloudflare-headers.mock' -o -name 'cloudflare-selective.mock' \) >&2
  exit 1
fi

echo "[test_cloudflare_cache_purge_tmpdir_root_fallback] Passed"
