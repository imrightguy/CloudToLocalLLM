#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER_DIR="$(mktemp -d)"
FAKE_BIN_DIR="$(mktemp -d)"
WRAPPER_COPY="$WRAPPER_DIR/flutter_with_cleanup.sh"
FAKE_FLUTTER="$FAKE_BIN_DIR/flutter"
EXPECTED_JAVA_HOME="/paperclip/.local-toolchain/root/usr/lib/jvm/java-21-openjdk-amd64"

cleanup() {
  rm -rf "$WRAPPER_DIR" "$FAKE_BIN_DIR"
}

trap cleanup EXIT

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${JAVA_HOME:-}" != "/paperclip/.local-toolchain/root/usr/lib/jvm/java-21-openjdk-amd64" ]]; then
  echo "Expected local toolchain JAVA_HOME, got: ${JAVA_HOME:-unset}" >&2
  exit 1
fi
if [[ ":${PATH:-}:" != *":$JAVA_HOME/bin:"* ]]; then
  echo "Expected JAVA_HOME/bin on PATH, got: ${PATH:-unset}" >&2
  exit 1
fi
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

cp "$PROJECT_ROOT/scripts/flutter_with_cleanup.sh" "$WRAPPER_COPY"
chmod +x "$WRAPPER_COPY"

PATH="/usr/local/bin:/usr/bin:/bin" FLUTTER_BIN="$FAKE_FLUTTER" "$WRAPPER_COPY" build linux --debug

echo "[test_flutter_with_cleanup_java_home] Passed"
