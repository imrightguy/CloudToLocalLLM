#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
VERSION_FILE="$FAKE_ROOT/assets/version.json"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_ROOT/assets" "$BIN_DIR"
cat > "$VERSION_FILE" <<'EOF'
{
  "version": "10.1.200",
  "build_number": "4200",
  "build_date": "old",
  "git_commit": "old",
  "buildTimestamp": "old"
}
EOF

cat > "$BIN_DIR/git" <<'EOF'
#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "-C" ]]; then
  shift 2
fi

if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--short" && "${3:-}" == "HEAD" ]]; then
  printf '%s\n' feedface
  exit 0
fi

echo "unexpected git invocation: $*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/git"

cat > "$BIN_DIR/date" <<'EOF'
#!/bin/bash
set -euo pipefail

case "$*" in
  '+%Y%m%d%H%M')
    printf '%s\n' 202405061234
    ;;
  '-u +%Y-%m-%dT%H:%M:%SZ')
    printf '%s\n' 2024-05-06T12:34:56Z
    ;;
  '+%Y-%m-%d %H:%M:%S')
    printf '%s\n' '2024-05-06 12:34:56'
    ;;
  *)
    echo "unexpected date invocation: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$BIN_DIR/date"

PATH="$BIN_DIR:$PATH" PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" bash "$PROJECT_ROOT/scripts/bump-version.sh" patch

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "version.json was not written to the override project root" >&2
  exit 1
fi

if ! grep -Fq '"version": "10.1.201"' "$VERSION_FILE"; then
  echo "version.json did not bump the patch version" >&2
  cat "$VERSION_FILE" >&2
  exit 1
fi

if ! grep -Fq '"build_number": "202405061234"' "$VERSION_FILE"; then
  echo "version.json did not record the expected build number" >&2
  cat "$VERSION_FILE" >&2
  exit 1
fi

if ! grep -Fq '"build_date": "2024-05-06T12:34:56Z"' "$VERSION_FILE"; then
  echo "version.json did not record the expected UTC build date" >&2
  cat "$VERSION_FILE" >&2
  exit 1
fi

if ! grep -Fq '"git_commit": "feedface"' "$VERSION_FILE"; then
  echo "version.json did not record the git commit from the override root" >&2
  cat "$VERSION_FILE" >&2
  exit 1
fi

if ! grep -Fq '"buildTimestamp": "2024-05-06 12:34:56"' "$VERSION_FILE"; then
  echo "version.json did not record the expected timestamp" >&2
  cat "$VERSION_FILE" >&2
  exit 1
fi

echo "PASS: scripts/bump-version.sh respects PROJECT_ROOT_OVERRIDE"
