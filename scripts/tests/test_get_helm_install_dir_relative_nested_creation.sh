#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/get_helm.sh"
FAKE_ROOT="$(mktemp -d)"
FAKE_BIN="$FAKE_ROOT/bin"
MK_TEMP_LOG="$FAKE_ROOT/mktemp.log"
mkdir -p "$FAKE_BIN"
for cmd in bash cat chmod date grep mkdir rm sed tail awk uname tr; do
  /usr/bin/ln -s "$(command -v "$cmd")" "$FAKE_BIN/$cmd"
done
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

cat > "$FAKE_BIN/wget" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -O)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ "$output" == *.sha256 ]]; then
  printf 'deadbeef\n' > "$output"
else
  printf 'placeholder download\n' > "$output"
fi
EOF
chmod +x "$FAKE_BIN/wget"

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
/usr/bin/cp "$1" "$2"
EOF
chmod +x "$FAKE_BIN/cp"

cat > "$FAKE_BIN/openssl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "SHA256(/tmp/fake)= deadbeef"
EOF
chmod +x "$FAKE_BIN/openssl"

cat > "$FAKE_BIN/gpg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${3:-}" in
  --import)
    :
    ;;
  --export)
    :
    ;;
  --status-fd=1)
    printf '[GNUPG:] GOODSIG 123\n[GNUPG:] VALIDSIG 456\n'
    ;;
  *)
    :
    ;;
esac
exit 0
EOF
chmod +x "$FAKE_BIN/gpg"

mkdir -p "$FAKE_ROOT/workspace"
set +e
cd "$FAKE_ROOT/workspace"
TMPDIR="/tmp////" PATH="$FAKE_BIN" USE_SUDO=false VERIFY_CHECKSUM=true VERIFY_SIGNATURES=true DESIRED_VERSION='v1.2.3' HELM_INSTALL_DIR='nested/install////' bash "$TARGET_SCRIPT" > "$FAKE_ROOT/output.log" 2>&1
status=$?
set -e
if [[ $status -ne 0 ]]; then
  cat "$FAKE_ROOT/output.log" >&2
  echo "Expected get_helm.sh to succeed with a relative nested HELM_INSTALL_DIR" >&2
  exit 1
fi
if ! grep -q '^Preparing to install helm into nested/install$' "$FAKE_ROOT/output.log"; then
  cat "$FAKE_ROOT/output.log" >&2
  echo "Expected relative install path to be normalized and preserved" >&2
  exit 1
fi
if [[ ! -x "$FAKE_ROOT/workspace/nested/install/helm" ]]; then
  echo "Expected helm binary at relative nested install path" >&2
  exit 1
fi
if ! grep -q '^template=/tmp/helm-installer\.' "$MK_TEMP_LOG"; then
  cat "$MK_TEMP_LOG" >&2
  echo "Expected mktemp to normalize TMPDIR=/tmp//// to /tmp" >&2
  exit 1
fi
