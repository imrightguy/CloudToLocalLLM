#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/installer-template.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
TEMP_FILE="$WORK_DIR/downloads/.cloudtolocalllm-download.fixed"
OUTPUT_DIR="$WORK_DIR/output"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$OUTPUT_DIR" "$(dirname "$TEMP_FILE")"

cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
printf '%s\n' "$TEMP_FILE"
: > "$TEMP_FILE"
EOF
chmod +x "$BIN_DIR/mktemp"

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
printf 'fake-appimage' > "$output"
EOF
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/mv" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$BIN_DIR/mv"

cat > "$BIN_DIR/chmod" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$BIN_DIR/chmod"

if PATH="$BIN_DIR:$PATH" bash -c 'set -euo pipefail; source "$1"; download_appimage "10.1.200" "stable" "$2"' _ "$TARGET_SCRIPT" "$OUTPUT_DIR" >/dev/null 2>&1; then
  echo "download_appimage unexpectedly succeeded in cleanup harness" >&2
  exit 1
fi

if [[ -e "$TEMP_FILE" ]]; then
  echo "Expected download temp cleanup, but $TEMP_FILE still exists" >&2
  exit 1
fi

if [[ -e "$OUTPUT_DIR/cloudtolocalllm-10.1.200-x86_64.AppImage" ]]; then
  echo "Unexpected final AppImage file left behind after mv failure" >&2
  exit 1
fi

echo "[test_installer_download_cleanup] Passed"
