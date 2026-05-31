#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE_ROOT="$(mktemp -d)"
WRAPPER_DIR="$STAGE_ROOT/scripts"
FAKE_BIN_DIR="$(mktemp -d)"
WRAPPER_COPY="$WRAPPER_DIR/flutter_with_cleanup.sh"
FAKE_FLUTTER="$FAKE_BIN_DIR/flutter"
EXPECTED_CMAKE="/paperclip/.local/bin/cmake"
EXPECTED_NINJA="/paperclip/.local/bin/ninja"

cleanup() {
  rm -rf "$STAGE_ROOT" "$FAKE_BIN_DIR"
}

trap cleanup EXIT

mkdir -p "$WRAPPER_DIR"
cp "$PROJECT_ROOT/scripts/flutter_with_cleanup.sh" "$WRAPPER_COPY"
chmod +x "$WRAPPER_COPY"

cat > "$FAKE_FLUTTER" <<EOF
#!/bin/bash
set -euo pipefail
cmake_path="\$(command -v cmake)"
ninja_path="\$(command -v ninja)"
if [[ "\$cmake_path" != "$EXPECTED_CMAKE" ]]; then
  echo "Expected project-local cmake, got: \$cmake_path" >&2
  exit 1
fi
if [[ "\$ninja_path" != "$EXPECTED_NINJA" ]]; then
  echo "Expected project-local ninja, got: \$ninja_path" >&2
  exit 1
fi
exit 0
EOF
chmod +x "$FAKE_FLUTTER"

PATH="/usr/local/bin:/usr/bin:/bin" FLUTTER_BIN="$FAKE_FLUTTER" "$WRAPPER_COPY" build linux --debug

echo "[test_flutter_with_cleanup_tool_path] Passed"
