#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/flutter_with_cleanup.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/flutter.log"
mkdir -p "$TMP_ROOT/build/linux/x64/release" "$TMP_ROOT/.dart_tool" "$BIN_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_ROOT/build/linux/x64/release/CMakeCache.txt" <<'EOF'
CMAKE_HOME_DIRECTORY:INTERNAL=/tmp/elsewhere/linux
CMAKE_CACHEFILE_DIR:INTERNAL=/tmp/elsewhere/build/linux/x64/release
EOF

cat > "$BIN_DIR/flutter" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "flutter:$*" >> "${FLUTTER_LOG:?missing FLUTTER_LOG}"
exit 0
EOF
chmod +x "$BIN_DIR/flutter"

PROJECT_ROOT_OVERRIDE="$TMP_ROOT" FLUTTER_BIN="$BIN_DIR/flutter" FLUTTER_LOG="$LOG_FILE" bash "$TARGET_SCRIPT" --version >/tmp/test_flutter_with_cleanup_project_root_override.log 2>&1

if [[ -d "$TMP_ROOT/build/linux/x64/release" ]]; then
  echo "flutter_with_cleanup.sh did not remove the stale Linux CMake cache under the override root" >&2
  cat /tmp/test_flutter_with_cleanup_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'flutter:pub get' "$LOG_FILE"; then
  echo "flutter_with_cleanup.sh did not refresh package config using the override-root flutter binary" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'flutter:--version' "$LOG_FILE"; then
  echo "flutter_with_cleanup.sh did not exec the override-root flutter binary with the requested args" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "PASS: scripts/flutter_with_cleanup.sh respects PROJECT_ROOT_OVERRIDE"
