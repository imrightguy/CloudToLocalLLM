#!/bin/bash
set -euo pipefail

WORK_DIR="$(mktemp -d)"
WEBROOT="$WORK_DIR/opt/CloudToLocalLLM/certbot/www"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WEBROOT/.well-known/acme-challenge/subdir"
cat > "$WEBROOT/.well-known/acme-challenge/testfile" <<'EOF'
test
EOF
cat > "$WEBROOT/.well-known/acme-challenge/hidden-file" <<'EOF'
hidden
EOF
chmod 600 "$WEBROOT/.well-known/acme-challenge/testfile"
chmod 700 "$WEBROOT/.well-known/acme-challenge/subdir"

find "$WEBROOT" -type d -exec chmod 755 {} +
find "$WEBROOT" -type f -exec chmod 644 {} +

if [[ "$(stat -c '%a' "$WEBROOT")" != "755" ]]; then
  echo "Expected webroot directory to be 755" >&2
  stat -c '%a %n' "$WEBROOT" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$WEBROOT/.well-known/acme-challenge/subdir")" != "755" ]]; then
  echo "Expected nested directory to be 755" >&2
  stat -c '%a %n' "$WEBROOT/.well-known/acme-challenge/subdir" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$WEBROOT/.well-known/acme-challenge/testfile")" != "644" ]]; then
  echo "Expected ACME testfile to be 644" >&2
  stat -c '%a %n' "$WEBROOT/.well-known/acme-challenge/testfile" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$WEBROOT/.well-known/acme-challenge/hidden-file")" != "644" ]]; then
  echo "Expected hidden ACME file to be 644" >&2
  stat -c '%a %n' "$WEBROOT/.well-known/acme-challenge/hidden-file" >&2
  exit 1
fi

echo "[test_setup_letsencrypt_webroot_permissions] Passed"
