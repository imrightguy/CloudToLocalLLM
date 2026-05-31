#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/get-cloudflare-zone-id.sh"
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
out=""
url=""
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -H|-X)
      shift 2
      ;;
    -s)
      shift 1
      ;;
    https://*)
      url="$1"
      shift 1
      ;;
    *)
      shift 1
      ;;
  esac
done
printf '%s\n' "$url $out" >> "$LOG_FILE"
if [[ -n "$out" ]]; then
  printf '%s\n' '{"success":true,"result":[{"id":"zone123"}]}' > "$out"
fi
EOF
chmod +x "$FAKE_BIN/curl"

set +e
TMPDIR="/" PATH="$FAKE_BIN:$PATH" CLOUDFLARE_API_TOKEN='Bearer   abc123   ' bash "$TARGET_SCRIPT" example.com > /tmp/test_get_cloudflare_zone_id_cleanup.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected get-cloudflare-zone-id.sh to succeed" >&2
  cat /tmp/test_get_cloudflare_zone_id_cleanup.log >&2
  exit 1
fi

if ! grep -Fq 'Zone ID found: zone123' /tmp/test_get_cloudflare_zone_id_cleanup.log; then
  echo "Missing success output" >&2
  cat /tmp/test_get_cloudflare_zone_id_cleanup.log >&2
  exit 1
fi

if ! grep -Fq 'https://api.cloudflare.com/client/v4/zones?name=example.com' "$LOG_FILE"; then
  echo "Expected curl to query the requested domain" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if find "$TMP_DIR" -type f | grep -q .; then
  echo "Expected response temp files to be cleaned up" >&2
  find "$TMP_DIR" -type f -print >&2
  exit 1
fi

echo "[test_get_cloudflare_zone_id_cleanup] Passed"
