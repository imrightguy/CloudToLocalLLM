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
OUTPUT_DEB="$DIST_DIR/cloudtolocalllm_failure_amd64.deb"
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
exit 1
EOF
chmod +x "$FAKE_DPKG_DEB"

set +e
TMPDIR="/" \
PATH="$WORK_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
OUTPUT_DEB="$OUTPUT_DEB" \
DPKG_DEB_CMD="$FAKE_DPKG_DEB" \
"$TARGET_SCRIPT" >"$WORK_DIR/output.log" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_deb.sh to fail when dpkg-deb exits non-zero" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq "root:/tmp/cloudtolocalllm-deb." "$FAKE_LOG"; then
  echo "Expected TMPDIR=/ to fall back to /tmp for the package root" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

if ! grep -Fq "out:$OUTPUT_DEB" "$FAKE_LOG"; then
  echo "Expected custom OUTPUT_DEB path to be passed to dpkg-deb" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

if find /tmp -maxdepth 1 -type d -name 'cloudtolocalllm-deb.*' | grep -q .; then
  echo "Expected temporary Debian package root cleanup after failure" >&2
  find /tmp -maxdepth 1 -type d -name 'cloudtolocalllm-deb.*' >&2
  exit 1
fi

if [[ -e "$OUTPUT_DEB" ]]; then
  echo "Expected failed Debian output cleanup at $OUTPUT_DEB" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

echo "[test_build_deb_tmpdir_root_fallback_failure_cleanup] Passed"
