#!/bin/bash
set -e

# Verify version consistency across files
# Usage: ./verify-version.sh

echo "ðŸ” Verifying version consistency..."

# Get version from assets/version.json
ASSETS_VERSION=$(jq -r '.version' assets/version.json)
# Extract semantic part
SEMANTIC_ASSETS=$(echo "$ASSETS_VERSION" | cut -d'+' -f1)

# Get version from pubspec.yaml
PUBSPEC_VERSION=$(grep "^version: " pubspec.yaml | cut -d' ' -f2)
SEMANTIC_PUBSPEC=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)

# Get version from api-backend package.json
API_VERSION_RAW=$(jq -r '.version' services/api-backend/package.json)
API_VERSION=$(echo "$API_VERSION_RAW" | cut -d'+' -f1)

# Get version from streaming-proxy package.json
PROXY_VERSION_RAW=$(jq -r '.version' services/streaming-proxy/package.json)
PROXY_VERSION=$(echo "$PROXY_VERSION_RAW" | cut -d'+' -f1)

# Get version from app_config.dart
APP_CONFIG_VERSION=$(grep "static const String appVersion = '" lib/config/app_config.dart | cut -d"'" -f2)

echo "  assets/version.json: $ASSETS_VERSION"
echo "  pubspec.yaml:        $PUBSPEC_VERSION"
echo "  api-backend:         $API_VERSION_RAW (semantic: $API_VERSION)"
echo "  streaming-proxy:     $PROXY_VERSION_RAW (semantic: $PROXY_VERSION)"
echo "  app_config.dart:     $APP_CONFIG_VERSION"

# Compare semantic parts
if [ "$SEMANTIC_ASSETS" != "$SEMANTIC_PUBSPEC" ]; then
    echo "â Œ ERROR: Semantic version mismatch between assets/version.json and pubspec.yaml"
    exit 1
fi

if [ "$SEMANTIC_ASSETS" != "$API_VERSION" ]; then
    echo "â Œ ERROR: Semantic version mismatch between assets/version.json and api-backend/package.json"
    exit 1
fi

if [ "$SEMANTIC_ASSETS" != "$PROXY_VERSION" ]; then
    echo "â Œ ERROR: Semantic version mismatch between assets/version.json and streaming-proxy/package.json"
    exit 1
fi

if [ "$SEMANTIC_ASSETS" != "$APP_CONFIG_VERSION" ]; then
    echo "â Œ ERROR: Semantic version mismatch between assets/version.json and lib/config/app_config.dart"
    exit 1
fi

if [ "$SEMANTIC_ASSETS" != "$API_VERSION" ]; then
    echo "âŒ ERROR: Semantic version mismatch between assets/version.json and api-backend/package.json"
    exit 1
fi

echo "âœ… Version consistency verified"
