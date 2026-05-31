#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/aur-push.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing AUR push workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

python3 - <<'PY' "$WORKFLOW_FILE"
from pathlib import Path
import sys

workflow = Path(sys.argv[1]).read_text()
checks = [
    'SSH_WORK_DIR="$(mktemp -d /tmp/aur-ssh.XXXXXX)"',
    'AUR_KEY_FILE="$SSH_WORK_DIR/id_rsa"',
    'AUR_KNOWN_HOSTS="$SSH_WORK_DIR/known_hosts"',
    'AUR_REPO_DIR=""',
    'cleanup_aur_publish() {',
    'trap cleanup_aur_publish EXIT',
    "printf '%s\\n' \"$AUR_SSH_PRIVATE_KEY\" > \"$AUR_KEY_FILE\"",
    'ssh-keyscan aur.archlinux.org > "$AUR_KNOWN_HOSTS"',
    'eval "$(ssh-agent -s)"',
    'ssh-add "$AUR_KEY_FILE"',
    'export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$AUR_KNOWN_HOSTS -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes"',
    'AUR_REPO_DIR="$(mktemp -d /tmp/aur-repo.XXXXXX)"',
]
for needle in checks:
    if needle not in workflow:
        raise SystemExit(f'missing AUR push hardening string: {needle}')

for forbidden in [
    'mkdir -p ~/.ssh',
    'echo "${{ secrets.AUR_SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa',
    'ssh-keyscan aur.archlinux.org > ~/.ssh/known_hosts',
    'ssh-add ~/.ssh/id_rsa',
    'rm -rf /tmp/aur-repo',
]:
    if forbidden in workflow:
        raise SystemExit(f'workflow still contains old AUR push pattern: {forbidden}')

print('[test_aur_push_ssh_workspace] Passed')
PY
