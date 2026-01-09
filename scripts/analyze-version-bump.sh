#!/bin/bash
set -e
set -o pipefail

# Script to analyze commits and determine version bump using Kilocode AI
# Outputs: new_version and bump_type to GITHUB_OUTPUT

# Enable error tracing
trap 'echo "Error on line $LINENO"' ERR

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Commits with Kilocode AI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get current version
CURRENT_VERSION=$(jq -r '.version' assets/version.json)
echo "Current version: $CURRENT_VERSION"

# Get commits since last version tag
LAST_TAG=$(git describe --tags --abbrev=0 --match="*-cloud-*" 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
    # No previous tag, get all commits
    COMMITS=$(git log --oneline --no-merges -20)
else
    # Get commits since last tag
    COMMITS=$(git log --oneline --no-merges ${LAST_TAG}..HEAD)
fi

echo ""
echo "Commits to analyze:"
echo "$COMMITS"
echo ""

# Prepare prompt for Kilocode (escape special characters for JSON)
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\"/g' | tr '\n' ' ')

PROMPT="You are a semantic versioning expert. Analyze these git commits and determine the appropriate version bump. Current version: $CURRENT_VERSION. Commits: $COMMITS_ESCAPED. Rules: BREAKING CHANGE or breaking: means MAJOR bump (x.0.0). feat: or feature: means MINOR bump (0.x.0) ONLY if it adds significant NEW user-facing functionality. Backend improvements, infrastructure changes, provider swaps (e.g., changing auth provider), enabling work, or fixes (even if labeled feat) should be PATCH (0.0.x) if they do not change the user experience. fix: or bugfix: means PATCH bump (0.0.x). chore:, docs:, style:, refactor:, test: means PATCH bump (0.0.x). If multiple types, use the highest priority (MAJOR > MINOR > PATCH). Respond with ONLY a JSON object with this exact format: {\"bump_type\": \"major or minor or patch\", \"new_version\": \"x.y.z\", \"reasoning\": \"brief explanation\"}. Do not include any other text, markdown, code blocks, or formatting. Only the raw JSON object."

# Call Kilocode
echo "🚀 Calling Kilocode AI to analyze commits..."

# Enforce KILOCODE_TOKEN
if [ -z "$KILOCODE_TOKEN" ]; then
    echo "❌ ERROR: KILOCODE_TOKEN is not set. Strict mode requires credentials."
    exit 1
fi

if ! command -v gemini-cli >/dev/null 2>&1; then
    echo "❌ ERROR: 'gemini-cli' command not found."
    exit 1
fi

# Call Kilocode and capture both stdout and stderr
set +e
RESPONSE=$(gemini-cli "$PROMPT" --json 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo "❌ CRITICAL FAILURE: Kilocode CLI failed with exit code: $EXIT_CODE"
    echo "$RESPONSE"
    exit 1
fi

# Extract JSON from response
JSON_RESPONSE=$(echo "$RESPONSE" | sed -n '/{/,/}/p')

if ! echo "$JSON_RESPONSE" | jq empty >/dev/null 2>&1; then
    echo "❌ CRITICAL FAILURE: Invalid JSON response from Kilocode."
    echo "$RESPONSE"
    exit 1
fi

# Extract values from JSON response
BUMP_TYPE=$(echo "$JSON_RESPONSE" | jq -r '.bump_type')
NEW_VERSION=$(echo "$JSON_RESPONSE" | jq -r '.new_version')
REASONING=$(echo "$JSON_RESPONSE" | jq -r '.reasoning')

if [ "$BUMP_TYPE" == "null" ] || [ "$NEW_VERSION" == "null" ]; then
    echo "❌ CRITICAL FAILURE: Missing required fields in Kilocode response."
    exit 1
fi

echo ""
echo "✅ Kilocode Analysis:"
echo "  Bump type: $BUMP_TYPE"
echo "  New version: $NEW_VERSION"
echo "  Reasoning: $REASONING"

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ CRITICAL FAILURE: Invalid version format from Kilocode: $NEW_VERSION"
    echo "Strict mode requires valid AI output. Terminating."
    exit 1
fi

echo ""
echo "✅ Version Decision:"
echo "  Current: $CURRENT_VERSION"
echo "  New:     $NEW_VERSION"
echo "  Type:    $BUMP_TYPE"

# Output for GitHub Actions
echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
echo "bump_type=$BUMP_TYPE" >> $GITHUB_OUTPUT
echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT
