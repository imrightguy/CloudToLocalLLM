#!/bin/bash
EMAIL='cmaltais@cloudtolocalllm.online'
API_KEY='abc12d491e2bc24a60e9e276be8d5b1af62bf'
ZONE_ID='01bae6fa9d97d5e731a1fa6fc8e1f960'
TUNNEL_CNAME='62da6c19-947b-4bf6-acad-100a73de4e0d.cfargotunnel.com'

# Record IDs from the list
ARGOCD_ID="511c33837ff0c1ed534ac76e3719c232"
GRAFANA_ID="de90131dc557fbeba4b252532d621b1a"

echo "Deleting broken records..."
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$ARGOCD_ID" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY"
echo -e "\n"

curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$GRAFANA_ID" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY"
echo -e "\n"

echo "Re-creating ArgoCD CNAME..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"CNAME\",\"name\":\"argocd\",\"content\":\"$TUNNEL_CNAME\",\"proxied\":true}"
echo -e "\n"

echo "Re-creating Grafana CNAME..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"CNAME\",\"name\":\"grafana\",\"content\":\"$TUNNEL_CNAME\",\"proxied\":true}"
echo -e "\n"
