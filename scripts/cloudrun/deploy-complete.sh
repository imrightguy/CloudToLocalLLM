#!/bin/bash

# CloudToLocalLLM - Complete Cloud Run Deployment Script
# This script performs a complete deployment including environment setup,
# database migration, service deployment, and post-deployment configuration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/cloudrun/.env.cloudrun"

# Default values
SKIP_SETUP=false
SKIP_BUILD=false
SKIP_DEPLOY=false
SKIP_CONFIG=false
VERBOSE=false
DRY_RUN=false

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

# Help function
show_help() {
    cat << EOF
CloudToLocalLLM - Complete Cloud Run Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --skip-setup        Skip initial environment setup
    --skip-build        Skip container image building
    --skip-deploy       Skip service deployment
    --skip-config       Skip post-deployment configuration
    --verbose           Enable verbose output
    --dry-run           Show what would be done without executing
    --help, -h          Show this help message

EXAMPLES:
    $0                          # Complete deployment
    $0 --skip-setup             # Skip setup, deploy only
    $0 --dry-run                # Show deployment plan
    $0 --verbose                # Detailed output

PHASES:
    1. Environment Setup        Setup secrets, service accounts, databases
    2. Container Build          Build and push container images
    3. Service Deployment       Deploy services to Cloud Run
    4. Post-Deploy Config       Configure service URLs and environment

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-setup)
                SKIP_SETUP=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-deploy)
                SKIP_DEPLOY=true
                shift
                ;;
            --skip-config)
                SKIP_CONFIG=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Load environment configuration
load_env_config() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment configuration file not found: $ENV_FILE"
        log_error "Please copy and configure .env.cloudrun.template first"
        exit 1
    fi
    
    log_info "Loading environment configuration..."
    source "$ENV_FILE"
    
    # Validate required variables
    required_vars=(
        "GOOGLE_CLOUD_PROJECT"
        "GOOGLE_CLOUD_REGION"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Set gcloud project
    gcloud config set project "$GOOGLE_CLOUD_PROJECT"
    
    log_success "Environment configuration loaded"
}

# Phase 1: Environment Setup
phase_setup() {
    if [ "$SKIP_SETUP" = true ]; then
        log_info "Skipping environment setup phase"
        return
    fi
    
    log_header "=== Phase 1: Environment Setup ==="
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would run environment setup"
        return
    fi
    
    log_info "Running environment setup script..."
    if [ -f "$SCRIPT_DIR/setup-environment.sh" ]; then
        bash "$SCRIPT_DIR/setup-environment.sh"
    else
        log_warning "Environment setup script not found, skipping"
    fi
    
    log_success "Environment setup completed"
}

# Phase 2: Container Build
phase_build() {
    if [ "$SKIP_BUILD" = true ]; then
        log_info "Skipping container build phase"
        return
    fi
    
    log_header "=== Phase 2: Container Build ==="
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would build and push container images"
        return
    fi
    
    log_info "Building and pushing container images..."
    
    # Use the existing deployment script with build-only flag
    if [ "$VERBOSE" = true ]; then
        bash "$SCRIPT_DIR/deploy-to-cloudrun.sh" --build-only --verbose
    else
        bash "$SCRIPT_DIR/deploy-to-cloudrun.sh" --build-only
    fi
    
    log_success "Container build completed"
}

# Phase 3: Service Deployment
phase_deploy() {
    if [ "$SKIP_DEPLOY" = true ]; then
        log_info "Skipping service deployment phase"
        return
    fi
    
    log_header "=== Phase 3: Service Deployment ==="
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would deploy services to Cloud Run"
        return
    fi
    
    log_info "Deploying services to Cloud Run..."
    
    # Use the existing deployment script with deploy-only flag
    if [ "$VERBOSE" = true ]; then
        bash "$SCRIPT_DIR/deploy-to-cloudrun.sh" --deploy-only --verbose
    else
        bash "$SCRIPT_DIR/deploy-to-cloudrun.sh" --deploy-only
    fi
    
    log_success "Service deployment completed"
}

# Phase 4: Post-Deployment Configuration
phase_config() {
    if [ "$SKIP_CONFIG" = true ]; then
        log_info "Skipping post-deployment configuration phase"
        return
    fi
    
    log_header "=== Phase 4: Post-Deployment Configuration ==="
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would configure service URLs and environment"
        return
    fi
    
    log_info "Configuring service URLs and environment..."
    
    # Get service URLs
    local web_url=$(gcloud run services describe CloudToLocalLLM-web --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    local api_url=$(gcloud run services describe cloudtolocalllm-api --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    local streaming_url=$(gcloud run services describe CloudToLocalLLM-streaming --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    
    # Update services with cross-service URLs
    if [ -n "$api_url" ] && [ -n "$web_url" ]; then
        log_info "Updating API service with CORS configuration..."
        gcloud run services update cloudtolocalllm-api \
            --platform=managed \
            --region="$GOOGLE_CLOUD_REGION" \
            --set-env-vars="CORS_ORIGINS=$web_url" \
            --quiet
    fi
    
    if [ -n "$streaming_url" ] && [ -n "$api_url" ]; then
        log_info "Updating streaming service with API URL..."
        gcloud run services update CloudToLocalLLM-streaming \
            --platform=managed \
            --region="$GOOGLE_CLOUD_REGION" \
            --set-env-vars="OLLAMA_BASE_URL=$api_url" \
            --quiet
    fi
    
    # Create service URLs configuration file
    local config_file="$PROJECT_ROOT/config/cloudrun/service-urls.json"
    cat > "$config_file" << EOF
{
  "services": {
    "web": {
      "name": "CloudToLocalLLM-web",
      "url": "$web_url",
      "description": "Flutter web application"
    },
    "api": {
      "name": "cloudtolocalllm-api", 
      "url": "$api_url",
      "description": "Node.js API backend"
    },
    "streaming": {
      "name": "CloudToLocalLLM-streaming",
      "url": "$streaming_url", 
      "description": "WebSocket streaming proxy"
    }
  },
  "endpoints": {
    "health": {
      "web": "$web_url/health",
      "api": "$api_url/health",
      "streaming": "$streaming_url/health"
    },
    "api": {
      "base": "$api_url/api",
      "auth": "$api_url/api/auth",
      "models": "$api_url/api/models"
    }
  },
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_success "Post-deployment configuration completed"
    log_info "Service URLs saved to: $config_file"
}

# Health check all services
health_check() {
    log_header "=== Health Check ==="
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would perform health checks"
        return
    fi
    
    log_info "Performing health checks..."
    
    if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
        bash "$SCRIPT_DIR/health-check.sh" --format table
    else
        log_warning "Health check script not found"
    fi
}

# Display deployment summary
show_summary() {
    log_header "=== Deployment Summary ==="
    
    # Get service URLs
    local web_url=$(gcloud run services describe CloudToLocalLLM-web --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    local api_url=$(gcloud run services describe cloudtolocalllm-api --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    local streaming_url=$(gcloud run services describe CloudToLocalLLM-streaming --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    
    echo
    log_info "CloudToLocalLLM Cloud Run Deployment Complete!"
    echo
    echo "Service URLs:"
    echo "  Web Application: $web_url"
    echo "  API Backend:     $api_url"
    echo "  Streaming Proxy: $streaming_url"
    echo
    echo "Next Steps:"
    echo "1. Test the web application: $web_url"
    echo "2. Verify API health: $api_url/health"
    echo "3. Check streaming health: $streaming_url/health"
    echo "4. Configure custom domains (optional)"
    echo "5. Set up monitoring and alerting"
    echo
    echo "Documentation:"
    echo "  Deployment Guide: docs/DEPLOYMENT/CLOUDRUN_DEPLOYMENT.md"
    echo "  Service URLs: config/cloudrun/service-urls.json"
    echo
}

# Main deployment function
main() {
    parse_args "$@"
    
    log_header "=== CloudToLocalLLM Complete Cloud Run Deployment ==="
    log_info "Starting complete deployment process..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    load_env_config
    
    # Execute deployment phases
    phase_setup
    phase_build
    phase_deploy
    phase_config
    
    # Perform health checks
    health_check
    
    # Show summary
    show_summary
    
    log_success "Complete Cloud Run deployment finished successfully!"
}

# Run main function with all arguments
main "$@"
