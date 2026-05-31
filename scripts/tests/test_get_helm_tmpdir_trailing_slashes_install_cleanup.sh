#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/get_helm.sh"
FAKE_ROOT="$(mktemp -d)"
FAKE_BIN="$FAKE_ROOT/bin"
MK_TEMP_LOG="$FAKE_ROOT/mktemp.log"
INSTALL_DIR="$FAKE_ROOT/install"
mkdir -p "$FAKE_BIN" "$INSTALL_DIR"
export MK_TEMP_LOG

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="$MK_TEMP_LOG"
if [[ "$1" != "-d" ]]; then
  echo "unexpected mktemp invocation: $*" >&2
  exit 1
fi
template="$2"
path="${template//XXXXXX/123456}"
mkdir -p "$path"
printf 'template=%s path=%s\n' "$template" "$path" >> "$log_file"
printf '%s\n' "$path"
EOF
chmod +x "$FAKE_BIN/mktemp"

cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ "$output" == *.sha256 ]]; then
  printf 'deadbeef  helm-v1.2.3-linux-amd64.tar.gz\n' > "$output"
else
  printf 'placeholder download\n' > "$output"
fi
EOF
chmod +x "$FAKE_BIN/curl"

cat > "$FAKE_BIN/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dest=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      dest="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
mkdir -p "$dest/linux-amd64"
cat > "$dest/linux-amd64/helm" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo v1.2.3
else
  echo "$(basename "$0")"
fi
SCRIPT
chmod +x "$dest/linux-amd64/helm"
EOF
chmod +x "$FAKE_BIN/tar"

cat > "$FAKE_BIN/cp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "copy failure" >&2
exit 1
EOF
chmod +x "$FAKE_BIN/cp"

set +e
TMPDIR="/tmp////" PATH="$FAKE_BIN:$PATH" USE_SUDO=false VERIFY_CHECKSUM=false VERIFY_SIGNATURES=false DESIRED_VERSION='v1.2.3' HELM_INSTALL_DIR="$INSTALL_DIR" bash "$TARGET_SCRIPT" > "$FAKE_ROOT/output.log" 2>&1
status=$?
set -e
if [[ $status -eq 0 ]]; then
  echo "Expected get_helm.sh to fail when cp fails" >&2
  cat "$FAKE_ROOT/output.log" >&2
  exit 1
fi
if ! grep -q '^template=/tmp/helm-installer\.' "$MK_TEMP_LOG"; then
  cat "$MK_TEMP_LOG" >&2
  echo "Expected mktemp to normalize TMPDIR=/tmp//// to /tmp" >&2
  exit 1
fi
created_path="$(sed -n 's/^template=.* path=//p' "$MK_TEMP_LOG" | tail -n 1)"
if [[ -z "$created_path" ]]; then
  cat "$MK_TEMP_LOG" >&2
  echo "Expected mktemp log to include a created path" >&2
  exit 1
fi
if [[ -e "$created_path" ]]; then
  echo "Expected Helm temp root cleanup to remove $created_path after copy failure" >&2
  exit 1
fi
if [[ -e "$INSTALL_DIR/helm" ]]; then
  echo "Did not expect helm binary to be installed on copy failure" >&2
  exit 1
fi
