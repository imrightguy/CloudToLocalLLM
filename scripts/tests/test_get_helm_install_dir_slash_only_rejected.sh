#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/get_helm.sh"
FAKE_ROOT="$(mktemp -d)"
FAKE_BIN="$FAKE_ROOT/bin"
MK_TEMP_LOG="$FAKE_ROOT/mktemp.log"
CURL_LOG="$FAKE_ROOT/curl.log"
WGET_LOG="$FAKE_ROOT/wget.log"
mkdir -p "$FAKE_BIN"
for cmd in bash cat chmod date grep mkdir rm sed tail awk uname tr; do
  /usr/bin/ln -s "$(command -v "$cmd")" "$FAKE_BIN/$cmd"
done
export MK_TEMP_LOG CURL_LOG WGET_LOG

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mktemp:%s\n' "$*" >> "$MK_TEMP_LOG"
exit 1
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl:%s\n' "$*" >> "$CURL_LOG"
exit 1
EOF
chmod +x "$FAKE_BIN/curl"

cat > "$FAKE_BIN/wget" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'wget:%s\n' "$*" >> "$WGET_LOG"
exit 1
EOF
chmod +x "$FAKE_BIN/wget"

set +e
TMPDIR="/tmp////" PATH="$FAKE_BIN" HELM_INSTALL_DIR='////' bash "$TARGET_SCRIPT" > "$FAKE_ROOT/output.log" 2>&1
status=$?
set -e
if [[ $status -eq 0 ]]; then
  cat "$FAKE_ROOT/output.log" >&2
  echo "Expected get_helm.sh to reject slash-only HELM_INSTALL_DIR" >&2
  exit 1
fi
if ! grep -q 'HELM_INSTALL_DIR must be a non-root install path' "$FAKE_ROOT/output.log"; then
  cat "$FAKE_ROOT/output.log" >&2
  echo "Expected a clear HELM_INSTALL_DIR validation error for slash-only paths" >&2
  exit 1
fi
if [[ -e "$MK_TEMP_LOG" ]]; then
  cat "$MK_TEMP_LOG" >&2
  echo "Expected slash-only HELM_INSTALL_DIR to fail before mktemp/download setup" >&2
  exit 1
fi
if [[ -e "$CURL_LOG" || -e "$WGET_LOG" ]]; then
  cat "$FAKE_ROOT/output.log" >&2
  echo "Expected slash-only HELM_INSTALL_DIR to fail before any download attempt" >&2
  exit 1
fi
