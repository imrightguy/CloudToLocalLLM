#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
DIST_DIR="$WORK_DIR/dist"
LOG_FILE="$WORK_DIR/build.log"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$DIST_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_TOOLS_DIR/dpkg-deb" <<'EOF'
#!/bin/sh
set -euo pipefail
echo "dpkg-deb should not have been called" >&2
exit 1
EOF
chmod +x "$FAKE_TOOLS_DIR/dpkg-deb"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version:
EOF

set +e
PATH="$FAKE_TOOLS_DIR:$PATH" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
PUBSPEC_FILE="$WORK_DIR/pubspec.yaml" \
bash "$TARGET_SCRIPT" > "$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_deb.sh to fail when version entry is empty" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq "version entry is empty in pubspec.yaml" "$LOG_FILE"; then
  echo "Expected empty version error message" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if compgen -G "$DIST_DIR/*.deb" >/dev/null; then
  echo "Expected no package output when version is empty" >&2
  ls -l "$DIST_DIR" >&2
  exit 1
fi

echo "[test_build_deb_empty_version_guard] Passed"
