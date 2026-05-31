#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_DPKG_DEB="$WORK_DIR/dpkg-deb"
FAKE_LOG="$WORK_DIR/dpkg-deb.log"
DIST_DIR="$WORK_DIR/dist"
mkdir -p "$FAKE_BUILD_DIR" "$DIST_DIR" "$WORK_DIR/bin"
export FAKE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

cat > "$FAKE_DPKG_DEB" <<'EOF'
#!/bin/bash
set -euo pipefail
root="${3:?missing package root}"
out="${4:?missing output path}"
if [[ ! -d "$root" ]]; then
  echo "missing package root: $root" >&2
  exit 1
fi
printf 'root:%s\n' "$root" >> "$FAKE_LOG"
printf 'out:%s\n' "$out" >> "$FAKE_LOG"
: > "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_DPKG_DEB"

TMPDIR="/" \
PATH="$WORK_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
DPKG_DEB_CMD="$FAKE_DPKG_DEB" \
APP_NAME="CloudToLocalLLM" \
PACKAGE_NAME="cloudtolocalllm" \
"$TARGET_SCRIPT"

VERSION="$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)"
PACKAGE_FILE="$DIST_DIR/cloudtolocalllm_${VERSION}_amd64.deb"
[[ -f "$PACKAGE_FILE" ]]
[[ -x "$PACKAGE_FILE" ]]
[[ -s "$FAKE_LOG" ]]
grep -Fq 'root:/tmp/cloudtolocalllm-deb.' "$FAKE_LOG"
grep -Fq "out:$PACKAGE_FILE" "$FAKE_LOG"

echo "[test_build_deb_tmpdir_slash_fallback] Passed"
