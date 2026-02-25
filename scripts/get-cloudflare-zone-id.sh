#!/bin/bash
set -e

# Script to get Cloudflare Zone ID for a domain

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Error: CLOUDFLARE_API_TOKEN environment variable not set"
    echo "Please run: export CLOUDFLARE_API_TOKEN=your_token_here"
    exit 1
fi

DOMAIN="${1:-cloudtolocalllm.online}"

echo "Fetching Zone ID for domain: $DOMAIN"
echo ""

RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if successful
if echo "$RESPONSE" | grep -q '"success":true'; then
    ZONE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$ZONE_ID" ]; then
        echo "âœ… Zone ID found: $ZONE_ID"
        echo ""
        echo "To add as GitHub secret, run:"
        echo "  gh secret set CLOUDFLARE_ZONE_ID --body '$ZONE_ID'"
    else
        echo "âš ï¸  Zone ID not found in response"
        echo "Response: $RESPONSE"
        exit 1
    fi
else
    echo "âŒ Failed to fetch Zone ID"
    echo "Response: $RESPONSE"
    exit 1
fi

