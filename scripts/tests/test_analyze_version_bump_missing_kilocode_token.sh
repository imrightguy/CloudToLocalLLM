#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/analyze-version-bump.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_BIN="$WORK_DIR/bin"
OUTPUT_LOG="$WORK_DIR/output.log"
mkdir -p "$FAKE_ROOT/assets" "$FAKE_BIN"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/assets/version.json" <<'EOF'
{"version":"1.2.3+456"}
EOF

cat > "$FAKE_BIN/git" <<'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  describe)
    exit 1
    ;;
  log)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_BIN/git"

set +e
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
PATH="$FAKE_BIN:$PATH" \
bash "$TARGET_SCRIPT" > "$OUTPUT_LOG" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected analyze-version-bump.sh to fail when KILOCODE_TOKEN is missing" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

if ! grep -Fq "KILOCODE_TOKEN is not set" "$OUTPUT_LOG"; then
  echo "Expected explicit missing-token error message" >&2
  cat "$OUTPUT_LOG" >&2
  exit 1
fi

echo "[test_analyze_version_bump_missing_kilocode_token] Passed"
