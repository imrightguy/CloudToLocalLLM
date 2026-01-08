#!/bin/bash

# Setup script for Kilocode CLI
# Configures the API key and verifies the installation

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kilocode CLI Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if API key is provided as argument
if [ -n "$1" ]; then
    API_KEY="$1"
else
    # Prompt for API key
    echo "Please enter your Kilocode API Key (JWT):"
    read -s API_KEY
fi

if [ -z "$API_KEY" ]; then
    echo "❌ Error: API Key cannot be empty."
    exit 1
fi

# Export the key for the current session
export KILOCODE_TOKEN="$API_KEY"
export KILOCODE_STRICT_COMPATIBILITY="true"
export KILOCODE_VERBOSE="true"
echo ""
echo "✅ API Key configured for this session."

# Verify the key
echo "Verifying API key with a test request..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure the script is executable
chmod +x "$SCRIPT_DIR/gemini-cli-cli.cjs"

# Run a test request
TEST_RESPONSE=$(node "$SCRIPT_DIR/gemini-cli-cli.cjs" "Hello, are you working?")
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] && [ -n "$TEST_RESPONSE" ]; then
    echo "✅ Verification successful!"
    echo "Response from Kilocode: ${TEST_RESPONSE:0:100}..."
    
    echo ""
    echo "To persist this key, add the following to your shell profile (e.g., ~/.bashrc or ~/.zshrc):"
    echo "export KILOCODE_TOKEN='$API_KEY'"
    
    echo ""
    echo "For GitHub Actions, add a secret named KILOCODE_TOKEN:"
    echo "gh secret set KILOCODE_TOKEN --body '$API_KEY'"
else
    echo "❌ Verification failed."
    echo "Exit code: $EXIT_CODE"
    echo "Response: $TEST_RESPONSE"
    exit 1
fi
