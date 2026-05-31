#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"
SCRIPT_FILE="$PROJECT_ROOT/scripts/release/verify_github_release_assets.py"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing deployment workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Missing release asset verifier: $SCRIPT_FILE" >&2
  exit 1
fi

for needle in \
  'Verify GitHub Release Assets Published' \
  'run: python3 scripts/release/verify_github_release_assets.py' \
  'GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}' \
  'VERSION: ${{ needs.ai_change_analysis.outputs.new_version }}' \
  'RELEASE_TAG: v${{ needs.ai_change_analysis.outputs.new_version }}' \
  'GITHUB_API_BASE_URL: https://api.github.com' \
  'RETRY_ATTEMPTS: 6' \
  'RETRY_DELAY_SECONDS: 10' \
  'artifacts: "dist/linux/*,dist/windows/cloudtolocalllm-${{ needs.ai_change_analysis.outputs.new_version }}-portable.zip,dist/windows/cloudtolocalllm-${{ needs.ai_change_analysis.outputs.new_version }}-portable.zip.sha256,dist/windows/CloudToLocalLLM-Windows-${{ needs.ai_change_analysis.outputs.new_version }}-Setup.exe,dist/windows/CloudToLocalLLM-Windows-${{ needs.ai_change_analysis.outputs.new_version }}-Setup.exe.sha256,dist/aur/*"'; do
  if ! grep -Fq "$needle" "$WORKFLOW_FILE"; then
    echo "Deployment workflow missing expected script invocation string: $needle" >&2
    exit 1
  fi
done

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

release_action_line=$(grep -nF '      - name: Create GitHub Release' "$WORKFLOW_FILE" | head -n1 | cut -d: -f1)
verify_release_line=$(grep -nF '      - name: Verify GitHub Release Assets Published' "$WORKFLOW_FILE" | head -n1 | cut -d: -f1)
if [[ -z "$release_action_line" || -z "$verify_release_line" ]]; then
  echo "Could not find release action or verification step in workflow" >&2
  exit 1
fi
if (( verify_release_line <= release_action_line )); then
  echo "Verify step must appear after the GitHub release action" >&2
  echo "Release action line: $release_action_line, Verify line: $verify_release_line" >&2
  exit 1
fi

echo "[test_deployment_release_asset_script_wiring] Passed"
