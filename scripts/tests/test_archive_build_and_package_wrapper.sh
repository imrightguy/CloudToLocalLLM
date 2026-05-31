#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/archive/build_and_package.sh"
WORK_DIR="$(mktemp -d)"
ARCHIVE_DIR="$WORK_DIR/scripts/archive"
TARGET_DIR="$WORK_DIR/scripts/packaging"
TARGET_SCRIPT="$TARGET_DIR/build_deb.sh"
LOG_FILE="$WORK_DIR/target.log"
mkdir -p "$ARCHIVE_DIR" "$TARGET_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$ARCHIVE_DIR/build_and_package.sh"
chmod +x "$ARCHIVE_DIR/build_and_package.sh"

set +e
WORK_DIR="$WORK_DIR" "$ARCHIVE_DIR/build_and_package.sh" >/tmp/test_archive_build_and_package_wrapper_missing.log 2>&1
missing_status=$?
set -e

if [[ $missing_status -eq 0 ]]; then
  echo "Expected wrapper to fail when the maintained packager is missing" >&2
  cat /tmp/test_archive_build_and_package_wrapper_missing.log >&2
  exit 1
fi

if ! grep -Fq 'Missing maintained packager:' /tmp/test_archive_build_and_package_wrapper_missing.log; then
  echo "Missing maintained-packager failure message" >&2
  cat /tmp/test_archive_build_and_package_wrapper_missing.log >&2
  exit 1
fi

cat > "$TARGET_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
EOF
chmod +x "$TARGET_SCRIPT"

WORK_DIR="$WORK_DIR" LOG_FILE="$LOG_FILE" "$ARCHIVE_DIR/build_and_package.sh" --foo bar baz

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Expected wrapper to invoke the maintained packager" >&2
  exit 1
fi

if [[ $(wc -l < "$LOG_FILE") -ne 1 ]]; then
  echo "Expected exactly one forwarded invocation" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq -- '--foo bar baz' "$LOG_FILE"; then
  echo "Missing forwarded arguments in wrapper output" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "[test_archive_build_and_package_wrapper] Passed"
