#!/bin/bash

#######################################################################
# CloudToLocalLLM - DigitalOcean DNS Setup Script
# 
# This script automates DNS configuration for DigitalOcean DNS
#######################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="cloudtolocalllm.online"
SUBDOMAINS=("app" "api" "auth")
TTL=300

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CloudToLocalLLM - DigitalOcean DNS Setup                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

#######################################################################
# Step 1: Check Prerequisites
#######################################################################

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if doctl is installed
if ! command -v doctl &> /dev/null; then
    echo -e "${RED}✗ doctl CLI not found${NC}"
    echo "Install it from: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi
echo -e "${GREEN}✓ doctl CLI found${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    echo "Install it from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

# Check doctl authentication
if ! doctl account get &> /dev/null; then
    echo -e "${RED}✗ doctl not authenticated${NC}"
    echo "Run: doctl auth init"
    exit 1
fi
echo -e "${GREEN}✓ doctl authenticated${NC}"

echo ""

#######################################################################
# Step 2: Get Load Balancer IP
#######################################################################

echo -e "${YELLOW}Step 2: Getting Load Balancer IP...${NC}"

# Check if ingress-nginx is deployed
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo -e "${RED}✗ ingress-nginx namespace not found${NC}"
    echo "Deploy nginx-ingress first: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/do/deploy.yaml"
    exit 1
fi

# Wait for Load Balancer IP
echo "Waiting for Load Balancer IP (this may take a few minutes)..."
RETRIES=0
MAX_RETRIES=30

while [ $RETRIES -lt $MAX_RETRIES ]; do
    LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$LB_IP" ]; then
        echo -e "${GREEN}✓ Load Balancer IP: $LB_IP${NC}"
        break
    fi
    
    RETRIES=$((RETRIES + 1))
    echo "  Waiting for Load Balancer... ($RETRIES/$MAX_RETRIES)"
    sleep 10
done

if [ -z "$LB_IP" ]; then
    echo -e "${RED}✗ Failed to get Load Balancer IP after ${MAX_RETRIES}0 seconds${NC}"
    echo "Check ingress-nginx deployment: kubectl get svc -n ingress-nginx"
    exit 1
fi

echo ""

#######################################################################
# Step 3: Create or Verify DNS Zone
#######################################################################

echo -e "${YELLOW}Step 3: Setting up DNS zone...${NC}"

# Check if domain already exists
if doctl compute domain get $DOMAIN &> /dev/null; then
    echo -e "${YELLOW}⚠ Domain $DOMAIN already exists in DigitalOcean DNS${NC}"
    read -p "Do you want to add/update DNS records? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
else
    # Create domain
    echo "Creating DNS zone for $DOMAIN..."
    if doctl compute domain create $DOMAIN --ip-address $LB_IP; then
        echo -e "${GREEN}✓ DNS zone created${NC}"
    else
        echo -e "${RED}✗ Failed to create DNS zone${NC}"
        exit 1
    fi
fi

echo ""

#######################################################################
# Step 4: Create DNS Records
#######################################################################

echo -e "${YELLOW}Step 4: Creating DNS records...${NC}"

# Function to create or update DNS record
create_or_update_record() {
    local record_name=$1
    local record_data=$2
    
    # Check if record exists
    RECORD_ID=$(doctl compute domain records list $DOMAIN --format ID,Name,Type,Data --no-header | grep "^[0-9]* *${record_name} *A " | awk '{print $1}' || echo "")
    
    if [ -n "$RECORD_ID" ]; then
        # Update existing record
        echo "  Updating $record_name.$DOMAIN → $record_data"
        if doctl compute domain records update $DOMAIN --record-id $RECORD_ID --record-data $record_data; then
            echo -e "  ${GREEN}✓ Updated${NC}"
        else
            echo -e "  ${RED}✗ Failed to update${NC}"
            return 1
        fi
    else
        # Create new record
        echo "  Creating $record_name.$DOMAIN → $record_data"
        if doctl compute domain records create $DOMAIN --record-type A --record-name $record_name --record-data $record_data --record-ttl $TTL; then
            echo -e "  ${GREEN}✓ Created${NC}"
        else
            echo -e "  ${RED}✗ Failed to create${NC}"
            return 1
        fi
    fi
}

# Create root domain record (@)
create_or_update_record "@" "$LB_IP"

# Create subdomain records
for subdomain in "${SUBDOMAINS[@]}"; do
    create_or_update_record "$subdomain" "$LB_IP"
done

echo ""

#######################################################################
# Step 5: Display Results
#######################################################################

echo -e "${YELLOW}Step 5: Verifying DNS records...${NC}"

echo ""
echo "DNS Records created:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
doctl compute domain records list $DOMAIN --format Name,Type,Data,TTL
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo -e "${GREEN}✓ DNS setup complete!${NC}"
echo ""

#######################################################################
# Step 6: Instructions
#######################################################################

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}NEXT STEPS:${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Update nameservers at your domain registrar:"
echo "   ┌──────────────────────────────────┐"
echo "   │ ns1.digitalocean.com             │"
echo "   │ ns2.digitalocean.com             │"
echo "   │ ns3.digitalocean.com             │"
echo "   └──────────────────────────────────┘"
echo ""
echo "2. Wait for DNS propagation (5-15 minutes, up to 48 hours)"
echo ""
echo "3. Test DNS resolution:"
echo "   dig cloudtolocalllm.online +short"
echo "   dig app.cloudtolocalllm.online +short"
echo "   dig api.cloudtolocalllm.online +short"
echo "   dig auth.cloudtolocalllm.online +short"
echo ""
echo "4. Deploy CloudToLocalLLM to Kubernetes:"
echo "   cd k8s && ./deploy.sh"
echo ""
echo "5. Wait for SSL certificates (cert-manager will auto-provision)"
echo "   kubectl get certificate -n CloudToLocalLLM"
echo ""
echo "6. Test your deployment:"
echo "   https://cloudtolocalllm.online"
echo "   https://api.cloudtolocalllm.online/health"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ All done! Your DNS is configured.${NC}"
echo ""

