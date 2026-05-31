#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/ssl/setup_letsencrypt.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/run.log"
SUDO_LOG="$WORK_DIR/sudo.log"
ETC_DIR="$WORK_DIR/etc"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$WORK_DIR/opt/CloudToLocalLLM/certbot/www/.well-known/acme-challenge" "$ETC_DIR/cron.daily"

cat > "$BIN_DIR/docker" <<'EOF'
#!/bin/bash
set -euo pipefail
case "$1 $2 ${3:-}" in
  'compose version ')
    exit 0
    ;;
  'compose ps ')
    exit 0
    ;;
  'compose up -d')
    exit 0
    ;;
  'compose run --rm')
    exit 0
    ;;
  'compose restart webapp')
    exit 0
    ;;
  *)
    echo "unexpected docker invocation: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$BIN_DIR/docker"

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/sleep"

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$SUDO_LOG"
map_dest() {
  local dest="$1"
  printf '%s/%s' "$ETC_DIR" "${dest#/etc/}"
}
case "$1" in
  mv)
    exit 1
    ;;
  chmod)
    chmod "$2" "$(map_dest "$3")"
    ;;
  sed|pacman|chown)
    exit 0
    ;;
  *)
    echo "unexpected sudo invocation: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$BIN_DIR/sudo"

export SUDO_LOG ETC_DIR
set +e
HOME="$WORK_DIR/home" \
CERTBOT_WEBROOT_ROOT="$WORK_DIR/opt/CloudToLocalLLM/certbot/www" \
DOCKER_CMD="$BIN_DIR/docker" \
PATH="$BIN_DIR:$PATH" \
TMPDIR='/' \
bash "$TARGET_SCRIPT" setup >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected setup_letsencrypt.sh to fail when sudo mv fails" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Eq '^mv /tmp/renew_certs\.[A-Za-z0-9]+\.sh /etc/cron.daily/renew-CloudToLocalLLM-certs$' "$SUDO_LOG"; then
  echo "Expected renewal script to use a temp path under /tmp" >&2
  cat "$SUDO_LOG" >&2
  exit 1
fi

temp_script="$(sed -n 's#^mv \(/tmp/renew_certs\.[A-Za-z0-9]*\.sh\) /etc/cron.daily/renew-CloudToLocalLLM-certs$#\1#p' "$SUDO_LOG" | head -n 1)"
if [[ -z "$temp_script" ]]; then
  echo "Failed to capture temp renewal script path" >&2
  cat "$SUDO_LOG" >&2
  exit 1
fi

if [[ -e "$temp_script" ]]; then
  echo "Expected temp renewal script cleanup after mv failure" >&2
  printf '%s\n' "$temp_script" >&2
  exit 1
fi

if [[ -e "$ETC_DIR/cron.daily/renew-CloudToLocalLLM-certs" ]]; then
  echo "Expected no installed renewal script after mv failure" >&2
  ls -l "$ETC_DIR/cron.daily" >&2
  exit 1
fi

echo "[test_setup_letsencrypt_tmpdir_root_fallback_mv_failure_cleanup] Passed"
