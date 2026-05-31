#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_LOG="$WORK_DIR/invocations.log"
export FAKE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_ROOT/assets" "$FAKE_ROOT/lib/config" "$FAKE_ROOT/services/api-backend" "$FAKE_ROOT/services/streaming-proxy" "$FAKE_ROOT/scripts"

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 1.2.3+9
EOF

cat > "$FAKE_ROOT/assets/version.json" <<'EOF'
{}
EOF
cat > "$FAKE_ROOT/assets/component-versions.json" <<'EOF'
{}
EOF

cat > "$FAKE_ROOT/services/api-backend/package.json" <<'EOF'
{
  "name": "api-backend",
  "version": "0.0.1"
}
EOF
cat > "$FAKE_ROOT/services/streaming-proxy/package.json" <<'EOF'
{
  "name": "streaming-proxy",
  "version": "0.0.1"
}
EOF

cat > "$FAKE_ROOT/package.json" <<'EOF'
{
  "name": "root",
  "version": "0.0.1"
}
EOF

cat > "$FAKE_ROOT/lib/main.dart" <<'EOF'
// DART MAIN START ----- v0.0.1+1
void main() {}
EOF

cat > "$FAKE_ROOT/lib/config/app_config.dart" <<'EOF'
class AppConfig {
  static const String appVersion = '0.0.1';
}
EOF

cat > "$FAKE_ROOT/README.md" <<'EOF'
Badge v0.0.1-
EOF

cat > "$FAKE_ROOT/SECURITY.md" <<'EOF'
| Version | Status |
| ------- | ------------------ |
EOF

cat > "$FAKE_ROOT/scripts/generate-changelog.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'generate-changelog %s\n' "$*" >> "$FAKE_LOG"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/generate-changelog.sh"

TMPDIR="/" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
"$PROJECT_ROOT/scripts/update-all-versions.sh" "2.3.4+5" "1234567890abcdef" >/tmp/test_update_all_versions_tmpdir_root.log 2>&1

python3 - <<'PY' "$FAKE_ROOT"
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
assert '2.3.4+1' in (root / 'pubspec.yaml').read_text()
assert '2.3.4' in (root / 'lib/config/app_config.dart').read_text()
assert '2.3.4' in (root / 'services/api-backend/package.json').read_text()
assert '2.3.4' in (root / 'services/streaming-proxy/package.json').read_text()
assert '2.3.4+5' in (root / 'package.json').read_text()
assert '2.3.4' in (root / 'assets/version.json').read_text()
assert '2.3.4' in (root / 'assets/component-versions.json').read_text()
assert '2.3.4+5' in (root / 'lib/main.dart').read_text()
print('[test_update_all_versions_tmpdir_root_fallback] Passed')
PY
