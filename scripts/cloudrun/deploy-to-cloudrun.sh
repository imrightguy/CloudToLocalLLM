#!/bin/bash

# CloudToLocalLLM - Google Cloud Run Deployment Script
# This script builds and deploys CloudToLocalLLM services to Google Cloud Run
#
# Prerequisites:
# - Run setup-cloudrun.sh first
# - Environment configuration file exists
# - Docker and gcloud CLI installed
#
# Usage: ./deploy-to-cloudrun.sh [OPTIONS]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/cloudrun/.env.cloudrun"

# Default values
BUILD_ONLY=false
DEPLOY_ONLY=false
SERVICE=""
VERBOSE=false
DRY_RUN=false

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

# Help function
show_help() {
    cat << EOF
CloudToLocalLLM - Google Cloud Run Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --build-only        Only build container images, don't deploy
    --deploy-only       Only deploy (assumes images are already built)
    --service SERVICE   Deploy only specific service (web|api|streaming|all)
    --verbose           Enable verbose output
    --dry-run           Show what would be done without executing
    --help, -h          Show this help message

EXAMPLES:
    $0                          # Build and deploy all services
    $0 --service web            # Deploy only web service
    $0 --build-only             # Only build container images
    $0 --deploy-only --service api  # Deploy only API service (skip build)
    $0 --dry-run                # Show deployment plan

SERVICES:
    web         Flutter web application
    api         Node.js API backend
    streaming   Streaming proxy service
    all         All services (default)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --deploy-only)
                DEPLOY_ONLY=true
                shift
                ;;
            --service)
                SERVICE="$2"
                shift 2
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
    
    # Set default service if not specified
    if [ -z "$SERVICE" ]; then
        SERVICE="all"
    fi
    
    # Validate service option
    if [[ ! "$SERVICE" =~ ^(web|api|streaming|all)$ ]]; then
        log_error "Invalid service: $SERVICE. Must be one of: web, api, streaming, all"
        exit 1
    fi
}

# Load environment configuration
load_env_config() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment configuration file not found: $ENV_FILE"
        log_error "Please run setup-cloudrun.sh first"
        exit 1
    fi
    
    log_info "Loading environment configuration..."
    source "$ENV_FILE"
    
    # Validate required variables
    required_vars=(
        "GOOGLE_CLOUD_PROJECT"
        "GOOGLE_CLOUD_REGION"
        "ARTIFACT_REGISTRY_REPO"
        "WEB_SERVICE_NAME"
        "API_SERVICE_NAME"
        "STREAMING_SERVICE_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_success "Environment configuration loaded"
}

# Build container image
build_image() {
    local service_name="$1"
    local dockerfile="$2"
    local image_tag="$3"
    
    log_info "Building $service_name image..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would build: docker build -f $dockerfile -t $image_tag ."
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        docker build -f "$dockerfile" -t "$image_tag" "$PROJECT_ROOT"
    else
        docker build -f "$dockerfile" -t "$image_tag" "$PROJECT_ROOT" > /dev/null
    fi
    
    log_success "$service_name image built: $image_tag"
}

# Push container image
push_image() {
    local image_tag="$1"
    
    log_info "Pushing image: $image_tag"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would push: docker push $image_tag"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        docker push "$image_tag"
    else
        docker push "$image_tag" > /dev/null
    fi
    
    log_success "Image pushed successfully"
}

# Deploy to Cloud Run
deploy_service() {
    local service_name="$1"
    local image_tag="$2"
    local port="$3"
    
    log_info "Deploying $service_name to Cloud Run..."
    
    local deploy_cmd=(
        gcloud run deploy "$service_name"
        --image "$image_tag"
        --platform managed
        --region "$GOOGLE_CLOUD_REGION"
        --allow-unauthenticated
        --port "$port"
        --memory 1Gi
        --cpu 1
        --min-instances 0
        --max-instances 10
        --concurrency 80
        --timeout 300
        --service-account "$SERVICE_ACCOUNT_EMAIL"
        --set-env-vars "NODE_ENV=production,LOG_LEVEL=info"
    )
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would deploy: ${deploy_cmd[*]}"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        "${deploy_cmd[@]}"
    else
        "${deploy_cmd[@]}" > /dev/null
    fi
    
    # Get service URL
    local service_url
    service_url=$(gcloud run services describe "$service_name" \
        --platform managed \
        --region "$GOOGLE_CLOUD_REGION" \
        --format 'value(status.url)')
    
    log_success "$service_name deployed successfully"
    log_info "Service URL: $service_url"
}

# Build and deploy web service
deploy_web() {
    local image_tag="$ARTIFACT_REGISTRY_REPO/web:latest"
    
    if [ "$DEPLOY_ONLY" = false ]; then
        build_image "web" "config/cloudrun/Dockerfile.web-cloudrun" "$image_tag"
        push_image "$image_tag"
    fi
    
    if [ "$BUILD_ONLY" = false ]; then
        deploy_service "$WEB_SERVICE_NAME" "$image_tag" "8080"
    fi
}

# Build and deploy API service
deploy_api() {
    local image_tag="$ARTIFACT_REGISTRY_REPO/api:latest"
    
    if [ "$DEPLOY_ONLY" = false ]; then
        build_image "api" "config/cloudrun/Dockerfile.api-cloudrun" "$image_tag"
        push_image "$image_tag"
    fi
    
    if [ "$BUILD_ONLY" = false ]; then
        deploy_service "$API_SERVICE_NAME" "$image_tag" "8080"
    fi
}

# Build and deploy streaming service
deploy_streaming() {
    local image_tag="$ARTIFACT_REGISTRY_REPO/streaming:latest"
    
    if [ "$DEPLOY_ONLY" = false ]; then
        build_image "streaming" "config/cloudrun/Dockerfile.streaming-proxy-cloudrun" "$image_tag"
        push_image "$image_tag"
    fi
    
    if [ "$BUILD_ONLY" = false ]; then
        deploy_service "$STREAMING_SERVICE_NAME" "$image_tag" "8080"
    fi
}

# Main deployment function
main() {
    parse_args "$@"
    
    log_info "Starting CloudToLocalLLM deployment to Google Cloud Run..."
    log_info "Service: $SERVICE"
    log_info "Build only: $BUILD_ONLY"
    log_info "Deploy only: $DEPLOY_ONLY"
    log_info "Dry run: $DRY_RUN"
    
    load_env_config
    
    # Set gcloud project
    gcloud config set project "$GOOGLE_CLOUD_PROJECT"
    
    # Deploy services based on selection
    case "$SERVICE" in
        web)
            deploy_web
            ;;
        api)
            deploy_api
            ;;
        streaming)
            deploy_streaming
            ;;
        all)
            deploy_web
            deploy_api
            deploy_streaming
            ;;
    esac
    
    if [ "$DRY_RUN" = false ] && [ "$BUILD_ONLY" = false ]; then
        log_success "Deployment completed successfully!"
        echo
        log_info "Service URLs:"
        gcloud run services list --platform managed --region "$GOOGLE_CLOUD_REGION" --format="table(metadata.name,status.url)"
    fi
}

# Run main function with all arguments
main "$@"
