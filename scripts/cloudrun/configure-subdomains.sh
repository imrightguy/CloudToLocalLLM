#!/bin/bash

# CloudToLocalLLM - Subdomain Configuration Script
# This script configures all subdomains and updates service configurations
# for production deployment with custom domains

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/cloudrun/subdomain-config.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_header() {
    echo -e "${CYAN}$1${NC}"
}

# Load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Loading subdomain configuration..."
    
    # Extract domains from config
    MAIN_DOMAIN=$(jq -r '.production.domains.main' "$CONFIG_FILE")
    APP_DOMAIN=$(jq -r '.production.domains.app' "$CONFIG_FILE")
    API_DOMAIN=$(jq -r '.production.domains.api' "$CONFIG_FILE")
    STREAMING_DOMAIN=$(jq -r '.production.domains.streaming' "$CONFIG_FILE")
    
    log_success "Configuration loaded"
    log_info "  Main: $MAIN_DOMAIN"
    log_info "  App: $APP_DOMAIN"
    log_info "  API: $API_DOMAIN"
    log_info "  Streaming: $STREAMING_DOMAIN"
}

# Check domain mappings
check_domain_mappings() {
    log_header "=== Checking Domain Mappings ==="
    
    local domains=("$APP_DOMAIN" "$API_DOMAIN" "$STREAMING_DOMAIN")
    local services=("CloudToLocalLLM-web" "cloudtolocalllm-api" "CloudToLocalLLM-streaming")
    
    for i in "${!domains[@]}"; do
        local domain="${domains[$i]}"
        local service="${services[$i]}"
        
        log_info "Checking domain mapping: $domain → $service"
        
        if gcloud beta run domain-mappings describe --domain "$domain" --region us-east4 &>/dev/null; then
            log_success "Domain mapping exists: $domain"
        else
            log_warning "Creating domain mapping: $domain → $service"
            gcloud beta run domain-mappings create \
                --service "$service" \
                --domain "$domain" \
                --region us-east4
        fi
    done
}

# Update Cloud Run services with CORS configuration
update_service_cors() {
    log_header "=== Updating Service CORS Configuration ==="
    
    local cors_origins="https://$MAIN_DOMAIN,https://$APP_DOMAIN,https://$API_DOMAIN,https://$STREAMING_DOMAIN"
    
    log_info "Updating API service CORS..."
    gcloud run services update cloudtolocalllm-api \
        --platform=managed \
        --region=us-east4 \
        --set-env-vars="CORS_ORIGINS=$cors_origins" \
        --quiet
    
    log_info "Updating streaming service configuration..."
    gcloud run services update CloudToLocalLLM-streaming \
        --platform=managed \
        --region=us-east4 \
        --set-env-vars="OLLAMA_BASE_URL=https://$API_DOMAIN" \
        --quiet
    
    log_success "Service CORS configuration updated"
}

# Generate DNS records
generate_dns_records() {
    log_header "=== DNS Records Configuration ==="
    
    local dns_file="$PROJECT_ROOT/config/cloudrun/dns-records.txt"
    
    cat > "$dns_file" << EOF
# CloudToLocalLLM DNS Records Configuration
# Add these CNAME records to your domain registrar

# Main domain (redirects to app)
cloudtolocalllm.online.     CNAME   ghs.googlehosted.com.

# Application frontend
app.cloudtolocalllm.online.     CNAME   ghs.googlehosted.com.

# API backend
api.cloudtolocalllm.online.     CNAME   ghs.googlehosted.com.

# Streaming service
streaming.cloudtolocalllm.online.     CNAME   ghs.googlehosted.com.

# Instructions:
# 1. Log into your domain registrar's DNS management panel
# 2. Add each CNAME record exactly as shown above
# 3. Wait for DNS propagation (usually 5-60 minutes)
# 4. Verify with: dig CNAME <subdomain>

# SSL certificates will be automatically provisioned by Google Cloud Run
# once the DNS records are properly configured.
EOF
    
    log_success "DNS records configuration saved to: $dns_file"
    
    echo
    log_info "DNS Records to configure in your domain registrar:"
    echo "┌─────────────────────────────────────┬──────┬─────────────────────────┐"
    echo "│ Name                                │ Type │ Value                   │"
    echo "├─────────────────────────────────────┼──────┼─────────────────────────┤"
    echo "│ cloudtolocalllm.online              │ CNAME│ ghs.googlehosted.com.   │"
    echo "│ app.cloudtolocalllm.online          │ CNAME│ ghs.googlehosted.com.   │"
    echo "│ api.cloudtolocalllm.online          │ CNAME│ ghs.googlehosted.com.   │"
    echo "│ streaming.cloudtolocalllm.online    │ CNAME│ ghs.googlehosted.com.   │"
    echo "└─────────────────────────────────────┴──────┴─────────────────────────┘"
}

# Test subdomain connectivity
test_subdomains() {
    log_header "=== Testing Subdomain Connectivity ==="
    
    local domains=("$APP_DOMAIN" "$API_DOMAIN" "$STREAMING_DOMAIN")
    local endpoints=("/health" "/health" "/health")
    
    for i in "${!domains[@]}"; do
        local domain="${domains[$i]}"
        local endpoint="${endpoints[$i]}"
        local url="https://$domain$endpoint"
        
        log_info "Testing: $url"
        
        if curl -s -f --max-time 10 "$url" > /dev/null 2>&1; then
            log_success "✓ $domain is responding"
        else
            log_warning "✗ $domain is not responding (may need DNS propagation)"
        fi
    done
}

# Create web app configuration with subdomains
create_web_config() {
    log_header "=== Creating Web App Configuration ==="
    
    local web_config_file="$PROJECT_ROOT/web/subdomain-config.js"
    
    cat > "$web_config_file" << EOF
// CloudToLocalLLM - Production Subdomain Configuration
// This file configures the Flutter web app to use production subdomains

window.cloudToLocalLLMConfig = {
  environment: 'production',
  
  // Production subdomain URLs
  services: {
    api: {
      baseUrl: 'https://$API_DOMAIN',
      endpoints: {
        health: '/health',
        auth: '/api/auth',
        models: '/api/models',
        chat: '/api/chat',
        streaming: '/api/streaming',
        tunnel: '/api/tunnel',
        bridge: '/api/bridge'
      }
    },
    streaming: {
      baseUrl: 'https://$STREAMING_DOMAIN',
      endpoints: {
        health: '/health',
        proxy: '/proxy',
        websocket: '/ws'
      }
    }
  },
  
  // CORS configuration
  cors: {
    credentials: 'include',
    mode: 'cors'
  },
  
  // Feature flags
  features: {
    localOllama: false,
    tunneling: true,
    streaming: true,
    auth: true,
    monitoring: true
  },
  
  // API configuration
  api: {
    timeout: 30000,
    retries: 3,
    retryDelay: 1000
  }
};

console.log('CloudToLocalLLM: Production subdomain configuration loaded');
console.log('API URL:', window.cloudToLocalLLMConfig.services.api.baseUrl);
console.log('Streaming URL:', window.cloudToLocalLLMConfig.services.streaming.baseUrl);
EOF
    
    log_success "Web app configuration created: $web_config_file"
}

# Main function
main() {
    log_header "=== CloudToLocalLLM Subdomain Configuration ==="
    log_info "Configuring production subdomains for CloudToLocalLLM..."
    
    load_config
    check_domain_mappings
    update_service_cors
    generate_dns_records
    create_web_config
    test_subdomains
    
    echo
    log_success "Subdomain configuration completed!"
    echo
    log_info "Next steps:"
    echo "1. Configure DNS records in your domain registrar (see dns-records.txt)"
    echo "2. Wait for DNS propagation (5-60 minutes)"
    echo "3. Test the subdomains:"
    echo "   - App: https://$APP_DOMAIN"
    echo "   - API: https://$API_DOMAIN/health"
    echo "   - Streaming: https://$STREAMING_DOMAIN/health"
    echo "4. SSL certificates will be automatically provisioned"
    echo
    log_info "Configuration files created:"
    echo "  - config/cloudrun/subdomain-config.json"
    echo "  - config/cloudrun/dns-records.txt"
    echo "  - web/subdomain-config.js"
}

# Run main function
main "$@"
