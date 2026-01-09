#!/bin/bash
set -e

# Kilocode CLI Wrapper (Simplified)
# This script bridges the gap between local environment execution and the containerized CLI
# It mimics the argument structure expected by the old .cjs script but delegates to the native binary

if [ "$1" == "--configure-ci" ]; then
  # CI configuration is handled by environment variables in the native CLI
  # We just acknowledge the command to maintain interface compatibility
  echo "CI configuration handled natively by environment variables."
  exit 0
fi

# Delegate to the local Node.js implementation
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "$DIR/gemini-orchestrator.cjs" "$@"
