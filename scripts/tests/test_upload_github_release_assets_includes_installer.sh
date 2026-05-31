#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$PROJECT_ROOT/scripts/powershell/Upload-GitHubReleaseAssets.ps1"

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Missing upload script: $SCRIPT_FILE" >&2
  exit 1
fi

for needle in \
  'Upload all release assets, including the Windows installer.' \
  'cloudtolocalllm-$Version-portable.zip' \
  'cloudtolocalllm-$Version-portable.zip.sha256' \
  'CloudToLocalLLM-Windows-$Version-Setup.exe' \
  'CloudToLocalLLM-Windows-$Version-Setup.exe.sha256' \
  'Missing release assets:' \
  'CloudToLocalLLM-Windows-3.7.0-Setup.exe'; do
  if ! grep -Fq "$needle" "$SCRIPT_FILE"; then
    echo "Upload script missing expected installer publishing string: $needle" >&2
    exit 1
  fi
done

echo "[test_upload_github_release_assets_includes_installer] Passed"
