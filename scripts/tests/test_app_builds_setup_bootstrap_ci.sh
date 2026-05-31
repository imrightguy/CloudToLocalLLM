#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW="$PROJECT_ROOT/.github/workflows/app-builds.yml"

python3 - <<'PY' "$WORKFLOW"
import sys
from pathlib import Path

workflow = Path(sys.argv[1]).read_text()
checks = [
    'Setup Bootstrap Fresh Home Smoke Test',
    './scripts/tests/test_setup_wsl_full_missing_bashrc.sh',
    'Packaging AppImage Failure Cleanup Test',
    './scripts/tests/test_packaging_build_appimage_failure_cleanup.sh',
    'Packaging Installer Tempfile Cleanup Test',
    './scripts/tests/test_build_installer_tempfile_cleanup.sh',
    'Packaging Update Daemon Strict Cleanup Test',
    './scripts/tests/test_update_daemon_strict_cleanup.sh',
    'Packaging Debian Tempdir Cleanup Test',
    './scripts/tests/test_build_deb_tempdir_cleanup.sh',
    'Packaging Release Artifact Hidden Bundle Test',
    './scripts/tests/test_deployment_release_artifact_hidden_bundle.sh',
    'Packaging Release Asset Name and Location Test',
    './scripts/tests/test_build_github_release_assets_explicit_names.sh',
    'Windows Installer Path Contract Test',
    './scripts/tests/test_windows_installer_path_contract.sh',
    'Deployment Release Asset Verification and Location Test',
    './scripts/tests/test_deployment_release_artifact_names.sh',
    'Deployment Release Asset Retry Pattern Test',
    './scripts/tests/test_deployment_release_asset_retry_patterns.sh',
    'Deployment Release Asset Script Wiring Test',
    './scripts/tests/test_deployment_release_asset_script_wiring.sh',
    'Deployment Release Asset Script Behavior Test',
    './scripts/tests/test_verify_github_release_assets_script.sh',
    'Deployment Release Asset Script Invalid Env Test',
    './scripts/tests/test_verify_github_release_assets_script_invalid_env.sh',
    'Deployment AUR SSH Workspace Hardening Test',
    './scripts/tests/test_deployment_aur_ssh_workspace.sh',
    'Deployment AUR Tempdir Cleanup Test',
    './scripts/tests/test_deployment_aur_tempdir_cleanup.sh',
    'Deployment AUR Command Quote Hardening Test',
    './scripts/tests/test_deployment_aur_command_quotes.sh',
    'Deployment AUR Cleanup Consolidation Test',
    './scripts/tests/test_deployment_aur_cleanup_consolidated.sh',
    'Build Windows Release Assets',
    './scripts/powershell/Build-GitHubReleaseAssets.ps1 -InstallInnoSetup',
    'Upload Windows Release Assets',
    'windows-release-assets',
    'Packaging Build Guide Web Deployment Copy Hardening Test',
    './scripts/tests/test_building_guide_web_deployment_copy_hardening.sh',
    'Deployment Docker Compose Certbot Permission Normalization Test',
    './scripts/tests/test_docker_compose_certbot_permission_normalization.sh',
    'Container SSL EntryPoint Certbot Permissions Test',
    './scripts/tests/test_entrypoint_with_ssl_fallback_certbot_permissions.sh',
    'Dockerfile Nginx Tmp Permissions Test',
    './scripts/tests/test_dockerfile_nginx_tmp_permissions.sh',
    'Setup Development Environment Command Guards Test',
    './scripts/tests/test_setup_development_environment_command_guards.sh',
]
for check in checks:
    if check not in workflow:
        raise SystemExit(f'missing workflow coverage for {check}')

print('[test_app_builds_setup_bootstrap_ci] Passed')
PY
