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

# Pass through arguments to the native kilocode binary
# Ensure we capture the prompt correctly if it's the last argument
kilocode "$@"
