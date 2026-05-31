#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
BIN_DIR="$WORK_DIR/bin"
TMP_LOG="$WORK_DIR/mktemp.log"
export TMP_LOG
mkdir -p "$FAKE_ROOT/scripts/packaging/update-daemon" "$FAKE_ROOT/dist/linux/root-fallback" "$BIN_DIR"

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

cat > "$BIN_DIR/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_LOG"
/usr/bin/mktemp "$@"
EOF
chmod +x "$BIN_DIR/mktemp"

cat > "$BIN_DIR/head" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$BIN_DIR/head"

for name in base64 sed tail; do
  cat > "$BIN_DIR/$name" <<EOF
#!/bin/bash
exec /usr/bin/$name "\$@"
EOF
  chmod +x "$BIN_DIR/$name"
done

set +e
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" OUTPUT_FILE="$FAKE_ROOT/dist/linux/root-fallback/install.sh" TMPDIR='/' PATH="$BIN_DIR:$PATH" bash "$TARGET_SCRIPT" >/tmp/test_build_installer_tmpdir_root_fallback_cleanup.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_installer.sh to fail when head fails" >&2
  cat /tmp/test_build_installer_tmpdir_root_fallback_cleanup.log >&2
  exit 1
fi

if ! grep -Fq '/tmp/build_installer.' "$TMP_LOG"; then
  echo "Expected build_installer.sh temp file to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

temp_path="$(sed -n 's#^.*\(/tmp/build_installer\.[^ ]*\)$#\1#p' "$TMP_LOG" | head -n 1)"
if [[ -z "$temp_path" ]]; then
  echo "Failed to capture temporary installer file path" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if [[ -e "$temp_path" ]]; then
  echo "Expected temporary installer file cleanup for TMPDIR=/" >&2
  printf '%s\n' "$temp_path" >&2
  exit 1
fi

echo "[test_build_installer_tmpdir_root_fallback_cleanup] Passed"
