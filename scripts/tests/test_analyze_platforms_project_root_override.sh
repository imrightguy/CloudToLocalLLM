#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/analyze-platforms.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
mkdir -p "$TMP_ROOT" "$BIN_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$TMP_ROOT"
git init -q
mkdir -p assets
cat > assets/version.json <<'EOF'
{"version":"10.1.200+4200"}
EOF
mkdir -p web lib/config services
printf '%s\n' 'web change' > web/marker.txt
printf '%s\n' 'service change' > services/marker.txt
git add assets/version.json web/marker.txt services/marker.txt
GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@example.com GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@example.com git commit -qm 'init'

cat > "$BIN_DIR/date" <<'EOF'
#!/bin/bash
set -euo pipefail
case "$*" in
  '+%Y%m%d%H%M')
    printf '%s\n' 202405061234
    ;;
  *)
    /usr/bin/date "$@"
    ;;
esac
EOF
chmod +x "$BIN_DIR/date"

cat > "$BIN_DIR/kilocode" <<'EOF'
#!/bin/bash
set -euo pipefail
cat <<'JSON'
{"bump_type":"none","semantic_version":"10.1.200","needs_managed":true,"needs_local":true,"needs_desktop":true,"needs_mobile":false,"reasoning":"override root test"}
JSON
EOF
chmod +x "$BIN_DIR/kilocode"

cd /tmp
output=$(PROJECT_ROOT_OVERRIDE="$TMP_ROOT" PATH="$BIN_DIR:$PATH" KILOCODE_TOKEN=1 bash "$TARGET_SCRIPT")

if ! grep -Fq 'Current version: 10.1.200+4200' <<<"$output"; then
  echo "analyze-platforms.sh did not read version.json from the override root" >&2
  echo "$output" >&2
  exit 1
fi

if ! grep -Fq 'New version: 10.1.200+202405061234' <<<"$output"; then
  echo "analyze-platforms.sh did not produce the expected version output" >&2
  echo "$output" >&2
  exit 1
fi

if ! grep -Fq 'Managed: true' <<<"$output" || ! grep -Fq 'Desktop: true' <<<"$output"; then
  echo "analyze-platforms.sh did not surface the Kilocode JSON from the override root" >&2
  echo "$output" >&2
  exit 1
fi

echo "PASS: scripts/analyze-platforms.sh respects PROJECT_ROOT_OVERRIDE"
