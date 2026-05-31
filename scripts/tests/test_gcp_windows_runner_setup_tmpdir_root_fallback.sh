#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
TMP_LOG="$WORK_DIR/mktemp.log"
GCLOUD_LOG="$WORK_DIR/gcloud.log"
COPIED_STARTUP="$WORK_DIR/startup.ps1"
STARTUP_SOURCE_PATH="$WORK_DIR/startup-source.txt"
mkdir -p "$FAKE_BIN"
export TMP_LOG GCLOUD_LOG COPIED_STARTUP STARTUP_SOURCE_PATH

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_LOG"
/usr/bin/mktemp "$@"
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/gcloud" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$GCLOUD_LOG"
for arg in "$@"; do
  case "$arg" in
    --metadata-from-file=windows-startup-script-ps1=*)
      startup_file="${arg#--metadata-from-file=windows-startup-script-ps1=}"
      printf '%s\n' "$startup_file" > "$STARTUP_SOURCE_PATH"
      cp "$startup_file" "$COPIED_STARTUP"
      ;;
  esac
done
if [[ "${GCLOUD_FAIL:-0}" == "1" ]]; then
  exit 1
fi
exit 0
EOF
chmod +x "$FAKE_BIN/gcloud"

run_case() {
  local script_path="$1"
  local label="$2"
  : > "$TMP_LOG"
  : > "$GCLOUD_LOG"
  rm -f "$COPIED_STARTUP"

  local log_file="/tmp/test_${label}_tmpdir_root_fallback.log"
  set +e
  TMPDIR='/' GITHUB_RUNNER_TOKEN='token-123' PATH="$FAKE_BIN:$PATH" bash "$script_path" > "$log_file" 2>&1
  local status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    echo "Expected ${label} to succeed with TMPDIR=/" >&2
    cat "$log_file" >&2
    exit 1
  fi

  if ! grep -Fq '/tmp/gcp-windows-runner.' "$TMP_LOG"; then
    echo "Expected startup script tempfile to fall back to /tmp for ${label}" >&2
    cat "$TMP_LOG" >&2
    exit 1
  fi

  if [[ ! -f "$COPIED_STARTUP" ]]; then
    echo "Expected gcloud to receive and copy the startup script for ${label}" >&2
    cat "$GCLOUD_LOG" >&2 || true
    exit 1
  fi

  if grep -Fq 'BOBH5XEA7XJPPTNW2CYI7F3IUR2RG' "$COPIED_STARTUP"; then
    echo "Expected ${label} startup script to use the token from the environment, not a hardcoded secret" >&2
    exit 1
  fi

  if ! grep -Fq 'token-123' "$COPIED_STARTUP"; then
    echo "Expected ${label} startup script to include the provided token" >&2
    cat "$COPIED_STARTUP" >&2
    exit 1
  fi
}

run_failure_cleanup_case() {
  local script_path="$1"
  local label="$2"
  : > "$TMP_LOG"
  : > "$GCLOUD_LOG"
  rm -f "$COPIED_STARTUP" "$STARTUP_SOURCE_PATH"

  local log_file="/tmp/test_${label}_tmpdir_root_fallback_cleanup.log"
  set +e
  GCLOUD_FAIL=1 TMPDIR='/' GITHUB_RUNNER_TOKEN='token-123' PATH="$FAKE_BIN:$PATH" bash "$script_path" > "$log_file" 2>&1
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    echo "Expected ${label} to fail when gcloud fails" >&2
    cat "$log_file" >&2
    exit 1
  fi

  if [[ -n "$(cat "$STARTUP_SOURCE_PATH" 2>/dev/null || true)" ]]; then
    source_path="$(cat "$STARTUP_SOURCE_PATH")"
    if [[ -e "$source_path" ]]; then
      echo "Expected ${label} temp startup script to be cleaned up on failure" >&2
      exit 1
    fi
  else
    echo "Expected ${label} gcloud stub to capture the startup script path" >&2
    cat "$GCLOUD_LOG" >&2
    exit 1
  fi
}

run_case "$PROJECT_ROOT/scripts/gcp-windows-runner-setup.sh" "gcp_windows_runner_setup"
run_case "$PROJECT_ROOT/scripts/gcp-windows-runner-setup-with-password.sh" "gcp_windows_runner_setup_with_password"
run_failure_cleanup_case "$PROJECT_ROOT/scripts/gcp-windows-runner-setup.sh" "gcp_windows_runner_setup"

echo "[test_gcp_windows_runner_setup_tmpdir_root_fallback] Passed"
