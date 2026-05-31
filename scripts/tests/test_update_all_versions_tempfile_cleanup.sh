#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/update-all-versions.sh"
WORK_DIR="$(mktemp -d)"
REPO_DIR="$WORK_DIR/repo"
TMP_DIR="$WORK_DIR/tmp"
FAKE_BIN="$WORK_DIR/bin"
mkdir -p "$REPO_DIR/assets" "$REPO_DIR/lib/config" "$REPO_DIR/lib" "$REPO_DIR/services/api-backend" "$REPO_DIR/services/streaming-proxy" "$REPO_DIR/scripts" "$REPO_DIR/docs" "$REPO_DIR/config" "$FAKE_BIN" "$TMP_DIR"
export TMPDIR="$TMP_DIR"
export WORK_DIR

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$REPO_DIR/scripts/update-all-versions.sh"
chmod +x "$REPO_DIR/scripts/update-all-versions.sh"

cat > "$REPO_DIR/assets/version.json" <<'EOF'
{}
EOF
cat > "$REPO_DIR/assets/component-versions.json" <<'EOF'
{}
EOF
cat > "$REPO_DIR/pubspec.yaml" <<'EOF'
name: temp_app
version: 1.0.0+1
EOF
cat > "$REPO_DIR/services/api-backend/package.json" <<'EOF'
{"name":"api","version":"0.0.1"}
EOF
cat > "$REPO_DIR/services/streaming-proxy/package.json" <<'EOF'
{"name":"proxy","version":"0.0.1"}
EOF
cat > "$REPO_DIR/README.md" <<'EOF'
Badge v1.0.0-
EOF
cat > "$REPO_DIR/docs/VERSIONING.md" <<'EOF'
Use 4.1.2 as example.
EOF
cat > "$REPO_DIR/lib/main.dart" <<'EOF'
DART MAIN START ----- v1.0.0
EOF
cat > "$REPO_DIR/SECURITY.md" <<'EOF'
| Version | Supported |
| ------- | ------------------ |
EOF
cat > "$REPO_DIR/lib/config/app_config.dart" <<'EOF'
static const String appVersion = '1.0.0';
EOF
cat > "$REPO_DIR/package.json" <<'EOF'
{"name":"root","version":"0.0.1"}
EOF
cat > "$REPO_DIR/config/.env.production.template" <<'EOF'
APP_VERSION=1.0.0
EOF
cat > "$REPO_DIR/scripts/generate-changelog.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "changelog $1"
EOF
chmod +x "$REPO_DIR/scripts/generate-changelog.sh"

cat > "$FAKE_BIN/jq" <<'EOF'
#!/bin/bash
set -euo pipefail
count_file="$WORK_DIR/jq-count"
count=0
if [[ -f "$count_file" ]]; then
  count=$(<"$count_file")
fi
count=$((count + 1))
printf '%s' "$count" > "$count_file"
case "$count" in
  1|2)
    cat <<'JSON'
{"ok":true}
JSON
    ;;
  3|4)
    cat <<'JSON'
{"version":"2.0.0"}
JSON
    ;;
  5)
    exit 1
    ;;
  *)
    cat <<'JSON'
{"ok":true}
JSON
    ;;
esac
EOF
chmod +x "$FAKE_BIN/jq"

set +e
( cd "$REPO_DIR" && PATH="$FAKE_BIN:$PATH" bash scripts/update-all-versions.sh "2.0.0" "abcdef1234567890" ) > /tmp/test_update_all_versions_tempfile_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected update-all-versions.sh to fail on the simulated root package update" >&2
  cat /tmp/test_update_all_versions_tempfile_cleanup.log >&2
  exit 1
fi

if [[ ! -s "$REPO_DIR/assets/version.json" ]]; then
  echo "assets/version.json should still be written before failure" >&2
  exit 1
fi

if find "$TMP_DIR" -type f | grep -q .; then
  echo "Expected temporary package files to be cleaned up" >&2
  find "$TMP_DIR" -type f -print >&2
  exit 1
fi

echo "[test_update_all_versions_tempfile_cleanup] Passed"
