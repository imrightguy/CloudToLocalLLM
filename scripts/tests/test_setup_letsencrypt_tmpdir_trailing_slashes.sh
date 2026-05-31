#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/ssl/setup_letsencrypt.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ETC="$WORK_DIR/etc"
TMP_LOG="$WORK_DIR/mktemp.log"
RUN_LOG="$WORK_DIR/run.log"
TMPDIR_RAW="$WORK_DIR/trailing/tmp////"
TMPDIR_EXPECTED="$WORK_DIR/trailing/tmp"
mkdir -p "$FAKE_ETC/cron.daily" "$TMPDIR_EXPECTED"
export TMP_LOG RUN_LOG FAKE_ETC TMPDIR_EXPECTED

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mktemp() {
  printf '%s\n' "$*" >> "$TMP_LOG"
  command mktemp "$@"
}

sudo() {
  printf '%s\n' "$*" >> "$RUN_LOG"
  case "$1" in
    mv)
      shift
      if [[ "$2" == /etc/cron.daily/renew-CloudToLocalLLM-certs ]]; then
        command mv "$1" "$FAKE_ETC/cron.daily/renew-CloudToLocalLLM-certs"
      else
        command mv "$@"
      fi
      ;;
    chmod)
      shift
      if [[ "$2" == /etc/cron.daily/renew-CloudToLocalLLM-certs ]]; then
        command chmod "$1" "$FAKE_ETC/cron.daily/renew-CloudToLocalLLM-certs"
      else
        command chmod "$@"
      fi
      ;;
    *)
      command "$@"
      ;;
  esac
}

set +e
TMPDIR="$TMPDIR_RAW" source "$TARGET_SCRIPT"
setup_renewal > /tmp/test_setup_letsencrypt_tmpdir_trailing_slashes.log 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Expected setup_renewal to succeed with trailing-slash TMPDIR" >&2
  cat /tmp/test_setup_letsencrypt_tmpdir_trailing_slashes.log >&2
  exit 1
fi

if ! grep -Fq "$TMPDIR_EXPECTED/renew_certs." "$TMP_LOG"; then
  echo "Expected renewal script temp file to use the normalized TMPDIR root" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if [[ ! -x "$FAKE_ETC/cron.daily/renew-CloudToLocalLLM-certs" ]]; then
  echo "Expected renewal script to be installed in the fake cron.daily directory" >&2
  ls -l "$FAKE_ETC/cron.daily" >&2 || true
  exit 1
fi

if ! grep -Fq 'Automatic renewal setup complete!' /tmp/test_setup_letsencrypt_tmpdir_trailing_slashes.log; then
  echo "Expected renewal setup log output" >&2
  cat /tmp/test_setup_letsencrypt_tmpdir_trailing_slashes.log >&2
  exit 1
fi

echo "[test_setup_letsencrypt_tmpdir_trailing_slashes] Passed"
