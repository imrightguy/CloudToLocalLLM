#!/bin/bash

# Cloudflare DNS Repair Script
# Version: 1.6.0 (Secure Refactor)
# Usage: CLOUDFLARE_API_KEY=xxx scripts/cloudflare-dns-repair.sh

set -e

# Secure Configuration (Inject via Env)
CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL:-"cmaltais@cloudtolocalllm.online"}
DOMAIN=${CLOUDFLARE_DOMAIN:-"cloudtolocalllm.online"}
TUNNEL_ID=${CLOUDFLARE_TUNNEL_ID:-"62da6c19-947b-4bf6-acad-100a73de4e0d"}
TARGET_CNAME="$TUNNEL_ID.cfargotunnel.com"

# Logging functions
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# Mandatory Env Check
if [ -z "$CLOUDFLARE_API_KEY" ]; then
    log_error "CLOUDFLARE_API_KEY environment variable is mandatory."
    exit 1
fi

cf_api_call() {
    curl -s -X "$1" "https://api.cloudflare.com/client/v4/$2" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json" \
        ${3:+-d "$3"}
}

main() {
    log_info "Starting Secure DNS Repair for $DOMAIN"
    
    # 1. Resolve Zone ID
    ZONE_ID=$(cf_api_call "GET" "zones?name=$DOMAIN" | jq -r '.result[0].id')
    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
        log_error "Could not find Zone ID for $DOMAIN."
        exit 1
    fi
    log_info "Zone ID: $ZONE_ID"

    # 2. Repair CNAME alignment
    ENDPOINTS=("" "app" "api" "argocd" "grafana")
    for SUB in "${ENDPOINTS[@]}"; do
        FULL_NAME="${SUB:+$SUB.}$DOMAIN"
        log_info "Verifying $FULL_NAME..."
        
        # Check current record
        CURRENT_RECORD=$(cf_api_call "GET" "zones/$ZONE_ID/dns_records?name=$FULL_NAME&type=CNAME")
        RECORD_ID=$(echo "$CURRENT_RECORD" | jq -r '.result[0].id')
        CONTENT=$(echo "$CURRENT_RECORD" | jq -r '.result[0].content')

        if [ "$CONTENT" == "$TARGET_CNAME" ]; then
            log_success "$FULL_NAME is already aligned with $TARGET_CNAME."
            continue
        fi

        if [ "$RECORD_ID" != "null" ]; then
            log_info "Realigning $FULL_NAME (ID: $RECORD_ID) to $TARGET_CNAME..."
            cf_api_call "PUT" "zones/$ZONE_ID/dns_records/$RECORD_ID" \
                '{"type":"CNAME","name":"'"$FULL_NAME"'","content":"'"$TARGET_CNAME"'","proxied":true,"ttl":1}' | jq -r '.success'
        else
            log_info "Creating new record for $FULL_NAME pointing to $TARGET_CNAME..."
            cf_api_call "POST" "zones/$ZONE_ID/dns_records" \
                '{"type":"CNAME","name":"'"$FULL_NAME"'","content":"'"$TARGET_CNAME"'","proxied":true,"ttl":1}' | jq -r '.success'
        fi
    done
    
    log_success "DNS Stack Integrity Restored."
}

main "$@"
