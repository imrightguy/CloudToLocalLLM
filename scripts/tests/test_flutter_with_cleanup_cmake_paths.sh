#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER_DIR="$(mktemp -d)"
FAKE_BIN_DIR="$(mktemp -d)"
WRAPPER_COPY="$WRAPPER_DIR/flutter_with_cleanup.sh"
FAKE_FLUTTER="$FAKE_BIN_DIR/flutter"
EXPECTED_PREFIX="/paperclip/.local-toolchain/root/usr"

cleanup() {
  rm -rf "$WRAPPER_DIR" "$FAKE_BIN_DIR"
}

trap cleanup EXIT

cat > "$FAKE_FLUTTER" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${CMAKE_PREFIX_PATH:-}" != *"/paperclip/.local-toolchain/root/usr"* ]]; then
  echo "Expected local toolchain prefix in CMAKE_PREFIX_PATH, got: ${CMAKE_PREFIX_PATH:-unset}" >&2
  exit 1
fi
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

cp "$PROJECT_ROOT/scripts/flutter_with_cleanup.sh" "$WRAPPER_COPY"
chmod +x "$WRAPPER_COPY"

PATH="/usr/local/bin:/usr/bin:/bin" FLUTTER_BIN="$FAKE_FLUTTER" "$WRAPPER_COPY" build linux --debug

echo "[test_flutter_with_cleanup_cmake_paths] Passed"
