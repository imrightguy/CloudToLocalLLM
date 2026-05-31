#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
import json
import sys
from pathlib import Path

script = Path(sys.argv[1]).read_text()
required = 'set -euo pipefail'
if 'set -euo pipefail' not in script:
    raise SystemExit(f'missing hardening flag: {required}')

if 'if command -v sudo >/dev/null 2>&1;' not in script:
    raise SystemExit('setup script should gate multilib enablement on sudo availability instead of file writability')

if '[[ -w /etc/pacman.conf ]]' in script:
    raise SystemExit('setup script still uses a file writability check for /etc/pacman.conf')

if 'No Flutter command found. Set FLUTTER_CMD or install flutter.' not in script:
    raise SystemExit('setup script does not fail fast when no Flutter command is available')

if '|| true' in script:
    raise SystemExit('setup script still contains masked failure handling via || true')

if '"$FLUTTER_CMD" config --android-sdk /opt/android-sdk' not in script:
    raise SystemExit('setup script does not use the Flutter command override for config')

if '"$FLUTTER_CMD" doctor --android-licenses' not in script:
    raise SystemExit('setup script does not use the Flutter command override for doctor')

if '"$FLUTTER_CMD" pub get' not in script:
    raise SystemExit('setup script does not use the Flutter command override for pub get')

if 'touch "$HOME/.bashrc"' not in script:
    raise SystemExit('setup script does not create ~/.bashrc before appending shell exports')

blocks = {
    'sequentialthinking.json': '{\n  "command": "mcp-sequentialthinking",\n  "args": []\n}',
    'context7.json': '{\n  "command": "mcp-context7",\n  "args": []\n}',
    'memory.json': '{\n  "command": "mcp-memory",\n  "args": []\n}',
}
for name, expected in blocks.items():
    if expected not in script:
        raise SystemExit(f'missing or malformed JSON block for {name}')
    json.loads(expected)

print('[test_setup_development_environment_mcp_configs] Passed')
PY
