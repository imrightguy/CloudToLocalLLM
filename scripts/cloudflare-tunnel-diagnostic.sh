#!/bin/bash

# Cloudflare Tunnel Diagnostic and Restoration Script
# Version: 1.6.0 (Secure Refactor)
# Usage: CLOUDFLARE_API_KEY=xxx scripts/cloudflare-tunnel-diagnostic.sh

set -e

# Secure Configuration (Inject via Env)
CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL:-"cmaltais@cloudtolocalllm.online"}
DOMAIN=${CLOUDFLARE_DOMAIN:-"cloudtolocalllm.online"}
TUNNEL_ID=${CLOUDFLARE_TUNNEL_ID:-"62da6c19-947b-4bf6-acad-100a73de4e0d"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Security Check
if [ -z "$CLOUDFLARE_API_KEY" ]; then
    log_error "CLOUDFLARE_API_KEY environment variable is not set."
    exit 1
fi

# Function to make Cloudflare API calls
cf_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    curl -s -X "$method" "https://api.cloudflare.com/client/v4/$endpoint" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json" \
        ${data:+-d "$data"}
}

# Main execution
main() {
    log_info "Starting Secure Cloudflare Diagnostic for $DOMAIN"
    
    # 1. Fetch Account ID
    ACCOUNT_ID=$(cf_api_call "GET" "accounts" | jq -r '.result[0].id')
    if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" == "null" ]; then
        log_error "Failed to retrieve Account ID. Check your API key."
        exit 1
    fi
    log_success "Account ID: $ACCOUNT_ID"

    # 2. Check Tunnel Status
    TUNNEL_INFO=$(cf_api_call "GET" "accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID")
    TUNNEL_STATUS=$(echo "$TUNNEL_INFO" | jq -r '.result.status')
    log_info "Tunnel Status: $TUNNEL_STATUS"

    if [ "$TUNNEL_STATUS" != "healthy" ]; then
        log_warning "Tunnel is not healthy. Current status: $TUNNEL_STATUS"
    else
        log_success "Tunnel is reported healthy at the edge."
    fi

    # 3. Check Active Connectors
    CONNECTORS=$(cf_api_call "GET" "accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/connections" | jq -r '.result[] | .id')
    if [ -z "$CONNECTORS" ]; then
        log_error "No active connectors found. Error 1033 likely active at origin side."
    else
        log_success "Found active connectors."
    fi

    # 4. Verify CNAME Alignment
    ZONE_ID=$(cf_api_call "GET" "zones?name=$DOMAIN" | jq -r '.result[0].id')
    ENDPOINTS=("" "app" "api" "argocd" "grafana")
    for SUB in "${ENDPOINTS[@]}"; do
        FULL_NAME="${SUB:+$SUB.}$DOMAIN"
        RECORD=$(cf_api_call "GET" "zones/$ZONE_ID/dns_records?name=$FULL_NAME&type=CNAME" | jq -r '.result[0].content')
        if [[ "$RECORD" == *".cfargotunnel.com"* ]]; then
            log_success "$FULL_NAME -> $RECORD (Correct)"
        else
            log_warning "$FULL_NAME record is missing or misaligned: $RECORD"
        fi
    done

    log_success "Secure Diagnostic Complete."
}

main "$@"
