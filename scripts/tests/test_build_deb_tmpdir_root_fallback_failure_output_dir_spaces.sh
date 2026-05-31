#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_TOOLS="$WORK_DIR/bin"
DIST_DIR="$FAKE_ROOT/dist dir with spaces/linux packages"
OUTPUT_DEB="$DIST_DIR/cloudtolocalllm_2.3.4_amd64.deb"
DPKG_LOG="$WORK_DIR/dpkg.log"
TMPDIR_BASE="/tmp"
mkdir -p "$FAKE_ROOT" "$FAKE_BUILD_DIR" "$FAKE_TOOLS" "$DIST_DIR" "$FAKE_ROOT/assets/images"
export DPKG_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: cloudtolocalllm
version: 2.3.4+5
EOF

cat > "$FAKE_BUILD_DIR/cloudtolocalllm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/cloudtolocalllm"

printf '%s\n' 'fake-icon' > "$FAKE_ROOT/assets/images/app_icon.png"

cat > "$FAKE_TOOLS/fake-dpkg-deb" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "$DPKG_LOG"
root="${3:?missing package root}"
out="${4:?missing output path}"
printf 'root:%s\n' "$root" >> "$DPKG_LOG"
printf 'out:%s\n' "$out" >> "$DPKG_LOG"
mkdir -p "$(dirname "$out")"
printf '%s\n' 'partial-deb' > "$out"
chmod +x "$out"
exit 1
EOF
chmod +x "$FAKE_TOOLS/fake-dpkg-deb"

set +e
TMPDIR='/' \
PATH="$FAKE_TOOLS:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
OUTPUT_DEB="$OUTPUT_DEB" \
DPKG_DEB_CMD="$FAKE_TOOLS/fake-dpkg-deb" \
"$PROJECT_ROOT/scripts/packaging/build_deb.sh" >/tmp/test_build_deb_tmpdir_root_fallback_failure_output_dir_spaces.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_deb.sh to fail when dpkg-deb exits non-zero" >&2
  cat /tmp/test_build_deb_tmpdir_root_fallback_failure_output_dir_spaces.log >&2
  exit 1
fi

if ! grep -Fq "root:$TMPDIR_BASE/cloudtolocalllm-deb." "$DPKG_LOG"; then
  echo "Expected TMPDIR=/ to fall back to /tmp for the package root" >&2
  cat "$DPKG_LOG" >&2
  exit 1
fi

if ! grep -Fq "out:$OUTPUT_DEB" "$DPKG_LOG"; then
  echo "Expected output path to match the configured spaced Debian output path" >&2
  cat "$DPKG_LOG" >&2
  exit 1
fi

pkg_root="$(sed -n 's#^root:\(.*cloudtolocalllm-deb\.[^ ]*\)$#\1#p' "$DPKG_LOG" | head -n 1)"
if [[ -z "$pkg_root" ]]; then
  echo "Expected to capture the temporary package root" >&2
  cat "$DPKG_LOG" >&2
  exit 1
fi

if [[ -d "$pkg_root" ]]; then
  echo "Expected temporary package root cleanup after failure" >&2
  printf '%s\n' "$pkg_root" >&2
  exit 1
fi

if [[ -e "$OUTPUT_DEB" ]]; then
  echo "Expected failed Debian output cleanup at $OUTPUT_DEB" >&2
  cat /tmp/test_build_deb_tmpdir_root_fallback_failure_output_dir_spaces.log >&2
  exit 1
fi

echo "[test_build_deb_tmpdir_root_fallback_failure_output_dir_spaces] Passed"
