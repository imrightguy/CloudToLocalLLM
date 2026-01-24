#!/bin/bash
set -e

# Cloudflare Cache Purge Script
# This script purges Cloudflare cache for all domains after deployment
# Usage:
#   export CLOUDFLARE_API_TOKEN="your_api_token"
#   export CLOUDFLARE_ZONE_ID="your_zone_id" (optional)
#   export CLOUDFLARE_EMAIL="your_email" (optional, for Global API Key)
#   ./scripts/cloudflare-cache-purge.sh

# Configuration
DOMAIN="cloudtolocalllm.online"
SUBDOMAINS=("app" "api" "docs" "mail")
MAX_RETRIES=3
RETRY_DELAY=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Global headers array
AUTH_HEADERS=()

# Validate environment
validate_env() {
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        log_error "CLOUDFLARE_API_TOKEN not set"
        echo "Please set the CLOUDFLARE_API_TOKEN environment variable."
        echo "If using Global API Key, also set CLOUDFLARE_EMAIL."
        exit 1
    fi

    # Trim whitespace and remove 'Bearer ' prefix if present
    CLOUDFLARE_API_TOKEN="$(echo "${CLOUDFLARE_API_TOKEN}" | sed 's/^Bearer //i' | tr -d '[:space:]')"
    
    if [ -n "$CLOUDFLARE_EMAIL" ]; then
        CLOUDFLARE_EMAIL="$(echo "${CLOUDFLARE_EMAIL}" | tr -d '[:space:]')"
    fi

    log_info "Environment validation passed"
    log_info "Token length: ${#CLOUDFLARE_API_TOKEN}"

    # Setup Auth Headers
    AUTH_HEADERS=("-H" "Content-Type: application/json")
    if [ -n "$CLOUDFLARE_EMAIL" ]; then
        log_info "Using Global API Key authentication (Email: $CLOUDFLARE_EMAIL)"
        AUTH_HEADERS+=("-H" "X-Auth-Email: ${CLOUDFLARE_EMAIL}")
        AUTH_HEADERS+=("-H" "X-Auth-Key: ${CLOUDFLARE_API_TOKEN}")
        
        # Verify Global Key (using /user endpoint)
        log_info "Verifying Global API Key..."
        TEST_URL="https://api.cloudflare.com/client/v4/user"
    else
        log_info "Using API Token authentication"
        AUTH_HEADERS+=("-H" "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
        
        # Verify Token
        log_info "Verifying API Token..."
        TEST_URL="https://api.cloudflare.com/client/v4/user/tokens/verify"
    fi
    
    local test_response
    test_response=$(curl -s -X GET "$TEST_URL" "${AUTH_HEADERS[@]}")
    
    if echo "$test_response" | grep -q '"success":true'; then
        log_success "Authentication valid"
    else
        log_error "Authentication failed"
        echo "Response: $test_response"
        exit 1
    fi
}

# Get Zone ID
get_zone_id() {
    local zone_name="$1"

    if [ -n "$CLOUDFLARE_ZONE_ID" ]; then
        log_info "Using provided Zone ID: $CLOUDFLARE_ZONE_ID" >&2
        echo "$CLOUDFLARE_ZONE_ID"
        return 0
    fi

    log_info "Fetching Zone ID for domain: $zone_name" >&2

    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
        "${AUTH_HEADERS[@]}")

    if echo "$response" | grep -qE '"success"[[:space:]]*:[[:space:]]*true'; then
        local zone_id
        zone_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$zone_id" ]; then
            log_success "Zone ID retrieved: $zone_id" >&2
            echo "$zone_id"
            return 0
        fi
    fi

    log_error "Failed to retrieve Zone ID" >&2
    echo "Response: $response" >&2
    return 1
}

# Purge cache with retry logic
purge_cache() {
    local zone_id="$1"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Cache purge attempt $attempt/$MAX_RETRIES for zone: $zone_id"

        local response
        local http_code
        local curl_exit_code
        
        # Make the API call and capture both response and HTTP status
        local temp_file=$(mktemp)
        local temp_headers=$(mktemp)
        
        log_info "Executing purge request..."
        
        # Execute curl with better error handling
        set +e  # Don't exit on curl failure
        http_code=$(curl -s -w "%{http_code}" -X POST \
            "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
            "${AUTH_HEADERS[@]}" \
            --data '{"purge_everything": true}' \
            --dump-header "$temp_headers" \
            -o "$temp_file" 2>&1)
        curl_exit_code=$?
        set -e  # Re-enable exit on error
        
        # Read response body
        response=$(cat "$temp_file" 2>/dev/null || echo "")
        
        log_info "Curl exit code: $curl_exit_code"
        log_info "HTTP Status: $http_code"
        
        # Show response headers for debugging
        if [ -f "$temp_headers" ]; then
            log_info "Response headers:"
            cat "$temp_headers" | head -10
        fi
        
        # Clean up temp files
        rm -f "$temp_file" "$temp_headers"
        
        # Check curl exit code first
        if [ $curl_exit_code -ne 0 ]; then
            log_error "Curl command failed with exit code $curl_exit_code"
            log_error "This usually indicates a network, DNS, or connection issue"
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
            ((attempt++))
            continue
        fi

        if echo "$response" | grep -qE '"success"[[:space:]]*:[[:space:]]*true'; then
            log_success "Cache purge successful for zone $zone_id"
            return 0
        else
            log_warning "Cache purge attempt $attempt failed"
            echo "Response: $response"
            
            # Check for specific error patterns
            if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
                log_error "Authentication failed (HTTP $http_code) - check permissions"
                break
            elif [ "$http_code" = "400" ]; then
                log_error "Bad request (HTTP $http_code) - check API parameters"
                break
            elif [ "$http_code" = "429" ]; then
                log_warning "Rate limited (HTTP $http_code) - will retry"
            elif echo "$response" | grep -q '"code":10000'; then
                log_error "Authentication failed"
                break
            elif echo "$response" | grep -q '"code":6003'; then
                log_error "Invalid zone ID or insufficient permissions"
                break
            elif [ -z "$response" ] && [ -z "$http_code" ]; then
                log_error "No response from Cloudflare API - possible network issue"
            elif [ -z "$response" ]; then
                log_error "Empty response body with HTTP $http_code"
            fi

            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi

        ((attempt++))
    done

    # If purge_everything failed, try selective URL purging as fallback
    log_warning "Purge everything failed, trying selective URL purging..."
    if purge_selective_urls "$zone_id"; then
        return 0
    fi

    log_error "Cache purge failed after $MAX_RETRIES attempts"
    return 1
}

# Fallback: purge specific URLs instead of everything
purge_selective_urls() {
    local zone_id="$1"
    local urls=()
    
    # Build list of URLs to purge
    urls+=("https://$DOMAIN")
    urls+=("https://$DOMAIN/")
    for subdomain in "${SUBDOMAINS[@]}"; do
        urls+=("https://$subdomain.$DOMAIN")
        urls+=("https://$subdomain.$DOMAIN/")
    done
    
    log_info "Attempting selective URL purging for ${#urls[@]} URLs"
    
    # Create JSON payload with URLs
    local url_list=""
    for url in "${urls[@]}"; do
        if [ -n "$url_list" ]; then
            url_list="$url_list,"
        fi
        url_list="$url_list\"$url\""
    done
    
    local payload="{\"files\":[$url_list]}"
    log_info "Purging URLs: $url_list"
    
    local response
    local temp_file=$(mktemp)
    local http_code
    
    http_code=$(curl -s -w "%{http_code}" -X POST \
        "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
        "${AUTH_HEADERS[@]}" \
        --data "$payload" \
        -o "$temp_file")
    
    response=$(cat "$temp_file")
    rm -f "$temp_file"
    
    log_info "Selective purge HTTP Status: $http_code"
    
    if echo "$response" | grep -qE '"success"[[:space:]]*:[[:space:]]*true'; then
        log_success "Selective URL purge successful"
        return 0
    else
        log_warning "Selective URL purge also failed"
        echo "Response: $response"
        return 1
    fi
}

# Verify cache purge by checking response headers
verify_cache_purge() {
    local domain="$1"
    local url="https://$domain"

    log_info "Verifying cache purge for: $url"

    # Make a request and check for cache headers
    local response
    response=$(curl -s -I "$url" 2>/dev/null || echo "")

    if [ -z "$response" ]; then
        log_warning "Could not reach $url for verification"
        return 0
    fi

    # Check if CF-Cache-Status indicates cache was purged
    if echo "$response" | grep -q "CF-Cache-Status: MISS\|CF-Cache-Status: EXPIRED"; then
        log_success "Cache verification successful for $domain (cache miss/expired)"
        return 0
    elif echo "$response" | grep -q "CF-Cache-Status: HIT"; then
        log_warning "Cache still serving cached content for $domain"
        return 1
    else
        log_info "Cache status unknown for $domain (may not be cached)"
        return 0
    fi
}

# Main execution
main() {
    echo "â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” "
    echo "Cloudflare Cache Purge for CloudToLocalLLM"
    echo "â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” â” "
    echo ""

    # Validate environment
    validate_env

    # Get Zone ID
    local zone_id
    if ! zone_id=$(get_zone_id "$DOMAIN"); then
        exit 1
    fi

    # Purge cache
    if ! purge_cache "$zone_id"; then
        log_error "Cache purge failed - deployment may continue but users might see cached content"
        exit 1
    fi

    echo ""
    log_info "Cache purge completed. Affected domains:"
    echo "  - $DOMAIN"
    for subdomain in "${SUBDOMAINS[@]}"; do
        echo "  - $subdomain.$DOMAIN"
    done

    echo ""
    log_info "Verifying cache purge effectiveness..."

    # Verify main domain
    verify_cache_purge "$DOMAIN"

    # Verify subdomains
    for subdomain in "${SUBDOMAINS[@]}"; do
        verify_cache_purge "$subdomain.$DOMAIN"
    done

    echo ""
    log_success "Cloudflare cache purge process completed"
    log_info "Users should now receive the latest deployed version"
    log_info "Note: DNS propagation and cache invalidation may take a few minutes globally"
}

# Run main function
main "$@"
