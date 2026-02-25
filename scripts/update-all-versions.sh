#!/bin/bash
set -e

# Script to update all version references across the project
# Usage: ./update-all-versions.sh <new-version> <commit-sha>

NEW_VERSION="$1"
COMMIT_SHA="$2"
SHORT_SHA="${COMMIT_SHA:0:8}"
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

if [ -z "$NEW_VERSION" ]; then
    echo "â Œ Usage: $0 <new-version> <commit-sha>"
    exit 1
fi

echo "â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” "
echo "Updating All Version References"
echo "â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” "
echo "New version: $NEW_VERSION"
echo "Commit SHA: $SHORT_SHA"
echo ""

# 1. Update assets/version.json
echo "1. Updating assets/version.json..."
jq -n \
  --arg version "$NEW_VERSION" \
  --arg build_number "$BUILD_NUMBER" \
  --arg build_date "$BUILD_DATE" \
  --arg git_commit "$SHORT_SHA" \
  --arg buildTimestamp "$BUILD_TIMESTAMP" \
  '{
    version: $version,
    build_number: $build_number,
    build_date: $build_date,
    git_commit: $git_commit,
    buildTimestamp: $buildTimestamp
  }' > assets/version.json

# 2. Update assets/component-versions.json
echo "2. Updating assets/component-versions.json..."
jq -n \
  --arg web "$NEW_VERSION" \
  --arg api "$NEW_VERSION-api" \
  --arg postgres "$NEW_VERSION-postgres" \
  --arg streaming_proxy "$NEW_VERSION-proxy" \
  --arg base "$NEW_VERSION-base" \
  --arg last_updated "$BUILD_DATE" \
  '{
    web: $web,
    api: $api,
    postgres: $postgres,
    streaming_proxy: $streaming_proxy,
    base: $base,
    last_updated: $last_updated
  }' > assets/component-versions.json

# 3. Update pubspec.yaml
echo "3. Updating pubspec.yaml..."
# Flutter uses version+build format (e.g., 4.5.0+202512031420)
# Extract semantic version (everything before first +) and add our build number
SEMANTIC_VERSION=$(echo "$NEW_VERSION" | cut -d'+' -f1)
sed -i "s/^version: .*/version: ${SEMANTIC_VERSION}+${BUILD_NUMBER}/" pubspec.yaml

# 4. Update services/api-backend/package.json
echo "4. Updating services/api-backend/package.json..."
if [ -f "services/api-backend/package.json" ]; then
    jq --arg version "$NEW_VERSION" '.version = $version' services/api-backend/package.json > /tmp/api-package.json
    mv /tmp/api-package.json services/api-backend/package.json
fi

# 5. Update services/streaming-proxy/package.json
echo "5. Updating services/streaming-proxy/package.json..."
if [ -f "services/streaming-proxy/package.json" ]; then
    jq --arg version "$NEW_VERSION" '.version = $version' services/streaming-proxy/package.json > /tmp/proxy-package.json
    mv /tmp/proxy-package.json services/streaming-proxy/package.json
fi

# 6. Update README.md version badges (if they exist)
echo "6. Updating README.md..."
if [ -f "README.md" ]; then
    sed -i "s/v[0-9]\+\.[0-9]\+\.[0-9]\+-/v${NEW_VERSION}-/g" README.md || true
fi

# 7. Update any documentation with version references
echo "7. Updating documentation..."
if [ -f "docs/VERSIONING.md" ]; then
    # Update example versions in documentation
    sed -i "s/4\.[0-9]\+\.[0-9]\+/${NEW_VERSION}/g" docs/VERSIONING.md || true
fi

# 8. Update lib/main.dart version string
echo "8. Updating lib/main.dart version string..."
if [ -f "lib/main.dart" ]; then
    sed -i "s/DART MAIN START ----- v[0-9]\+\.[0-9]\+\.[0-9]\+\(+[0-9]\+\)*/DART MAIN START ----- v${NEW_VERSION}/g" lib/main.dart
fi

# 9. Update SECURITY.md
echo "9. Updating SECURITY.md..."
if [ -f "SECURITY.md" ]; then
    # Extract Major.Minor (e.g., 4.14.3 -> 4.14)
    MAJOR_MINOR=$(echo "$NEW_VERSION" | cut -d. -f1-2)
    NEW_ROW="| ${MAJOR_MINOR}.x  | :white_check_mark: |"
    
    # Check if this version is already listed
    if ! grep -q "| ${MAJOR_MINOR}.x" SECURITY.md; then
        # Insert after the table header separator line
        sed -i "/| ------- | ------------------ |/a $NEW_ROW" SECURITY.md
        echo "   Added version ${MAJOR_MINOR}.x to supported list"
    else
        echo "   Version ${MAJOR_MINOR}.x already listed"
    fi
fi

# 10. Update lib/config/app_config.dart
echo "10. Updating lib/config/app_config.dart..."
if [ -f "lib/config/app_config.dart" ]; then
    sed -i "s/static const String appVersion = '.*';/static const String appVersion = '${NEW_VERSION}';/" lib/config/app_config.dart
fi

# 11. Generate Changelog
echo "11. Generating Changelog..."
chmod +x scripts/generate-changelog.sh
./scripts/generate-changelog.sh "$NEW_VERSION"

# 12. Update root package.json
echo "12. Updating root package.json..."
if [ -f "package.json" ]; then
    jq --arg version "$NEW_VERSION" '.version = $version' package.json > /tmp/root-package.json
    mv /tmp/root-package.json package.json
fi

# 13. Update .env.production.template
echo "13. Updating .env.production.template..."
if [ -f "config/.env.production.template" ]; then
    sed -i "s/CloudToLocalLLM v[0-9]\+\.[0-9]\+\.[0-9]\+/CloudToLocalLLM v${NEW_VERSION}/g" config/.env.production.template
    sed -i "s/APP_VERSION=[0-9]\+\.[0-9]\+\.[0-9]\+/APP_VERSION=${NEW_VERSION}/g" config/.env.production.template
fi

# 14. Update test setup and documentation files that might have hardcoded versions
echo "14. Updating miscellaneous version references..."
# EXCLUDE lock files and package.json files from this mass replacement to avoid breaking dependencies
grep -rlE "3\.10\.0|10\.1\.0" . --exclude-dir=.git --exclude-dir=node_modules --exclude="*-lock.json" --exclude="package.json" | xargs sed -i "s/3\.10\.0/${NEW_VERSION}/g; s/10\.1\.0/${NEW_VERSION}/g" 2>/dev/null || true

echo ""
echo "â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” "
echo "âœ… All Version References Updated"
echo "â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” "
echo ""
echo "Files updated:"
echo "  âœ… assets/version.json â†’ $NEW_VERSION"
echo "  âœ… assets/component-versions.json â†’ all services"
echo "  âœ… pubspec.yaml â†’ ${NEW_VERSION}+${BUILD_NUMBER}"
echo "  âœ… services/api-backend/package.json â†’ $NEW_VERSION"
echo "  âœ… services/streaming-proxy/package.json â†’ $NEW_VERSION"
echo "  âœ… root package.json â†’ $NEW_VERSION"
echo "  âœ… config/.env.production.template"
echo "  âœ… lib/main.dart â†’ v${NEW_VERSION}"
echo "  âœ… README.md â†’ updated badges"
echo "  âœ… docs/VERSIONING.md â†’ updated examples"
echo "  âœ… SECURITY.md â†’ added new version row"
echo "  âœ… lib/config/app_config.dart â†’ $NEW_VERSION"
echo "  âœ… CHANGELOG.md â†’ prepended new version entry"
echo ""
