#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DAEMON_SCRIPT="$PROJECT_ROOT/scripts/packaging/update-daemon/cloudtolocalllm-updated"
WORK_DIR="$(mktemp -d)"
HOME_DIR="$WORK_DIR/home"
BIN_DIR="$WORK_DIR/bin"
STATE_DIR="$WORK_DIR/state"
TMPDIR_ROOT="$WORK_DIR/nested/tmp/dir"
CURL_LOG="$WORK_DIR/curl.log"
MKTEMP_LOG="$WORK_DIR/mktemp.log"
mkdir -p "$HOME_DIR" "$BIN_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$BIN_DIR/curl" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "\$*" >> "$CURL_LOG"
out_file=''
url=''
args=("\$@")
for ((i=0; i<\${#args[@]}; i++)); do
  case "\${args[i]}" in
    -o|--output)
      out_file="\${args[i+1]}"
      ((i++))
      ;;
    -* )
      ;;
    *)
      if [[ -z "\$url" ]]; then
        url="\${args[i]}"
      fi
      ;;
  esac
done

if [[ "\$url" == *'api.github.com'* ]]; then
  cat > "\$out_file" <<'JSON'
{"assets":[{"name":"cloudtolocalllm-1.2.3-x86_64.AppImage","browser_download_url":"https://example.com/cloudtolocalllm-1.2.3.AppImage"}]}
JSON
else
  printf 'appimage-binary' > "\$out_file"
fi
EOF
chmod +x "$BIN_DIR/curl"

REAL_MKTEMP="$(command -v mktemp)"
cat > "$BIN_DIR/mktemp" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "\$*" >> "$MKTEMP_LOG"
exec "$REAL_MKTEMP" "\$@"
EOF
chmod +x "$BIN_DIR/mktemp"

HOME="$HOME_DIR" \
TMPDIR="$TMPDIR_ROOT" \
STATE_DIR_OVERRIDE="$STATE_DIR" \
PATH="$BIN_DIR:$PATH" \
"$DAEMON_SCRIPT" download 1.2.3

EXPECTED_OUTPUT="$HOME_DIR/.local/share/cloudtolocalllm/cache/cloudtolocalllm-1.2.3.AppImage"
[[ -d "$TMPDIR_ROOT" ]]
[[ -f "$EXPECTED_OUTPUT" ]]
grep -Fqx 'appimage-binary' "$EXPECTED_OUTPUT"
[[ $(wc -l < "$CURL_LOG") -eq 2 ]]
grep -Fq 'api.github.com/repos/CloudToLocalLLM-online/CloudToLocalLLM/releases/tags/v1.2.3' "$CURL_LOG"
grep -Fq 'https://example.com/cloudtolocalllm-1.2.3.AppImage' "$CURL_LOG"
[[ $(wc -l < "$MKTEMP_LOG") -eq 2 ]]
grep -Fq "${TMPDIR_ROOT%/}/cloudtolocalllm-1.2.3.AppImage" "$MKTEMP_LOG"
grep -Fq "${TMPDIR_ROOT%/}/cloudtolocalllm-updated-response" "$MKTEMP_LOG"

echo "[test_update_daemon_nested_tmpdir_download] Passed"
