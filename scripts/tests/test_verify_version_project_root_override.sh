#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/verify-version.sh"
WORK_DIR="$(mktemp -d)"
TMP_ROOT="$WORK_DIR/fake-root"
mkdir -p "$TMP_ROOT/assets" "$TMP_ROOT/services/api-backend" "$TMP_ROOT/services/streaming-proxy" "$TMP_ROOT/lib/config"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$TMP_ROOT/assets/version.json" <<'EOF'
{"version":"10.1.200+4200"}
EOF
cat > "$TMP_ROOT/pubspec.yaml" <<'EOF'
version: 10.1.200+4200
EOF
cat > "$TMP_ROOT/services/api-backend/package.json" <<'EOF'
{"version":"10.1.200+4200"}
EOF
cat > "$TMP_ROOT/services/streaming-proxy/package.json" <<'EOF'
{"version":"10.1.200+4200"}
EOF
cat > "$TMP_ROOT/lib/config/app_config.dart" <<'EOF'
class AppConfig {
  static const String appVersion = '10.1.200';
}
EOF

cd /tmp
PROJECT_ROOT_OVERRIDE="$TMP_ROOT" bash "$TARGET_SCRIPT" > /tmp/test_verify_version_project_root_override.log 2>&1

if ! grep -Fq 'Version consistency verified' /tmp/test_verify_version_project_root_override.log; then
  echo "verify-version.sh did not report success from the override root" >&2
  cat /tmp/test_verify_version_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'assets/version.json: 10.1.200+4200' /tmp/test_verify_version_project_root_override.log; then
  echo "verify-version.sh did not read assets/version.json from the override root" >&2
  cat /tmp/test_verify_version_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'app_config.dart:     10.1.200' /tmp/test_verify_version_project_root_override.log; then
  echo "verify-version.sh did not read app_config.dart from the override root" >&2
  cat /tmp/test_verify_version_project_root_override.log >&2
  exit 1
fi

echo "PASS: scripts/verify-version.sh respects PROJECT_ROOT_OVERRIDE"
