#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/voice_transcribe.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
TMP_LOG="$WORK_DIR/mktemp.log"
WHISPER_LOG="$WORK_DIR/whisper.log"
mkdir -p "$FAKE_BIN"
export TMP_LOG WHISPER_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/whisper" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$WHISPER_LOG"
outdir=""
for ((i=1; i<=$#; i++)); do
  if [[ "${!i}" == "--output_dir" ]]; then
    j=$((i+1))
    outdir="${!j}"
  fi
done
mkdir -p "$outdir"
printf 'hello from whisper\n' > "$outdir/audio.txt"
EOF
chmod +x "$FAKE_BIN/whisper"

cat > "$FAKE_BIN/mktemp" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TMP_LOG"
/usr/bin/mktemp "$@"
EOF
chmod +x "$FAKE_BIN/mktemp"

printf 'dummy wav' > "$WORK_DIR/audio.wav"

output="$(TMPDIR='/' PATH="$FAKE_BIN:$PATH" bash "$TARGET_SCRIPT" "$WORK_DIR/audio.wav")"

if [[ "$output" != "hello from whisper" ]]; then
  echo "Expected transcript output from whisper stub" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

tempdir_path="$(sed -n '1p' "$TMP_LOG" | awk '{print $NF}')"
if [[ -z "$tempdir_path" || "$tempdir_path" != /tmp/paperclip-voice.* ]]; then
  echo "Expected voice tmpdir to fall back to /tmp" >&2
  cat "$TMP_LOG" >&2
  exit 1
fi

if ! grep -Fq -- '--output_dir' "$WHISPER_LOG"; then
  echo "Expected whisper stub to be called" >&2
  cat "$WHISPER_LOG" >&2
  exit 1
fi

if [[ -e "$tempdir_path" ]]; then
  echo "Expected voice tempdir to be cleaned up on exit" >&2
  printf '%s\n' "$tempdir_path" >&2
  exit 1
fi

echo "[test_voice_transcribe_tmpdir_root_fallback] Passed"
