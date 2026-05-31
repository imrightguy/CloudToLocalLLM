#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_TOOLS_DIR="$WORK_DIR/bin"
FAKE_DPKG_DEB_LOG="$WORK_DIR/dpkg-deb.log"
FAKE_PKG_ROOT="$WORK_DIR/pkg-root"
DIST_DIR="$WORK_DIR/dist"
VERSION="$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)"
OUTPUT_DEB="$DIST_DIR/cloudtolocalllm_${VERSION}_amd64.deb"
mkdir -p "$FAKE_BUILD_DIR" "$FAKE_TOOLS_DIR" "$DIST_DIR"
export FAKE_DPKG_DEB_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_TOOLS_DIR/mktemp" <<EOF
#!/bin/bash
if [[ "\$1" == "-d" ]]; then
  mkdir -p "$FAKE_PKG_ROOT"
  printf '%s\n' "$FAKE_PKG_ROOT"
  exit 0
fi
exec /usr/bin/mktemp "\$@"
EOF
chmod +x "$FAKE_TOOLS_DIR/mktemp"

cat > "$FAKE_TOOLS_DIR/dpkg-deb" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_DPKG_DEB_LOG:?}"
exit 1
EOF
chmod +x "$FAKE_TOOLS_DIR/dpkg-deb"

if PATH="$FAKE_TOOLS_DIR:$PATH" \
  BUILD_DIR="$FAKE_BUILD_DIR" \
  DIST_DIR="$DIST_DIR" \
  APP_NAME="CloudToLocalLLM" \
  PACKAGE_NAME="cloudtolocalllm" \
  bash "$TARGET_SCRIPT" >/dev/null 2>&1; then
  echo "build_deb.sh unexpectedly succeeded in failure-path harness" >&2
  exit 1
fi

if [[ -d "$FAKE_PKG_ROOT" ]]; then
  echo "Expected temporary package root cleanup, but $FAKE_PKG_ROOT still exists" >&2
  exit 1
fi

if [[ -f "$OUTPUT_DEB" ]]; then
  echo "Expected failed .deb output cleanup, but $OUTPUT_DEB still exists" >&2
  exit 1
fi

if ! grep -Fq -- '--root-owner-group --build' "$FAKE_DPKG_DEB_LOG"; then
  echo "Expected dpkg-deb to be invoked before failure" >&2
  exit 1
fi

echo "[test_build_deb_tempdir_cleanup] Passed"
