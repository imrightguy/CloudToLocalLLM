#!/bin/bash
API_TOKEN="9lO2G2n_jL_jtfhOG_zAnCa-GIU9flTsLl6bGbvG"
ACCOUNT_ID="35fa09929e656c4e96e4aa79909d11b7"
TUNNEL_ID="62da6c19-947b-4bf6-acad-100a73de4e0d"

echo "Using Account ID: $ACCOUNT_ID"

echo "Fetching Tunnel Token..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tunnels/$TUNNEL_ID/token" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Code: $HTTP_CODE"
echo "Response Body: $BODY"

TUNNEL_TOKEN=$(echo "$BODY" | jq -r '.result')

if [ "$TUNNEL_TOKEN" == "null" ] || [ -z "$TUNNEL_TOKEN" ]; then
    echo "Failed to fetch Tunnel Token"
    echo "Retrying with cfd_tunnel endpoint..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo "Retry HTTP Code: $HTTP_CODE"
    echo "Retry Response Body: $BODY"
    
    TUNNEL_TOKEN=$(echo "$BODY" | jq -r '.result')
fi

if [ "$TUNNEL_TOKEN" == "null" ] || [ -z "$TUNNEL_TOKEN" ]; then
    echo "Failed to fetch Tunnel Token"
    exit 1
fi

echo "Tunnel Token fetched."

echo "Fetching DNS Write Permission ID..."
PERM_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/permission_groups" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[] | select(.name == "DNS Write") | .id')

echo "Permission ID: $PERM_ID"

echo "Fetching Zone ID..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=cloudtolocalllm.online" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Zone ID: $ZONE_ID"

echo "Creating DNS Token..."
DNS_TOKEN_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"GitHub Actions DNS Update $(date +%s)\",
    \"policies\": [
      {
        \"effect\": \"allow\",
        \"resources\": {
          \"com.cloudflare.api.account.zone.$ZONE_ID\": \"*\"
        },
        \"permission_groups\": [
          {
            \"id\": \"$PERM_ID\",
            \"name\": \"DNS Write\"
          }
        ]
      }
    ]
  }")

DNS_TOKEN=$(echo $DNS_TOKEN_RESPONSE | jq -r '.result.value')

if [ "$DNS_TOKEN" == "null" ] || [ -z "$DNS_TOKEN" ]; then
    echo "Failed to create DNS Token"
    echo $DNS_TOKEN_RESPONSE
    exit 1
fi

echo "DNS Token created."

echo "Setting GitHub Secrets..."
gh secret set CLOUDFLARE_ACCOUNT_ID --body "$ACCOUNT_ID"
gh secret set CLOUDFLARE_TUNNEL_TOKEN --body "$TUNNEL_TOKEN"
gh secret set CLOUDFLARE_DNS_TOKEN --body "$DNS_TOKEN"

echo "Secrets updated successfully."
