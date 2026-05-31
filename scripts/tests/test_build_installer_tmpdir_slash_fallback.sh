#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
OUTPUT_FILE="$FAKE_ROOT/dist/linux/root-fallback/install.sh"
TMP_LOG="$WORK_DIR/mktemp.log"
export TMP_LOG
mkdir -p "$FAKE_ROOT/scripts/packaging/update-daemon" "$FAKE_ROOT/dist/linux/root-fallback" "$WORK_DIR/bin"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: fake_app
version: 10.1.200+4200
EOF

cp "$PROJECT_ROOT/scripts/packaging/installer-template.sh" "$FAKE_ROOT/scripts/packaging/installer-template.sh"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated" "$FAKE_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.service" "$FAKE_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.service"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer" "$FAKE_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer"

cat > "$WORK_DIR/bin/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_LOG"
if [[ "$1" == "-d" ]]; then
  /usr/bin/mktemp "$@"
  exit 0
fi
/usr/bin/mktemp "$@"
EOF
chmod +x "$WORK_DIR/bin/mktemp"

cat > "$WORK_DIR/bin/head" <<'EOF'
#!/bin/bash
exec /usr/bin/head "$@"
EOF
chmod +x "$WORK_DIR/bin/head"

cat > "$WORK_DIR/bin/tail" <<'EOF'
#!/bin/bash
exec /usr/bin/tail "$@"
EOF
chmod +x "$WORK_DIR/bin/tail"

for name in base64 sed; do
  cat > "$WORK_DIR/bin/$name" <<EOF
#!/bin/bash
exec /usr/bin/$name "\$@"
EOF
  chmod +x "$WORK_DIR/bin/$name"
done

PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" OUTPUT_FILE="$OUTPUT_FILE" TMPDIR="/" PATH="$WORK_DIR/bin:$PATH" bash "$TARGET_SCRIPT" >/tmp/test_build_installer_tmpdir_slash_fallback.log 2>&1

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "build_installer.sh did not write install.sh for TMPDIR=/" >&2
  cat /tmp/test_build_installer_tmpdir_slash_fallback.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/build_installer.' "$TMP_LOG"; then
  echo "Expected build_installer.sh temp file to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

echo "[test_build_installer_tmpdir_slash_fallback] Passed"
