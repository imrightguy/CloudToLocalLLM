#!/bin/bash

# CloudToLocalLLM - Google Cloud Run Initial Setup Script
# This script sets up the Google Cloud environment for deploying CloudToLocalLLM to Cloud Run
# 
# Prerequisites:
# - Google Cloud SDK (gcloud) installed and authenticated
# - Docker installed (for local testing)
# - Appropriate IAM permissions in your Google Cloud project
#
# Usage: ./setup-cloudrun.sh [PROJECT_ID] [REGION]

set -euo pipefail

# Configuration
DEFAULT_REGION="us-central1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
CloudToLocalLLM - Google Cloud Run Setup Script

USAGE:
    $0 [PROJECT_ID] [REGION]

ARGUMENTS:
    PROJECT_ID    Google Cloud Project ID (optional, will prompt if not provided)
    REGION        Google Cloud region (default: $DEFAULT_REGION)

EXAMPLES:
    $0                                    # Interactive setup
    $0 my-project-id                      # Setup with project ID
    $0 my-project-id us-west1             # Setup with project ID and region

PREREQUISITES:
    - Google Cloud SDK installed and authenticated
    - Docker installed for local testing
    - Appropriate IAM permissions in your Google Cloud project

REQUIRED PERMISSIONS:
    - Cloud Run Admin
    - Service Account Admin
    - IAM Admin
    - Cloud Build Editor
    - Artifact Registry Admin

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud SDK (gcloud) is not installed."
        log_error "Please install it from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed. You'll need it for local testing."
        log_warning "Install from: https://docs.docker.com/get-docker/"
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "You are not authenticated with Google Cloud."
        log_error "Please run: gcloud auth login"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Get project ID
get_project_id() {
    if [ $# -ge 1 ] && [ -n "$1" ]; then
        PROJECT_ID="$1"
    else
        # Try to get current project
        CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
        
        if [ -n "$CURRENT_PROJECT" ]; then
            read -p "Use current project '$CURRENT_PROJECT'? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                PROJECT_ID="$CURRENT_PROJECT"
            else
                read -p "Enter Google Cloud Project ID: " PROJECT_ID
            fi
        else
            read -p "Enter Google Cloud Project ID: " PROJECT_ID
        fi
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "Project ID is required"
        exit 1
    fi
    
    log_info "Using project: $PROJECT_ID"
}

# Get region
get_region() {
    if [ $# -ge 2 ] && [ -n "$2" ]; then
        REGION="$2"
    else
        read -p "Enter region (default: $DEFAULT_REGION): " REGION
        REGION=${REGION:-$DEFAULT_REGION}
    fi
    
    log_info "Using region: $REGION"
}

# Set up Google Cloud project
setup_project() {
    log_info "Setting up Google Cloud project..."
    
    # Set the project
    gcloud config set project "$PROJECT_ID"
    
    # Enable required APIs
    log_info "Enabling required APIs..."
    gcloud services enable \
        cloudbuild.googleapis.com \
        run.googleapis.com \
        artifactregistry.googleapis.com \
        iam.googleapis.com \
        cloudresourcemanager.googleapis.com
    
    log_success "APIs enabled successfully"
}

# Create Artifact Registry repository
setup_artifact_registry() {
    log_info "Setting up Artifact Registry..."
    
    REPO_NAME="CloudToLocalLLM"
    
    # Check if repository already exists
    if gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" &>/dev/null; then
        log_warning "Artifact Registry repository '$REPO_NAME' already exists"
    else
        log_info "Creating Artifact Registry repository..."
        gcloud artifacts repositories create "$REPO_NAME" \
            --repository-format=docker \
            --location="$REGION" \
            --description="CloudToLocalLLM container images"
        
        log_success "Artifact Registry repository created"
    fi
    
    # Configure Docker authentication
    log_info "Configuring Docker authentication..."
    gcloud auth configure-docker "$REGION-docker.pkg.dev"
    
    log_success "Artifact Registry setup completed"
}

# Create service accounts
setup_service_accounts() {
    log_info "Setting up service accounts..."
    
    # Cloud Run service account
    SA_NAME="CloudToLocalLLM-runner"
    SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
    
    if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
        log_warning "Service account '$SA_NAME' already exists"
    else
        log_info "Creating Cloud Run service account..."
        gcloud iam service-accounts create "$SA_NAME" \
            --display-name="CloudToLocalLLM Cloud Run Service Account" \
            --description="Service account for CloudToLocalLLM Cloud Run services"
        
        log_success "Service account created"
    fi
    
    # Grant necessary roles
    log_info "Granting IAM roles..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/run.invoker"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/cloudsql.client"
    
    log_success "Service accounts setup completed"
}

# Create environment configuration
create_env_config() {
    log_info "Creating environment configuration..."
    
    ENV_FILE="$PROJECT_ROOT/config/cloudrun/.env.cloudrun"
    
    cat > "$ENV_FILE" << EOF
# CloudToLocalLLM - Google Cloud Run Environment Configuration
# Generated on $(date)

# Google Cloud Configuration
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_REGION=$REGION

# Artifact Registry
ARTIFACT_REGISTRY_REPO=$REGION-docker.pkg.dev/$PROJECT_ID/CloudToLocalLLM

# Service Account
SERVICE_ACCOUNT_EMAIL=CloudToLocalLLM-runner@$PROJECT_ID.iam.gserviceaccount.com

# Cloud Run Service Names
WEB_SERVICE_NAME=CloudToLocalLLM-web
API_SERVICE_NAME=cloudtolocalllm-api
STREAMING_SERVICE_NAME=CloudToLocalLLM-streaming

# Application Configuration (customize as needed)
NODE_ENV=production
LOG_LEVEL=info

# JWT Configuration (set your values)
JWT_ISSUER_DOMAIN=your-jwt-domain.jwt.com
JWT_CLIENT_ID=your-jwt-client-id
JWT_CLIENT_SECRET=your-jwt-client-secret

# Database Configuration (if using Cloud SQL)
# DB_HOST=your-cloud-sql-instance
# DB_USER=your-db-user
# DB_PASSWORD=your-db-password
# DB_NAME=CloudToLocalLLM

EOF

    log_success "Environment configuration created at: $ENV_FILE"
    log_warning "Please review and update the configuration file with your specific values"
}

# Main setup function
main() {
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    log_info "Starting CloudToLocalLLM Google Cloud Run setup..."
    
    check_prerequisites
    get_project_id "$@"
    get_region "$@"
    
    setup_project
    setup_artifact_registry
    setup_service_accounts
    create_env_config
    
    log_success "Google Cloud Run setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review and update the environment configuration:"
    echo "   $PROJECT_ROOT/config/cloudrun/.env.cloudrun"
    echo
    echo "2. Deploy your application:"
    echo "   ./scripts/cloudrun/deploy-to-cloudrun.sh"
    echo
    echo "3. Test your deployment:"
    echo "   curl https://\$WEB_SERVICE_URL/health"
    echo
    log_info "For more information, see: docs/DEPLOYMENT/CLOUDRUN_DEPLOYMENT.md"
}

# Run main function with all arguments
main "$@"
