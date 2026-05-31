#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/flutter_with_cleanup.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/flutter.log"
PACKAGE_CONFIG="$TMP_ROOT/.dart_tool/package_config.json"
EXPECTED_PUB_CACHE="$TMP_ROOT/.pub-cache"

cleanup() {
  chmod -R u+rwx "$TMP_ROOT" 2>/dev/null || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_ROOT/.dart_tool" "$BIN_DIR"
cat > "$PACKAGE_CONFIG" <<'EOF'
{
  "configVersion": 2,
  "packages": [
    {
      "name": "example",
      "rootUri": "file:///paperclip/.pub-cache/hosted/pub.dev/example-1.0.0",
      "packageUri": "lib/",
      "languageVersion": "3.0"
    }
  ]
}
EOF
chmod 555 "$TMP_ROOT/.dart_tool"

cat > "$BIN_DIR/flutter" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s|%s\n' "$PWD" "$*" >> "${FLUTTER_LOG:?missing FLUTTER_LOG}"

if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
  mkdir -p "$PWD/.dart_tool"
  cat > "$PWD/.dart_tool/package_config.json" <<EOF_INNER
{
  "configVersion": 2,
  "packages": [
    {
      "name": "example",
      "rootUri": "file://$EXPECTED_PUB_CACHE/hosted/pub.dev/example-1.0.0",
      "packageUri": "lib/",
      "languageVersion": "3.0"
    }
  ]
}
EOF_INNER
fi
exit 0
EOF
chmod +x "$BIN_DIR/flutter"

export EXPECTED_PUB_CACHE
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" FLUTTER_BIN="$BIN_DIR/flutter" FLUTTER_LOG="$LOG_FILE" bash "$TARGET_SCRIPT" --version >/tmp/test_flutter_with_cleanup_locked_dart_tool_mirror.log 2>&1

first_line="$(sed -n '1p' "$LOG_FILE")"
second_line="$(sed -n '2p' "$LOG_FILE")"
mirror_pwd="${first_line%%|*}"
first_args="${first_line#*|}"
second_args="${second_line#*|}"

if [[ "$first_args" != "pub get" ]]; then
  echo "Expected pub get before --version, got: $first_args" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ "$second_args" != "--version" ]]; then
  echo "Expected --version after pub get, got: $second_args" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ "$mirror_pwd" == "$TMP_ROOT" ]]; then
  echo "Expected the wrapper to use a writable mirror workspace, but it stayed on the locked root" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "Detected non-writable .dart_tool; using writable mirror workspace" /tmp/test_flutter_with_cleanup_locked_dart_tool_mirror.log; then
  echo "Expected the wrapper to announce mirror workspace fallback" >&2
  cat /tmp/test_flutter_with_cleanup_locked_dart_tool_mirror.log >&2
  exit 1
fi

if ! grep -Fq '/paperclip/.pub-cache' "$PACKAGE_CONFIG"; then
  echo "Expected the locked source package_config to remain untouched" >&2
  exit 1
fi

echo "[test_flutter_with_cleanup_locked_dart_tool_mirror] Passed"
