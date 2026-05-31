#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BUILD_CMD="$(mktemp -d)"
TMP_LINUX_CMD="$(mktemp -d)"
LOG_FILE="/tmp/test_full_release_wsl_missing_release_cmd_guard.log"
MISSING_RELEASE_CMD="$TMP_HOME/missing-release"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BUILD_CMD" "$TMP_LINUX_CMD"
}
trap cleanup EXIT

cat > "$TMP_BUILD_CMD/windows-build" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "windows build invoked" >&2
exit 0
EOF
chmod +x "$TMP_BUILD_CMD/windows-build"

cat > "$TMP_LINUX_CMD/linux-build" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "linux build invoked" >&2
exit 0
EOF
chmod +x "$TMP_LINUX_CMD/linux-build"

set +e
HOME="$TMP_HOME" \
WINDOWS_BUILD_CMD="$TMP_BUILD_CMD/windows-build" \
LINUX_BUILD_CMD="$TMP_LINUX_CMD/linux-build" \
RELEASE_CMD="$MISSING_RELEASE_CMD" \
WSLPATH_CMD=/usr/bin/true \
PACMAN_CMD=/usr/bin/true \
WHICH_CMD=/usr/bin/true \
bash "$PROJECT_ROOT/scripts/release/full_release_wsl.sh" >"$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected full_release_wsl.sh to fail when RELEASE_CMD is missing" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "RELEASE_CMD not found or not executable" "$LOG_FILE"; then
  echo "Expected missing RELEASE_CMD error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if grep -Fq "windows build invoked" "$LOG_FILE" || grep -Fq "linux build invoked" "$LOG_FILE"; then
  echo "Expected release command guard to run before build commands" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_full_release_wsl_missing_release_cmd_guard] Passed"
