#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_SCRIPT="$PROJECT_ROOT/scripts/deploy-simon-vps.sh"
COMPOSE_FILE="$PROJECT_ROOT/deploy/simon-vps/docker-compose.yml"

if [[ ! -f "$DEPLOY_SCRIPT" ]]; then
  echo "Missing deploy script: $DEPLOY_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing compose file: $COMPOSE_FILE" >&2
  exit 1
fi

python3 - <<'PY' "$DEPLOY_SCRIPT" "$COMPOSE_FILE"
from pathlib import Path
import re
import sys

deploy_script = Path(sys.argv[1]).read_text()
compose_file = Path(sys.argv[2]).read_text()

script_checks = [
    'for attempt in \\$(seq 1 24); do',
    'if curl -fsS "http://127.0.0.1:$SIMON_PUBLIC_HTTP_PORT/health" >/dev/null; then',
    'docker compose --env-file .env up -d --build',
]
for needle in script_checks:
    if needle not in deploy_script:
        raise SystemExit(f'missing Simon deploy readiness check string: {needle}')

api_healthcheck_snippets = [
    '"curl"',
    '"-fsS"',
    '"http://127.0.0.1:3000/health"',
]
for needle in api_healthcheck_snippets:
    if needle not in compose_file:
        raise SystemExit('Simon API healthcheck must use curl against the API container health endpoint')

match = re.search(r'\n  api:\n(.*?)\n  web:\n', compose_file, re.S)
if match is None:
    raise SystemExit('Simon compose file missing api service block')

api_block = match.group(1)
if 'wget' in api_block:
    raise SystemExit('Simon API healthcheck still uses wget')

print('[test_deploy_simon_vps_health_wait] Passed')
PY
