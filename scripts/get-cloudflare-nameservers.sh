#!/bin/bash

# Get Cloudflare nameservers for a domain
# This fetches the actual nameservers assigned to your Cloudflare zone

set -e

DOMAIN="cloudtolocalllm.online"

# Check if CLOUDFLARE_API_TOKEN is set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "âŒ Error: CLOUDFLARE_API_TOKEN environment variable is not set"
    echo "Please set it with: export CLOUDFLARE_API_TOKEN=your_token"
    exit 1
fi

CF_API_TOKEN="$CLOUDFLARE_API_TOKEN"

echo "ðŸ” Fetching Cloudflare nameservers for $DOMAIN..."
echo ""

# Get Zone ID
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

ZONE_COUNT=$(echo "$ZONE_RESPONSE" | jq -r '.result | length')

if [ "$ZONE_COUNT" -eq 0 ]; then
    echo "âŒ Error: Domain $DOMAIN not found in Cloudflare"
    exit 1
fi

CF_ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id')
NAMESERVERS=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].name_servers[]')

echo "âœ… Zone ID: $CF_ZONE_ID"
echo ""

# Display nameservers
if [ -n "$NAMESERVERS" ]; then
    echo "Cloudflare Nameservers for $DOMAIN:"
    echo ""
    echo "$NAMESERVERS" | while read ns; do
        echo "  â€¢ $ns"
    done
    echo ""
    echo "ðŸ“‹ Add these nameservers at your domain registrar (Namecheap):"
    echo "   1. Go to: https://www.namecheap.com/myaccount/login.aspx"
    echo "   2. Domain List â†’ $DOMAIN â†’ Manage â†’ Nameservers"
    echo "   3. Select 'Custom DNS'"
    echo "   4. Enter the nameservers above"
    echo ""
    
    # Save to file for monitoring script
    echo "$NAMESERVERS" > cloudflare-nameservers.txt
    echo "âœ… Nameservers saved to: cloudflare-nameservers.txt"
    echo ""
    echo "You can now run: ./scripts/monitor-nameservers.sh"
else
    echo "âš ï¸  Warning: Could not retrieve nameservers from Cloudflare API"
    echo "Using default Cloudflare nameserver pattern..."
    echo ""
    echo "Cloudflare typically uses nameservers like:"
    echo "  â€¢ kip.ns.cloudflare.com"
    echo "  â€¢ lewis.ns.cloudflare.com"
    echo ""
    echo "Check your Cloudflare dashboard for the actual nameservers:"
    echo "  https://dash.cloudflare.com â†’ $DOMAIN â†’ Overview â†’ Nameservers"
fi

