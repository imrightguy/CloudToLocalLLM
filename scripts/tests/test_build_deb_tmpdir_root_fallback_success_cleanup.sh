#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_BUILD_DIR="$FAKE_ROOT/build/linux/x64/release/bundle"
FAKE_DPKG_DEB="$WORK_DIR/dpkg-deb"
FAKE_LOG="$WORK_DIR/dpkg-deb.log"
DIST_DIR="$FAKE_ROOT/dist/linux"
OUTPUT_DEB="$DIST_DIR/cloudtolocalllm_2.3.4_amd64.deb"
mkdir -p "$FAKE_ROOT" "$FAKE_BUILD_DIR" "$DIST_DIR"
export FAKE_LOG

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

TMPDIR='/' \
PATH="$WORK_DIR:/usr/bin:/bin" \
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
DPKG_DEB_CMD="$FAKE_DPKG_DEB" \
"$TARGET_SCRIPT"

if [[ ! -f "$OUTPUT_DEB" ]]; then
  echo "Expected Debian package output at $OUTPUT_DEB" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

if ! grep -Fq 'root:/tmp/cloudtolocalllm-deb.' "$FAKE_LOG"; then
  echo "Expected TMPDIR=/ to fall back to /tmp for the package root" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

pkg_root="$(awk -F: '/^root:/ {print $2; exit}' "$FAKE_LOG")"
if [[ -z "$pkg_root" ]]; then
  echo "Expected to capture the temporary package root" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

if [[ -d "$pkg_root" ]]; then
  echo "Expected temporary package root cleanup after success" >&2
  printf '%s\n' "$pkg_root" >&2
  exit 1
fi

if ! grep -Fq "out:$OUTPUT_DEB" "$FAKE_LOG"; then
  echo "Expected output path to match the configured Debian output path" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

echo "[test_build_deb_tmpdir_root_fallback_success_cleanup] Passed"
