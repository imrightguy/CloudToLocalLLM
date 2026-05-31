#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/get-next-service-version.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
mkdir -p "$TMP_ROOT/assets" "$BIN_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_ROOT/assets/version.json" <<'EOF'
{"version":"4.4.0"}
EOF

cat > "$BIN_DIR/az" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "az:$*" >> "${AZ_LOG:?missing AZ_LOG}"
if [[ "${1:-}" == "acr" && "${2:-}" == "repository" && "${3:-}" == "show-tags" ]]; then
  exit 0
fi
echo "unexpected az invocation: $*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/az"

cat > "$BIN_DIR/jq" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${1:-}" == "-r" && "${2:-}" == '[.[] | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-z]+)?$"))] | .[0]' ]]; then
  exit 0
fi
echo "unexpected jq invocation: $*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/jq"

cd /tmp
output=$(AZ_LOG="$WORK_DIR/az.log" PATH="$BIN_DIR:$PATH" PROJECT_ROOT_OVERRIDE="$TMP_ROOT" bash "$TARGET_SCRIPT" web demo 2>"$WORK_DIR/stderr.log")

if [[ "$output" != "4.4.0" ]]; then
  echo "get-next-service-version.sh did not fall back to version.json from the override root" >&2
  cat "$WORK_DIR/stderr.log" >&2
  exit 1
fi

if ! grep -Fq 'az:acr repository show-tags --name demo --repository web --orderby time_desc --output json' "$WORK_DIR/az.log"; then
  echo "unexpected az invocation log" >&2
  cat "$WORK_DIR/az.log" >&2
  exit 1
fi

echo "PASS: scripts/get-next-service-version.sh respects PROJECT_ROOT_OVERRIDE"
