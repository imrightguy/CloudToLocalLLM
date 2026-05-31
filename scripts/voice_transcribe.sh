#!/usr/bin/env bash
set -euo pipefail

normalize_tmpdir_root() {
  local candidate="${1:-/tmp}"
  while [[ "$candidate" == */ ]]; do
    candidate="${candidate%/}"
  done
  if [[ -z "$candidate" || "$candidate" == "/" ]]; then
    echo "/tmp"
  else
    echo "$candidate"
  fi
}

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <wav-path>" >&2
  exit 2
fi

audio_path="$1"

if ! command -v whisper >/dev/null 2>&1; then
  echo "voice transcription requires the 'whisper' CLI from openai-whisper" >&2
  echo "install it, then retry: python3 -m pip install -U openai-whisper" >&2
  exit 127
fi

tmpdir_root="$(normalize_tmpdir_root "${TMPDIR:-/tmp}")"
mkdir -p "$tmpdir_root"
tmpdir="$(mktemp -d "$tmpdir_root/paperclip-voice.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

model="${CLOUDTOLOCALLLM_WHISPER_MODEL:-base}"
whisper "$audio_path" --model "$model" --output_format txt --output_dir "$tmpdir" >/dev/null

transcript_file="$(find "$tmpdir" -maxdepth 1 -name '*.txt' -print -quit)"
if [[ -z "$transcript_file" ]]; then
  echo "" >&2
  exit 0
fi

cat "$transcript_file"
