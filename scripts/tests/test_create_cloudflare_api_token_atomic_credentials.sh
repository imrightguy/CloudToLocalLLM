#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/create-cloudflare-api-token.sh"
WORK_DIR="$(mktemp -d)"
TMP_DIR="$WORK_DIR/tmp"
FAKE_BIN="$WORK_DIR/bin"
CREDENTIALS_FILE="$WORK_DIR/.cloudflare-credentials.json"
mkdir -p "$TMP_DIR" "$FAKE_BIN"
export TMPDIR="$TMP_DIR////"
export WORK_DIR

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
{"success": true, "result": [{"id": "zone123"}]}
JSON
    ;;
  *'/user/tokens'*)
    cat <<'JSON'
{"success": true, "result": {"id": "token123", "value": "scoped-token-value"}}
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
printf '%s\n' "$*" >> "$WORK_DIR/mv.log"
exit 1
EOF
chmod +x "$FAKE_BIN/mv"

echo '{"existing":"keep-me"}' > "$CREDENTIALS_FILE"

set +e
PATH="$FAKE_BIN:$PATH" CLOUDFLARE_API_KEY='api-key' CLOUDFLARE_EMAIL='user@example.com' CREDENTIALS_FILE="$CREDENTIALS_FILE" bash "$TARGET_SCRIPT" > /tmp/test_create_cloudflare_api_token_atomic_credentials.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected create-cloudflare-api-token.sh to fail when credentials replacement fails" >&2
  cat /tmp/test_create_cloudflare_api_token_atomic_credentials.log >&2
  exit 1
fi

if ! grep -Fq '{"existing":"keep-me"}' "$CREDENTIALS_FILE"; then
  echo "Expected original credentials file contents to remain unchanged" >&2
  cat "$CREDENTIALS_FILE" >&2
  exit 1
fi

if find "$TMP_DIR" -type f | grep -q .; then
  echo "Expected temporary token/credentials files to be cleaned up" >&2
  find "$TMP_DIR" -type f -print >&2
  exit 1
fi

echo "[test_create_cloudflare_api_token_atomic_credentials] Passed"
