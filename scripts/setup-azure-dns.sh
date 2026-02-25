#!/bin/bash

# Setup Azure DNS for CloudToLocalLLM
# This script creates an Azure DNS zone and all required DNS records

set -e

# Configuration
RESOURCE_GROUP="CloudToLocalLLM-rg"
DNS_ZONE_NAME="cloudtolocalllm.online"
AKS_CLUSTER_NAME="CloudToLocalLLM-aks"
TTL=300

# DNS records to create
declare -a DOMAINS=(
    "cloudtolocalllm.online"
    "app.cloudtolocalllm.online"
    "api.cloudtolocalllm.online"
    "auth.cloudtolocalllm.online"
)

echo "ðŸ”§ Setting up Azure DNS for $DNS_ZONE_NAME..."
echo ""

# Step 1: Get AKS credentials
echo "ðŸ“‹ Step 1: Getting AKS credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

# Step 2: Get Load Balancer IP
echo ""
echo "ðŸ“‹ Step 2: Getting Load Balancer IP..."
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$LB_IP" ]; then
    echo "âŒ Error: Could not retrieve Load Balancer IP"
    echo "Please ensure the ingress-nginx controller is deployed and has an external IP"
    exit 1
fi

echo "âœ… Load Balancer IP: $LB_IP"
echo ""

# Step 3: Create Azure DNS zone (if it doesn't exist)
echo "ðŸ“‹ Step 3: Creating Azure DNS zone..."
if az network dns zone show --resource-group "$RESOURCE_GROUP" --name "$DNS_ZONE_NAME" &>/dev/null; then
    echo "âœ… DNS zone already exists"
else
    echo "Creating DNS zone..."
    az network dns zone create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$DNS_ZONE_NAME"
    echo "âœ… DNS zone created"
fi
echo ""

# Step 4: Get nameservers
echo "ðŸ“‹ Step 4: Getting nameservers..."
NAMESERVERS=$(az network dns zone show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DNS_ZONE_NAME" \
  --query "nameServers" -o tsv)

echo "Azure DNS Nameservers:"
echo "$NAMESERVERS" | while read ns; do
    echo "  - $ns"
done
echo ""

# Step 5: Create DNS records
echo "ðŸ“‹ Step 5: Creating DNS records..."

for domain in "${DOMAINS[@]}"; do
    # Extract subdomain name
    if [ "$domain" = "cloudtolocalllm.online" ]; then
        record_name="@"
    else
        record_name=$(echo "$domain" | sed 's/\.CloudToLocalLLM\.online//')
    fi
    
    echo "Creating/updating: $domain â†’ $LB_IP"
    
    # Check if record exists
    if az network dns record-set a show \
      --resource-group "$RESOURCE_GROUP" \
      --zone-name "$DNS_ZONE_NAME" \
      --name "$record_name" &>/dev/null; then
        # Update existing record
        az network dns record-set a update \
          --resource-group "$RESOURCE_GROUP" \
          --zone-name "$DNS_ZONE_NAME" \
          --name "$record_name" \
          --set "aRecords[0].ipv4Address=$LB_IP" "ttl=$TTL" >/dev/null
        echo "  âœ… Updated"
    else
        # Create new record
        az network dns record-set a create \
          --resource-group "$RESOURCE_GROUP" \
          --zone-name "$DNS_ZONE_NAME" \
          --name "$record_name" \
          --ttl "$TTL" >/dev/null
        
        az network dns record-set a add-record \
          --resource-group "$RESOURCE_GROUP" \
          --zone-name "$DNS_ZONE_NAME" \
          --record-set-name "$record_name" \
          --ipv4-address "$LB_IP" >/dev/null
        echo "  âœ… Created"
    fi
done

echo ""

# Step 6: List all records
echo "ðŸ“‹ Step 6: Current DNS records in Azure DNS:"
echo ""
az network dns record-set list \
  --resource-group "$RESOURCE_GROUP" \
  --zone-name "$DNS_ZONE_NAME" \
  --output table

echo ""
echo "âœ… Azure DNS setup complete!"
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ“ NEXT STEPS - Configure Namecheap:"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""
echo "1. Go to Namecheap Dashboard â†’ Domain List â†’ Manage"
echo "2. Go to 'Nameservers' section"
echo "3. Select 'Custom DNS'"
echo "4. Enter these nameservers:"
echo ""
echo "$NAMESERVERS" | while read ns; do
    echo "   $ns"
done
echo ""
echo "5. Click 'Save'"
echo ""
echo "âš ï¸  DNS propagation can take 5 minutes to 48 hours (usually 5-15 minutes)"
echo ""
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "ðŸ“Š DNS Records Summary:"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""
for domain in "${DOMAINS[@]}"; do
    echo "  $domain â†’ $LB_IP (TTL: ${TTL}s)"
done
echo ""

