#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$PROJECT_ROOT/docs/development/BUILDING_GUIDE.md"

if ! grep -Fq 'cp -a build/web/. /var/www/html/' "$FILE"; then
  echo "missing hardened static hosting copy command" >&2
  exit 1
fi

if grep -Fq 'cp -r build/web/* /var/www/html/' "$FILE"; then
  echo "found legacy static hosting copy command" >&2
  exit 1
fi

echo "[test_building_guide_web_deployment_copy_hardening] Passed"
