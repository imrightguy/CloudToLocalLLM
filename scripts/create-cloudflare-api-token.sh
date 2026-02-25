#!/bin/bash
set -e

# Script to create a scoped Cloudflare API token with minimal permissions
# This token will ONLY be able to:
# 1. Read zone information
# 2. Purge cache

if [ -z "$CLOUDFLARE_API_KEY" ]; then
    echo "âŒ CLOUDFLARE_API_KEY not set"
    echo ""
    echo "Please run:"
    echo "  export CLOUDFLARE_API_KEY='your_global_api_key'"
    echo "  export CLOUDFLARE_EMAIL='your_email'"
    echo "  $0"
    exit 1
fi

if [ -z "$CLOUDFLARE_EMAIL" ]; then
    echo "âŒ CLOUDFLARE_EMAIL not set"
    exit 1
fi

echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "Creating Scoped Cloudflare API Token"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""

# Get Zone ID first
DOMAIN="cloudtolocalllm.online"
echo "Step 1: Getting Zone ID for $DOMAIN..."

ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ZONE_ID" ]; then
    echo "âŒ Failed to get Zone ID"
    echo "Response: $ZONE_RESPONSE"
    exit 1
fi

echo "âœ… Zone ID: $ZONE_ID"
echo ""

# Create API token with minimal permissions
echo "Step 2: Creating scoped API token..."
echo "Permissions:"
echo "  - Zone.Cache Purge (Purge)"
echo "  - Zone.Zone (Read)"
echo "  - Scope: cloudtolocalllm.online only"
echo ""

TOKEN_REQUEST=$(cat <<EOF
{
  "name": "CloudToLocalLLM Deployment - Cache Purge (No IP Restrictions)",
  "policies": [
    {
      "effect": "allow",
      "resources": {
        "com.cloudflare.api.account.zone.${ZONE_ID}": "*"
      },
      "permission_groups": [
        {
          "id": "c8fed203ed3043cba015a93ad1616f1f",
          "name": "Zone Read"
        },
        {
          "id": "e17beae8b8cb423a99b1730f21238bed",
          "name": "Cache Purge"
        }
      ]
    }
  ]
}
EOF
)

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "Content-Type: application/json" \
    --data "$TOKEN_REQUEST")

if echo "$RESPONSE" | grep -q '"success": true'; then
    TOKEN=$(echo "$RESPONSE" | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
    TOKEN_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo "âœ… API Token created successfully!"
    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "Token Details:"
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    echo "Token ID: $TOKEN_ID"
    echo "Token Value: $TOKEN"
    echo ""
    echo "âš ï¸  IMPORTANT: Save this token now! You won't be able to see it again."
    echo ""
    echo "To add it to GitHub secrets, run:"
    echo "  gh secret set CLOUDFLARE_API_TOKEN --body '$TOKEN'"
    echo ""
    echo "To test it works:"
    echo "  export CLOUDFLARE_API_TOKEN='$TOKEN'"
    echo "  # Update test script to use CLOUDFLARE_API_TOKEN instead of CLOUDFLARE_API_KEY"
    echo ""
    
    # Save to credentials file
    if [ -f ".cloudflare-credentials.json" ]; then
        echo "Updating .cloudflare-credentials.json with scoped token..."
        cat > .cloudflare-credentials.json <<EOF
{
  "global_api_key": "abc12d491e2bc24a60e9e276be8d5b1af62bf",
  "origin_ca_key": "v1.0-5ec28e52c84a8165343ae25b-5cc5dbb2d8bd9d901872aa2e7d9fb23c28a0f65231fb4f49e3d272a33989876bc02b7bd4f8988688c0673468321887bf07b4ce797f94eb05741306583a5f93046cfd5e12900988053e",
  "email": "cmaltais@cloudtolocalllm.online",
  "scoped_api_token": "$TOKEN",
  "scoped_token_id": "$TOKEN_ID",
  "scoped_token_permissions": "Zone Read + Cache Purge for cloudtolocalllm.online only"
}
EOF
        echo "âœ… Credentials file updated"
    fi
else
    echo "âŒ Failed to create API token"
    echo "Response: $RESPONSE"
    exit 1
fi

