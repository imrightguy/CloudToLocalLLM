#!/bin/bash
set -e

# Test Cloudflare Cache Purge
# Usage: 
#   export CLOUDFLARE_API_KEY="your_global_api_key"
#   export CLOUDFLARE_EMAIL="your_cloudflare_email"
#   ./scripts/test-cloudflare-cache-purge.sh

if [ -z "$CLOUDFLARE_API_KEY" ]; then
    echo "âŒ CLOUDFLARE_API_KEY not set"
    echo ""
    echo "To get your API key:"
    echo "1. Go to: https://dash.cloudflare.com/profile/api-tokens"
    echo "2. Scroll to 'API Keys' section"
    echo "3. Click 'View' next to Global API Key"
    echo ""
    echo "Then run:"
    echo "  export CLOUDFLARE_API_KEY='your_key_here'"
    echo "  export CLOUDFLARE_EMAIL='your_email_here'"
    echo "  $0"
    exit 1
fi

if [ -z "$CLOUDFLARE_EMAIL" ]; then
    echo "âŒ CLOUDFLARE_EMAIL not set"
    echo "Please run: export CLOUDFLARE_EMAIL='your_email_here'"
    exit 1
fi

echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "Testing Cloudflare Cache Purge"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""

# Get Zone ID for cloudtolocalllm.online
DOMAIN="cloudtolocalllm.online"
echo "Step 1: Fetching Zone ID for: $DOMAIN"

ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "Content-Type: application/json")

if echo "$ZONE_RESPONSE" | grep -q '"success":true'; then
    ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "âœ… Zone ID: $ZONE_ID"
else
    echo "âŒ Failed to get Zone ID"
    echo "Response: $ZONE_RESPONSE"
    exit 1
fi

echo ""
echo "Step 2: Purging cache for entire zone (all domains)..."

RESPONSE=$(curl -s -X POST \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{"purge_everything": true}')

echo ""
if echo "$RESPONSE" | grep -q '"success": true'; then
    echo "âœ… Cache purged successfully for all domains:"
    echo "   - cloudtolocalllm.online"
    echo "   - app.cloudtolocalllm.online"
    echo "   - api.cloudtolocalllm.online"
    echo ""
    echo "âœ… Test PASSED! The credentials work."
else
    echo "âŒ Cache purge failed"
    echo "Response: $RESPONSE"
    echo ""
    echo "Common issues:"
    echo "1. API key might be incorrect"
    echo "2. Email might be incorrect"
    echo "3. API key might not have cache purge permissions"
    exit 1
fi

