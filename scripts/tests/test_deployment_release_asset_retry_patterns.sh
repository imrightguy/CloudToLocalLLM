#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$PROJECT_ROOT/scripts/release/verify_github_release_assets.py"

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Missing release asset verifier: $SCRIPT_FILE" >&2
  exit 1
fi

for needle in \
  'required_assets = {' \
  'cloudtolocalllm-{version}-portable.zip' \
  'cloudtolocalllm-{version}-portable.zip.sha256' \
  'CloudToLocalLLM-Windows-{version}-Setup.exe' \
  'CloudToLocalLLM-Windows-{version}-Setup.exe.sha256' \
  'cloudtolocalllm_{version}_amd64.deb' \
  'cloudtolocalllm_{version}_amd64.deb.sha256' \
  'cloudtolocalllm-{version}-x86_64.AppImage' \
  'cloudtolocalllm-{version}-x86_64.AppImage.sha256' \
  'for attempt in range(1, retry_attempts + 1):' \
  'time.sleep(retry_delay_seconds)' \
  'Verified GitHub release assets: ' \
  'Missing release assets: '; do
  if ! grep -Fq "$needle" "$SCRIPT_FILE"; then
    echo "Release asset verifier missing expected string: $needle" >&2
    exit 1
  fi
done

echo "[test_deployment_release_asset_retry_patterns] Passed"
