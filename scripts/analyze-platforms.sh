#!/bin/bash
set -e
# Load nvm if available
[ -s "/home/rightguy/.nvm/nvm.sh" ] && source "/home/rightguy/.nvm/nvm.sh"

# Analyze which platforms need updates using Kilocode AI
# Outputs: new_version, needs_managed, needs_local, needs_desktop, needs_mobile

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Platform Changes with Kilocode AI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get current version
CURRENT_VERSION=$(jq -r '.version' assets/version.json)
echo "Current version: $CURRENT_VERSION"

# Get recent commits (limit to 3 for faster processing)
COMMITS=$(git log --oneline --no-merges -3)
echo ""
echo "Recent commits:"
echo "$COMMITS"
echo ""

# Get changed files
CHANGED_FILES=$(git diff --name-only HEAD~5..HEAD 2>/dev/null || git log --name-only --oneline -5 | grep -v "^[a-f0-9]" || echo "")
echo "Changed files (last 5 commits):"
echo "$CHANGED_FILES"
echo ""

# Pre-analyze files to force cloud deployment for web-related changes
FORCE_CLOUD=false
if echo "$CHANGED_FILES" | grep -qE "(web/|lib/.*auth|lib/.*router|lib/config/|services/|k8s/|\.github/workflows/deploy-aks\.yml)"; then
    FORCE_CLOUD=true
    echo "ðŸŒ  DETECTED WEB-RELATED CHANGES - Cloud deployment will be forced"
fi

# Prepare prompt for Kilocode - properly escape for JSON
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | tr '\n' ' ')
FILES_ESCAPED=$(echo "$CHANGED_FILES" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | tr '\n' ' ')

# Get current semantic version (without build metadata)
SEMANTIC_VERSION=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_DATE=$(date +%Y%m%d%H%M)

PROMPT="Current version: $CURRENT_VERSION
Semantic version: $SEMANTIC_VERSION
Recent commits: $COMMITS_ESCAPED
Changed files: $FILES_ESCAPED

Analyze changes and determine deployment needs. Output ONLY valid JSON:

{
  \"bump_type\": \"none\",
  \"semantic_version\": \"$SEMANTIC_VERSION\",
  \"needs_managed\": true,
  \"needs_local\": true,
  \"needs_desktop\": true,
  \"needs_mobile\": false,
  \"reasoning\": \"Conservative deployment for debugging changes\"
}

CRITICAL RULES FOR VERSION BUMPING:
- DEFAULT: bump_type=none, semantic_version=$SEMANTIC_VERSION (NEVER increment for internal changes)
- DEBUGGING/FIXES/CI/SECURITY: Always bump_type=none (keep same semantic version)
- PATCH: ONLY for user-visible bug fixes that users will notice
- MINOR: ONLY for new user-facing features that users will see
- MAJOR: ONLY for breaking user experience changes
- Internal changes, CI fixes, security patches, debugging = NO VERSION BUMP

DEPLOYMENT RULES:
- CORE CHANGES (main.dart, lib/services/, lib/models/) trigger ALL platforms
- PLATFORM-SPECIFIC (web/, windows/, android/) trigger only that platform
- Managed (SaaS): web/, services/ (including package-lock.json/dependencies), k8s/, auth changes (production cloud)
- Local (On-Prem): web/, services/ (including package-lock.json/dependencies), k8s/, auth changes (docker desktop/local)
- Desktop: windows/, linux/, desktop code
- Mobile: android/, ios/, mobile code"

# Helper: Enforce KILOCODE_TOKEN
if [ -z "$KILOCODE_TOKEN" ]; then
    echo "❌ ERROR: KILOCODE_TOKEN is not set."
    exit 1
fi

# Get response from Kilocode
echo "🚀 Sending request to Kilocode AI..."
if ! command -v kilocode >/dev/null 2>&1; then
    echo "❌ ERROR: 'kilocode' command not found."
    exit 1
fi

set +e
RESPONSE=$(kilocode "$PROMPT" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ CRITICAL FAILURE: Kilocode analysis failed"
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

# Parse without fallback
SEMANTIC_VERSION_NEW=$(echo "$JSON_RESPONSE" | jq -r '.semantic_version')
BUMP_TYPE=$(echo "$JSON_RESPONSE" | jq -r '.bump_type')
NEEDS_MANAGED=$(echo "$JSON_RESPONSE" | jq -r '.needs_managed')
NEEDS_LOCAL=$(echo "$JSON_RESPONSE" | jq -r '.needs_local')
NEEDS_DESKTOP=$(echo "$JSON_RESPONSE" | jq -r '.needs_desktop')
NEEDS_MOBILE=$(echo "$JSON_RESPONSE" | jq -r '.needs_mobile')
REASONING=$(echo "$JSON_RESPONSE" | jq -r '.reasoning')

# Build final version with build metadata
NEW_VERSION="${SEMANTIC_VERSION_NEW}+${BUILD_DATE}"

# FAIL FAST: Removed auto-increment conflict logic.
# If the version already exists, the build will naturally fail downstream, 
# or we could check it here and fail early.

if git rev-parse "v$SEMANTIC_VERSION_NEW" >/dev/null 2>&1 || gh release view "v$SEMANTIC_VERSION_NEW" >/dev/null 2>&1; then
    if [ "$BUMP_TYPE" != "none" ]; then
        echo "❌ CRITICAL FAILURE: Tag v$SEMANTIC_VERSION_NEW already exists. AI produced a conflicting version."
        exit 1
    fi
fi

# Strict validation
if [ "$SEMANTIC_VERSION_NEW" == "null" ] || [ -z "$SEMANTIC_VERSION_NEW" ] || [ "$NEEDS_MANAGED" == "null" ]; then
    echo "❌ CRITICAL FAILURE: Failed to parse required fields from Kilocode response"
    exit 1
fi

echo "✅ Kilocode Analysis:"
echo "  Bump type: $BUMP_TYPE"
echo "  New version: $NEW_VERSION"
echo "  Managed: $NEEDS_MANAGED"
echo "  Local: $NEEDS_LOCAL"
echo "  Desktop: $NEEDS_DESKTOP"
echo "  Mobile: $NEEDS_MOBILE"
echo "  Reasoning: $REASONING"

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
    echo "❌ CRITICAL FAILURE: Invalid version format: $NEW_VERSION"
    exit 1
fi

# Output for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
    echo "needs_managed=$NEEDS_MANAGED" >> $GITHUB_OUTPUT
    echo "needs_local=$NEEDS_LOCAL" >> $GITHUB_OUTPUT
    echo "needs_desktop=$NEEDS_DESKTOP" >> $GITHUB_OUTPUT
    echo "needs_mobile=$NEEDS_MOBILE" >> $GITHUB_OUTPUT
    echo "bump_type=$BUMP_TYPE" >> $GITHUB_OUTPUT
else
    echo "Running locally - GITHUB_OUTPUT not set"
    echo "new_version=$NEW_VERSION"
    echo "needs_managed=$NEEDS_MANAGED"
    echo "needs_local=$NEEDS_LOCAL"
    echo "needs_desktop=$NEEDS_DESKTOP"
    echo "needs_mobile=$NEEDS_MOBILE"
    echo "bump_type=$BUMP_TYPE"
fi
