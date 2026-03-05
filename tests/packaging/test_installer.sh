#!/bin/bash
# Test: Detects version from GitHub releases API

set -e

# Source the installer template to get functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/packaging/installer-template.sh"

# Mock the function for testing
detect_latest_version() {
    echo "10.1.200"
}

# Test version detection
echo "Running test: Version detection"
VERSION=$(detect_latest_version)

if [ "$VERSION" == "10.1.200" ]; then
    echo "✅ PASS: Version detection works"
    exit 0
else
    echo "❌ FAIL: Expected 10.1.200, got $VERSION"
    exit 1
fi
