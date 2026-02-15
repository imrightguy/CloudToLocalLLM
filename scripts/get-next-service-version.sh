#!/bin/bash
set -e

# Get the next version for a specific service from ACR
# Usage: ./get-next-service-version.sh <service-name> <acr-name>
# Output: Only the version number (e.g., "4.4.1")

SERVICE_NAME="$1"
ACR_NAME="$2"

if [ -z "$SERVICE_NAME" ] || [ -z "$ACR_NAME" ]; then
    >&2 echo "Usage: $0 <service-name> <acr-name>"
    >&2 echo "Example: $0 web imrightguyzoidbot"
    exit 1
fi

>&2 echo "Fetching latest version for service: $SERVICE_NAME from ACR: $ACR_NAME"

# Get all tags for this service, filter for semantic versions, sort and get latest
LATEST_TAG=$(az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository "$SERVICE_NAME" \
    --orderby time_desc \
    --output json 2>/dev/null | \
    jq -r '[.[] | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-z]+)?$"))] | .[0]' || echo "")

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
    # No version found, start with version from version.json
    BASE_VERSION=$(jq -r '.version' assets/version.json 2>/dev/null || echo "4.4.0")
    >&2 echo "No existing version found, starting from: $BASE_VERSION"
    echo "$BASE_VERSION"
    exit 0
fi

>&2 echo "Latest existing version: $LATEST_TAG"

# Strip service suffix if present (e.g., "4.4.0-api" â†’ "4.4.0")
BASE_VERSION=$(echo "$LATEST_TAG" | sed 's/-[a-z]*$//')

# Parse version
IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"

# Bump patch version
PATCH=$((PATCH + 1))

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
>&2 echo "Next version: $NEW_VERSION"
echo "$NEW_VERSION"

