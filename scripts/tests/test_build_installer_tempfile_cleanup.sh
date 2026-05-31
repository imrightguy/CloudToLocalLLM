#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
TEMP_FILE="$WORK_DIR/install.sh.tmp"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$WORK_DIR/scripts/packaging/update-daemon" "$WORK_DIR/dist/linux"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/build_installer.sh"
chmod +x "$WORK_DIR/scripts/packaging/build_installer.sh"

cat > "$WORK_DIR/scripts/packaging/installer-template.sh" <<'EOF'
#!/bin/bash
INSTALL_VERSION=""
EOF

cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated" "$WORK_DIR/scripts/packaging/update-daemon/cloudtolocalllm-updated"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.service" "$WORK_DIR/scripts/packaging/update-daemon/cloudtolocalllm-updated.service"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer" "$WORK_DIR/scripts/packaging/update-daemon/cloudtolocalllm-updated.timer"

cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
printf '%s\n' "$TEMP_FILE"
: > "$TEMP_FILE"
exit 0
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

if PATH="$BIN_DIR:$PATH" bash "$WORK_DIR/scripts/packaging/build_installer.sh" >/dev/null 2>&1; then
  echo "build_installer.sh unexpectedly succeeded in failure-path harness" >&2
  exit 1
fi

if [[ -e "$TEMP_FILE" ]]; then
  echo "Expected temporary installer file cleanup, but $TEMP_FILE still exists" >&2
  exit 1
fi

echo "[test_build_installer_tempfile_cleanup] Passed"
