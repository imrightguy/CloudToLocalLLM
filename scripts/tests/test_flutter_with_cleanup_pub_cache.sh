#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE_CONFIG="$PROJECT_ROOT/.dart_tool/package_config.json"
BACKUP_ROOT="$(mktemp -d)"
WRAPPER_DIR="$(mktemp -d)"
FAKE_BIN_DIR="$(mktemp -d)"
WRAPPER_COPY="$WRAPPER_DIR/flutter_with_cleanup.sh"
WRAPPER_STDERR="$WRAPPER_DIR/wrapper.stderr"
FAKE_FLUTTER="$FAKE_BIN_DIR/flutter"
LOG_FILE="$FAKE_BIN_DIR/flutter.log"
EXPECTED_PUB_CACHE="$PROJECT_ROOT/.pub-cache"
HAD_ORIGINAL=0

restore_original() {
  rm -rf "$PROJECT_ROOT/.dart_tool"
  if [[ "$HAD_ORIGINAL" -eq 1 ]]; then
    mv "$BACKUP_ROOT/original" "$PROJECT_ROOT/.dart_tool"
  fi
  rm -rf "$BACKUP_ROOT" "$WRAPPER_DIR" "$FAKE_BIN_DIR"
}

trap restore_original EXIT

if [[ -e "$PROJECT_ROOT/.dart_tool" ]]; then
  mv "$PROJECT_ROOT/.dart_tool" "$BACKUP_ROOT/original"
  HAD_ORIGINAL=1
fi

mkdir -p "$PROJECT_ROOT/.dart_tool"
cat > "$PACKAGE_CONFIG" <<EOF
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

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$LOG_FILE"
if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
  mkdir -p "$PROJECT_ROOT/.dart_tool"
  cat > "$PROJECT_ROOT/.dart_tool/package_config.json" <<EOF_INNER
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
chmod +x "$FAKE_FLUTTER"

cp "$PROJECT_ROOT/scripts/flutter_with_cleanup.sh" "$WRAPPER_COPY"
chmod +x "$WRAPPER_COPY"

LOG_FILE="$LOG_FILE" PROJECT_ROOT="$PROJECT_ROOT" EXPECTED_PUB_CACHE="$EXPECTED_PUB_CACHE" PUB_CACHE="/paperclip/.pub-cache" FLUTTER_BIN="$FAKE_FLUTTER" "$WRAPPER_COPY" build linux --debug 2> "$WRAPPER_STDERR"

first_call="$(sed -n '1p' "$LOG_FILE")"
second_call="$(sed -n '2p' "$LOG_FILE")"

if [[ "$first_call" != "pub get" ]]; then
  echo "Expected pub get before build, got: $first_call" >&2
  exit 1
fi

if [[ "$second_call" != "build linux --debug" ]]; then
  echo "Expected build after pub get, got: $second_call" >&2
  exit 1
fi

grep -q "Rebinding stale PUB_CACHE=/paperclip/.pub-cache" "$WRAPPER_STDERR"
grep -q "$EXPECTED_PUB_CACHE" "$PACKAGE_CONFIG"
! grep -q '/paperclip/.pub-cache' "$PACKAGE_CONFIG"

echo "[test_flutter_with_cleanup_pub_cache] Passed"
