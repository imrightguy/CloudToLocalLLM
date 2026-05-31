#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing deployment workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

for needle in \
  'cp -f "$GITHUB_WORKSPACE/dist/aur/PKGBUILD" .' \
  'docker run --rm -v "$(pwd)":/pkg -w /pkg archlinux:latest bash -c' \
  'sudo chown -R "$(id -u):$(id -g)" .'; do
  if ! grep -Fq "$needle" "$WORKFLOW_FILE"; then
    echo "Deployment workflow missing expected AUR hardening string: $needle" >&2
    exit 1
  fi
done

echo "[test_deployment_aur_command_quotes] Passed"
