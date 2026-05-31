#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/create-cloudflare-api-token.sh"
WORK_DIR="$(mktemp -d)"
TMP_DIR="$WORK_DIR/tmp"
FAKE_BIN="$WORK_DIR/bin"
CREDENTIALS_FILE="$WORK_DIR/.cloudflare-credentials.json"
MV_LOG="$WORK_DIR/mv.log"
mkdir -p "$TMP_DIR" "$FAKE_BIN"
export MV_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
args="$*"
case "$args" in
  *'zones?name='*)
    cat <<'JSON'
{"success":true,"result":[{"id":"zone123"}]}
JSON
    ;;
  *'/user/tokens'*)
    cat <<'JSON'
{"success": true, "result": {"id":"token123","value":"scoped-token-value"}}
JSON
    ;;
  *)
    echo "Unexpected curl invocation: $args" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$FAKE_BIN/curl"

cat > "$FAKE_BIN/mv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$MV_LOG"
exit 0
EOF
chmod +x "$FAKE_BIN/mv"

echo '{"existing":"keep-me"}' > "$CREDENTIALS_FILE"

set +e
PATH="$FAKE_BIN:$PATH" CLOUDFLARE_API_KEY='api-key' CLOUDFLARE_EMAIL='user@example.com' CREDENTIALS_FILE="$CREDENTIALS_FILE" TMPDIR='/' bash "$TARGET_SCRIPT" > /tmp/test_create_cloudflare_api_token_tmpdir_root_fallback.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected create-cloudflare-api-token.sh to succeed with TMPDIR=/" >&2
  cat /tmp/test_create_cloudflare_api_token_tmpdir_root_fallback.log >&2
  exit 1
fi

if ! grep -Fq '{"existing":"keep-me"}' "$CREDENTIALS_FILE"; then
  echo "Expected original credentials file contents to remain unchanged by mv stub" >&2
  cat "$CREDENTIALS_FILE" >&2
  exit 1
fi

if ! grep -Fq '/tmp/cloudflare-credentials.' "$MV_LOG"; then
  echo "Expected credentials temp file to use /tmp after TMPDIR normalization" >&2
  cat "$MV_LOG" >&2
  exit 1
fi

source_path="$(sed -n 's#^\(/tmp/cloudflare-credentials\.[^ ]*\) .*#\1#p' "$MV_LOG" | head -n 1)"
if [[ -z "$source_path" ]]; then
  echo "Failed to capture temporary credentials path from mv log" >&2
  cat "$MV_LOG" >&2
  exit 1
fi

if [[ -e "$source_path" ]]; then
  echo "Expected temporary credentials file cleanup for TMPDIR=/" >&2
  printf '%s\n' "$source_path" >&2
  exit 1
fi

if ! grep -Fq 'API Token created successfully!' /tmp/test_create_cloudflare_api_token_tmpdir_root_fallback.log; then
  echo "Missing success output" >&2
  cat /tmp/test_create_cloudflare_api_token_tmpdir_root_fallback.log >&2
  exit 1
fi

echo "[test_create_cloudflare_api_token_tmpdir_root_fallback] Passed"
