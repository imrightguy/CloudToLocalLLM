#!/bin/bash
# CloudToLocalLLM ArgoCD Deployment Standard Operating Procedure
# Comprehensive deployment workflow with validation and monitoring
# Usage: ./deployment-sop.sh <environment> <application> [options]

set -e

# Configuration
ENVIRONMENT=""
APPLICATION=""
DRY_RUN=false
SKIP_VALIDATION=false
SKIP_BACKUP=false
SKIP_MONITORING=false

# ArgoCD Configuration
ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="CloudToLocalLLM"
LOG_FILE="/var/log/deployment-sop.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$DATE]${NC} $1" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $LOG_FILE
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a $LOG_FILE
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a $LOG_FILE
}

# Function to validate prerequisites
validate_prerequisites() {
    log "=== Validating Prerequisites ==="
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if argocd CLI is available
    if ! command -v argocd &> /dev/null; then
        error "argocd CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check ArgoCD connection
    if ! argocd version --client &> /dev/null; then
        error "Cannot connect to ArgoCD server"
        exit 1
    fi
    
    # Check if environment is valid
    case $ENVIRONMENT in
        "production"|"staging"|"development"|"local"|"managed")
            success "Environment: $ENVIRONMENT"
            ;;
        *)
            error "Invalid environment: $ENVIRONMENT"
            error "Valid environments: production, staging, development, local, managed"
            exit 1
            ;;
    esac
    
    # Check if application is valid
    case $APPLICATION in
        "api-backend"|"web-frontend"|"postgres"|"redis"|"monitoring"|"infrastructure"|"utilities"|"ingress")
            success "Application: $APPLICATION"
            ;;
        *)
            error "Invalid application: $APPLICATION"
            error "Valid applications: api-backend, web-frontend, postgres, redis, monitoring, infrastructure, utilities, ingress"
            exit 1
            ;;
    esac
    
    success "Prerequisites validated"
}

# Function to run pre-deployment validation
run_pre_deployment_validation() {
    if [ "$SKIP_VALIDATION" = true ]; then
        warning "Skipping pre-deployment validation"
        return 0
    fi
    
    log "=== Running Pre-deployment Validation ==="
    
    # Run health check
    if [ -f "./scripts/argocd-health-check.sh" ]; then
        log "Running ArgoCD health check..."
        if ! ./scripts/argocd-health-check.sh --critical; then
            error "ArgoCD health check failed"
            exit 1
        fi
    else
        warning "ArgoCD health check script not found, skipping"
    fi
    
    # Validate Kubernetes manifests
    log "Validating Kubernetes manifests..."
    local manifest_path="k8s/apps/$ENVIRONMENT/$APPLICATION"
    
    if [ -d "$manifest_path" ]; then
        find $manifest_path -name "*.yaml" -o -name "*.yml" | while read file; do
            if ! kubectl apply --dry-run=client -f "$file" 2>/dev/null; then
                error "Invalid manifest: $file"
                exit 1
            fi
        done
        success "Kubernetes manifests validated"
    else
        warning "Manifest path not found: $manifest_path"
    fi
    
    # Check resource limits
    log "Checking resource limits..."
    local node_count=$(kubectl get nodes --no-headers | wc -l)
    local pod_count=$(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE --no-headers | wc -l)
    
    log "Cluster nodes: $node_count"
    log "CloudToLocalLLM pods: $pod_count"
    
    if [ $node_count -eq 0 ]; then
        error "No nodes available in cluster"
        exit 1
    fi
    
    success "Pre-deployment validation completed"
}

# Function to create backup
create_backup() {
    if [ "$SKIP_BACKUP" = true ]; then
        warning "Skipping backup creation"
        return 0
    fi
    
    log "=== Creating Backup ==="
    
    if [ -f "./scripts/argocd-backup-restore.sh" ]; then
        log "Creating ArgoCD backup..."
        ./scripts/argocd-backup-restore.sh backup --type applications,applicationsets,appprojects
        success "Backup created successfully"
    else
        warning "Backup script not found, skipping backup"
    fi
}

# Function to pause critical applications
pause_critical_applications() {
    log "=== Pausing Critical Applications ==="
    
    local critical_apps=("api-backend" "web-frontend")
    
    for app in "${critical_apps[@]}"; do
        local full_app_name="CloudToLocalLLM-$app"
        
        if argocd app get $full_app_name &> /dev/null; then
            log "Pausing application: $full_app_name"
            argocd app pause $full_app_name
            success "Application $full_app_name paused"
        else
            warning "Application $full_app_name not found, skipping"
        fi
    done
}

# Function to deploy application
deploy_application() {
    log "=== Deploying Application ==="
    
    local full_app_name="CloudToLocalLLM-$APPLICATION"
    
    if ! argocd app get $full_app_name &> /dev/null; then
        error "Application $full_app_name not found"
        exit 1
    fi
    
    log "Syncing application: $full_app_name"
    
    # Perform sync with retry logic
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if argocd app sync $full_app_name --force; then
            success "Application sync initiated successfully"
            break
        else
            retry_count=$((retry_count + 1))
            warning "Sync attempt $retry_count failed, retrying in 30 seconds..."
            sleep 30
        fi
    done
    
    if [ $retry_count -eq $max_retries ]; then
        error "Failed to sync application after $max_retries attempts"
        exit 1
    fi
    
    # Wait for sync completion
    log "Waiting for sync completion..."
    if ! argocd app wait $full_app_name --timeout 600; then
        error "Application sync timed out"
        exit 1
    fi
    
    success "Application deployed successfully"
}

# Function to verify deployment
verify_deployment() {
    log "=== Verifying Deployment ==="
    
    local full_app_name="CloudToLocalLLM-$APPLICATION"
    
    # Get application status
    local app_status=$(argocd app get $full_app_name --output json | jq -r '.status.sync.status')
    local app_health=$(argocd app get $full_app_name --output json | jq -r '.status.health.status')
    
    log "Application status: $app_status"
    log "Application health: $app_health"
    
    if [ "$app_status" != "Synced" ] || [ "$app_health" != "Healthy" ]; then
        error "Application is not healthy after deployment"
        error "Status: $app_status, Health: $app_health"
        exit 1
    fi
    
    # Run smoke tests if available
    if [ -f "./scripts/smoke-tests.sh" ]; then
        log "Running smoke tests..."
        if ! ./scripts/smoke-tests.sh; then
            error "Smoke tests failed"
            exit 1
        fi
    else
        warning "Smoke tests script not found, skipping"
    fi
    
    success "Deployment verification completed"
}

# Function to resume applications
resume_applications() {
    log "=== Resuming Applications ==="
    
    local critical_apps=("api-backend" "web-frontend")
    
    for app in "${critical_apps[@]}"; do
        local full_app_name="CloudToLocalLLM-$app"
        
        if argocd app get $full_app_name &> /dev/null; then
            log "Resuming application: $full_app_name"
            argocd app resume $full_app_name
            success "Application $full_app_name resumed"
        else
            warning "Application $full_app_name not found, skipping"
        fi
    done
}

# Function to start monitoring
start_monitoring() {
    if [ "$SKIP_MONITORING" = true ]; then
        warning "Skipping post-deployment monitoring"
        return 0
    fi
    
    log "=== Starting Post-deployment Monitoring ==="
    
    # Run health check
    if [ -f "./scripts/argocd-health-check.sh" ]; then
        log "Running post-deployment health check..."
        if ! ./scripts/argocd-health-check.sh; then
            warning "Post-deployment health check failed"
        else
            success "Post-deployment health check passed"
        fi
    fi
    
    # Monitor for 5 minutes
    log "Monitoring deployment for 5 minutes..."
    for i in {1..5}; do
        sleep 60
        log "Monitoring minute $i/5..."
        
        # Check application status
        local full_app_name="CloudToLocalLLM-$APPLICATION"
        local app_status=$(argocd app get $full_app_name --output json | jq -r '.status.sync.status' 2>/dev/null || echo "Unknown")
        local app_health=$(argocd app get $full_app_name --output json | jq -r '.status.health.status' 2>/dev/null || echo "Unknown")
        
        if [ "$app_status" != "Synced" ] || [ "$app_health" != "Healthy" ]; then
            warning "Application status changed: $app_status, Health: $app_health"
        fi
    done
    
    success "Post-deployment monitoring completed"
}

# Function to generate deployment report
generate_deployment_report() {
    local report_file="/tmp/deployment-report-$(date +%Y%m%d_%H%M%S).json"
    
    log "=== Generating Deployment Report ==="
    
    cat > $report_file << EOF
{
  "deployment": {
    "timestamp": "$DATE",
    "environment": "$ENVIRONMENT",
    "application": "$APPLICATION",
    "status": "completed",
    "dry_run": $DRY_RUN,
    "validation_skipped": $SKIP_VALIDATION,
    "backup_skipped": $SKIP_BACKUP,
    "monitoring_skipped": $SKIP_MONITORING
  },
  "applications": $(argocd app list --output json),
  "cluster_info": {
    "nodes": $(kubectl get nodes --no-headers | wc -l),
    "cloudtolocalllm_pods": $(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE --no-headers | wc -l)
  }
}
EOF
    
    success "Deployment report generated: $report_file"
    cat $report_file | jq '.' | tee -a $LOG_FILE
}

# Function to handle deployment failure
handle_deployment_failure() {
    local error_message=$1
    
    error "Deployment failed: $error_message"
    
    # Attempt rollback if backup exists
    if [ -f "./scripts/rollback-argocd-app.sh" ]; then
        log "Attempting rollback..."
        ./scripts/rollback-argocd-app.sh -a "CloudToLocalLLM-$APPLICATION" --emergency
    fi
    
    exit 1
}

# Function to display deployment summary
display_summary() {
    log "=== Deployment Summary ==="
    log "Environment: $ENVIRONMENT"
    log "Application: $APPLICATION"
    log "Status: SUCCESS"
    log "Timestamp: $DATE"
    log "Log file: $LOG_FILE"
    
    success "Deployment completed successfully!"
}

# Main execution function
main() {
    log "=== CloudToLocalLLM ArgoCD Deployment SOP Started ==="
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -a|--application)
                APPLICATION="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --skip-monitoring)
                SKIP_MONITORING=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  -e, --environment <env>     Environment (production, staging, development, local, managed)"
                echo "  -a, --application <app>     Application to deploy (api-backend, web-frontend, postgres, redis, monitoring, infrastructure, utilities, ingress)"
                echo "  --dry-run                   Simulate deployment without making changes"
                echo "  --skip-validation           Skip pre-deployment validation"
                echo "  --skip-backup               Skip backup creation"
                echo "  --skip-monitoring           Skip post-deployment monitoring"
                echo "  --help                      Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    echo "=== CloudToLocalLLM ArgoCD Deployment SOP Started at $DATE ===" > $LOG_FILE
    
    # Validate required parameters
    if [ -z "$ENVIRONMENT" ] || [ -z "$APPLICATION" ]; then
        error "Environment and application are required"
        echo "Usage: $0 -e <environment> -a <application> [options]"
        exit 1
    fi
    
    # Handle dry run
    if [ "$DRY_RUN" = true ]; then
        warning "DRY RUN MODE - No actual changes will be made"
        log "Environment: $ENVIRONMENT"
        log "Application: $APPLICATION"
        log "Dry run completed successfully"
        exit 0
    fi
    
    # Execute deployment steps
    trap 'handle_deployment_failure "Script interrupted"' ERR
    
    validate_prerequisites
    run_pre_deployment_validation
    create_backup
    pause_critical_applications
    deploy_application
    verify_deployment
    resume_applications
    start_monitoring
    generate_deployment_report
    display_summary
    
    success "Deployment SOP completed successfully"
}

# Run main function with all arguments
main "$@"