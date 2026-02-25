#!/bin/bash

# Fix Cloudflare SSL mode to "flexible" to resolve 500 errors
# This allows Cloudflare to connect to origin via HTTP while providing HTTPS to visitors

set -e

# Check if CLOUDFLARE_API_TOKEN is set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "âŒ Error: CLOUDFLARE_API_TOKEN environment variable is not set"
    echo "Please set it with: export CLOUDFLARE_API_TOKEN=your_token"
    exit 1
fi

CF_API_TOKEN="$CLOUDFLARE_API_TOKEN"
ZONE_NAME="cloudtolocalllm.online"

echo "ðŸ”§ Fixing Cloudflare SSL mode for $ZONE_NAME..."

# Get Zone ID
CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [ "$CF_ZONE_ID" = "null" ] || [ -z "$CF_ZONE_ID" ]; then
    echo "âŒ Unable to determine Cloudflare Zone ID"
    exit 1
fi

echo "Found Zone ID: $CF_ZONE_ID"

# Change SSL mode to "flexible"
echo "Setting SSL mode to 'flexible'..."
RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value": "flexible"}')

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
    echo "âœ… Cloudflare SSL mode changed to 'flexible' successfully!"
    echo ""
    echo "This allows:"
    echo "  - Visitors â†’ Cloudflare: HTTPS (secure)"
    echo "  - Cloudflare â†’ Origin: HTTP (no TLS required on origin)"
    echo ""
    echo "The 500 error should now be resolved. Please wait a few seconds and try accessing the site again."
else
    echo "âŒ Failed to change SSL mode"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

