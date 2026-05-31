#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/powershell/Build-GitHubReleaseAssets.ps1"

if [[ ! -f "$TARGET_SCRIPT" ]]; then
  echo "Missing release asset builder: $TARGET_SCRIPT" >&2
  exit 1
fi

for needle in \
  '# Creates all release assets: `cloudtolocalllm-<version>-portable.zip`, `CloudToLocalLLM-Windows-<version>-Setup.exe`, and checksums' \
  'Write-Host "  • cloudtolocalllm-$Version-portable.zip"' \
  'Write-Host "  • CloudToLocalLLM-Windows-$Version-Setup.exe"' \
  'Write-LogInfo "Creating cloudtolocalllm-$Version-portable.zip..."' \
  'Write-LogSuccess "cloudtolocalllm-$Version-portable.zip created successfully: $packageName"' \
  'Write-LogInfo "Creating CloudToLocalLLM-Windows-$Version-Setup.exe..."' \
  'Write-LogWarning "Inno Setup not found. Use -InstallInnoSetup to install it automatically before creating CloudToLocalLLM-Windows-$Version-Setup.exe."' \
  'Write-LogWarning "Skipping CloudToLocalLLM-Windows-$Version-Setup.exe creation."' \
  'Write-LogSuccess "CloudToLocalLLM-Windows-$Version-Setup.exe created successfully: $installerPath"' \
  'Write-LogError "Failed to create CloudToLocalLLM-Windows-$Version-Setup.exe: $($_.Exception.Message)"' \
  '# Create cloudtolocalllm-$Version-portable.zip' \
  '# Create CloudToLocalLLM-Windows-$Version-Setup.exe if not skipped' \
  'Write-LogInfo "cloudtolocalllm-$Version-portable.zip location: $zipPath"' \
  'Write-LogInfo "CloudToLocalLLM-Windows-$Version-Setup.exe location: $installerPath"'; do
  if ! grep -Fq "$needle" "$TARGET_SCRIPT"; then
    echo "Release asset builder missing expected explicit asset string: $needle" >&2
    exit 1
  fi
done

echo "[test_build_github_release_assets_explicit_names] Passed"
