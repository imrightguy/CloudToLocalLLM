#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/get_helm.sh"
OUTPUT_FILE="$(mktemp)"

set +e
TMPDIR="/tmp////" HELM_INSTALL_DIR="/" bash "$TARGET_SCRIPT" > "$OUTPUT_FILE" 2>&1
status=$?
set -e
if [[ $status -eq 0 ]]; then
  cat "$OUTPUT_FILE" >&2
  echo "Expected get_helm.sh to reject HELM_INSTALL_DIR=/" >&2
  exit 1
fi
if ! grep -q 'HELM_INSTALL_DIR must be a non-root install path' "$OUTPUT_FILE"; then
  cat "$OUTPUT_FILE" >&2
  echo "Expected a clear HELM_INSTALL_DIR validation error" >&2
  exit 1
fi
