#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/update-all-versions.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
GIT_LOG="$WORK_DIR/git.log"
CHANGELOG_LOG="$WORK_DIR/changelog.log"
mkdir -p \
  "$TMP_ROOT/assets" \
  "$TMP_ROOT/config" \
  "$TMP_ROOT/docs" \
  "$TMP_ROOT/lib/config" \
  "$TMP_ROOT/scripts" \
  "$TMP_ROOT/services/api-backend" \
  "$TMP_ROOT/services/streaming-proxy" \
  "$BIN_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_ROOT/assets/version.json" <<'EOF'
{
  "version": "0.0.0",
  "build_number": "0",
  "build_date": "old",
  "git_commit": "old",
  "buildTimestamp": "old"
}
EOF

cat > "$TMP_ROOT/assets/component-versions.json" <<'EOF'
{
  "web": "old",
  "api": "old",
  "postgres": "old",
  "streaming_proxy": "old",
  "base": "old",
  "last_updated": "old"
}
EOF

cat > "$TMP_ROOT/pubspec.yaml" <<'EOF'
name: fake_app
version: 0.0.0+0
EOF

cat > "$TMP_ROOT/services/api-backend/package.json" <<'EOF'
{"name":"api-backend","version":"0.0.0"}
EOF

cat > "$TMP_ROOT/services/streaming-proxy/package.json" <<'EOF'
{"name":"streaming-proxy","version":"0.0.0"}
EOF

cat > "$TMP_ROOT/README.md" <<'EOF'
Release badge v0.0.0-
EOF

cat > "$TMP_ROOT/docs/VERSIONING.md" <<'EOF'
Example release 4.1.2
EOF

cat > "$TMP_ROOT/lib/main.dart" <<'EOF'
void main() {}
// DART MAIN START ----- v0.0.0
EOF

cat > "$TMP_ROOT/SECURITY.md" <<'EOF'
| Version | Status |
| ------- | ------------------ |
EOF

cat > "$TMP_ROOT/lib/config/app_config.dart" <<'EOF'
class AppConfig {
  static const String appVersion = '0.0.0';
}
EOF

cat > "$TMP_ROOT/package.json" <<'EOF'
{"name":"root","version":"0.0.0"}
EOF

cat > "$TMP_ROOT/config/.env.production.template" <<'EOF'
CloudToLocalLLM v0.0.0
APP_VERSION=0.0.0
EOF

cat > "$TMP_ROOT/scripts/generate-changelog.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${CHANGELOG_LOG:?missing CHANGELOG_LOG}"
printf '%s\n' "# Changelog for $1" > CHANGELOG.md
EOF
chmod +x "$TMP_ROOT/scripts/generate-changelog.sh"

cat > "$BIN_DIR/git" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${GIT_LOG:?missing GIT_LOG}"
case "$*" in
  "rev-list --count HEAD")
    printf '%s\n' 321
    ;;
  *)
    echo "unexpected git invocation: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$BIN_DIR/git"

cat > "$BIN_DIR/date" <<'EOF'
#!/bin/bash
set -euo pipefail
case "$*" in
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

cd /tmp
PATH="$BIN_DIR:$PATH" \
CHANGELOG_LOG="$CHANGELOG_LOG" \
GIT_LOG="$GIT_LOG" \
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" \
bash "$TARGET_SCRIPT" 9.8.7 1234567890abcdef >/tmp/test_update_all_versions_project_root_override.log 2>&1

if ! grep -Fq '"version": "9.8.7"' "$TMP_ROOT/assets/version.json"; then
  echo "assets/version.json did not update the version" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '"git_commit": "12345678"' "$TMP_ROOT/assets/version.json"; then
  echo "assets/version.json did not capture the provided commit prefix" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '"web": "9.8.7"' "$TMP_ROOT/assets/component-versions.json"; then
  echo "component versions were not updated from the override root" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'version: 9.8.7+321' "$TMP_ROOT/pubspec.yaml"; then
  echo "pubspec.yaml did not update from the override root" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '"version": "9.8.7"' "$TMP_ROOT/services/api-backend/package.json"; then
  echo "api-backend package.json did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '"version": "9.8.7"' "$TMP_ROOT/services/streaming-proxy/package.json"; then
  echo "streaming-proxy package.json did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'v9.8.7-' "$TMP_ROOT/README.md"; then
  echo "README.md did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'Example release 9.8.7' "$TMP_ROOT/docs/VERSIONING.md"; then
  echo "docs/VERSIONING.md did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq "DART MAIN START ----- v9.8.7" "$TMP_ROOT/lib/main.dart"; then
  echo "lib/main.dart did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '| 9.8.x' "$TMP_ROOT/SECURITY.md" || ! grep -Fq ':white_check_mark:' "$TMP_ROOT/SECURITY.md"; then
  echo "SECURITY.md did not add the expected row" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq "static const String appVersion = '9.8.7';" "$TMP_ROOT/lib/config/app_config.dart"; then
  echo "app_config.dart did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'CloudToLocalLLM v9.8.7' "$TMP_ROOT/config/.env.production.template"; then
  echo "env template did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '"version": "9.8.7"' "$TMP_ROOT/package.json"; then
  echo "root package.json did not update" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq '# Changelog for 9.8.7' "$TMP_ROOT/CHANGELOG.md"; then
  echo "generate-changelog.sh was not invoked from the project root" >&2
  cat /tmp/test_update_all_versions_project_root_override.log >&2
  exit 1
fi

if [[ -n $(find "$TMP_ROOT" -name '.tmp.*' -o -name '.version.json.*') ]]; then
  echo "Temporary files were left behind" >&2
  find "$TMP_ROOT" -name '.tmp.*' -o -name '.version.json.*' >&2
  exit 1
fi

echo "PASS: scripts/update-all-versions.sh respects PROJECT_ROOT_OVERRIDE"
