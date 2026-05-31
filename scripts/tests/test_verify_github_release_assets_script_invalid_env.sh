#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$PROJECT_ROOT/scripts/release/verify_github_release_assets.py"
WORK_DIR="$(mktemp -d)"
LOG_FILE="$WORK_DIR/script.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if GITHUB_TOKEN=dummy \
  GITHUB_REPOSITORY=example-org/example-repo \
  RELEASE_TAG=v9.9.9 \
  VERSION=9.9.9 \
  RETRY_ATTEMPTS=abc \
  python3 "$SCRIPT_FILE" >"$LOG_FILE" 2>&1; then
  echo "Expected invalid RETRY_ATTEMPTS to fail" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'Invalid integer for RETRY_ATTEMPTS: abc' "$LOG_FILE"; then
  echo "Missing invalid RETRY_ATTEMPTS error" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if GITHUB_TOKEN=dummy \
  GITHUB_REPOSITORY=example-org/example-repo \
  RELEASE_TAG=v9.9.9 \
  VERSION=9.9.9 \
  RETRY_DELAY_SECONDS=-1 \
  python3 "$SCRIPT_FILE" >"$LOG_FILE" 2>&1; then
  echo "Expected negative RETRY_DELAY_SECONDS to fail" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'RETRY_DELAY_SECONDS must be >= 0: -1' "$LOG_FILE"; then
  echo "Missing invalid RETRY_DELAY_SECONDS error" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_verify_github_release_assets_script_invalid_env] Passed"
