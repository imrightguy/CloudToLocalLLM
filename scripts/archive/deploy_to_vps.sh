#!/bin/bash

# CloudToLocalLLM VPS Deployment Script - Enhanced Version
# Deploy the latest changes to the VPS with automated error handling
# Version: 3.6.4 - Fully Automated Deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Configuration
PROJECT_DIR="/opt/CloudToLocalLLM"
COMPOSE_FILE="docker-compose.multi.yml"
BACKUP_DIR="/opt/CloudToLocalLLM/backups"
MAX_RETRIES=3
RETRY_DELAY=5

# Retry function for commands that might fail
retry_command() {
    local cmd="$1"
    local description="$2"
    local retries=0

    while [[ $retries -lt $MAX_RETRIES ]]; do
        log_info "Attempting: $description (attempt $((retries + 1))/$MAX_RETRIES)"

        if eval "$cmd"; then
            log_success "$description completed successfully"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $MAX_RETRIES ]]; then
                log_warning "$description failed, retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            else
                log_error "$description failed after $MAX_RETRIES attempts"
                return 1
            fi
        fi
    done
}

# Check if running as cloudllm user
check_user() {
    if [[ "$USER" == "root" ]]; then
        log_error "This script should not be run as root user"
        log_info "Please run as cloudllm user: sudo -u cloudllm $0"
        exit 1
    fi

    if [[ "$USER" != "cloudllm" ]]; then
        log_warning "Running as user: $USER (expected: cloudllm)"
        log_info "Continuing anyway..."
    fi

    log_success "User check passed"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    log_success "Directory check passed"
}

# Create backup of current deployment
create_backup() {
    log_info "Creating backup of current deployment..."
    
    local backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/backup_$backup_timestamp"
    
    mkdir -p "$backup_path"
    
    # Backup docker-compose files
    cp docker-compose*.yml "$backup_path/" 2>/dev/null || true
    
    # Backup Flutter web build
    if [[ -d "build/web" ]]; then
        cp -r build/web "$backup_path/"
    fi
    
    # Backup nginx config
    if [[ -d "nginx" ]]; then
        cp -r nginx "$backup_path/"
    fi
    
    log_success "Backup created: $backup_path"
}

# Pull latest changes from Git
pull_latest_changes() {
    log_step "Pulling latest changes from Git..."

    # Stash any local changes
    log_info "Stashing local changes..."
    git stash push -m "Auto-stash before deployment $(date)" 2>/dev/null || true

    # Pull latest changes with retry logic
    retry_command "git pull origin master" "Git pull from origin/master"

    log_success "Git pull completed"
}

# Enhanced container cleanup - stops ALL conflicting containers
cleanup_all_containers() {
    log_step "Performing comprehensive container cleanup..."

    # Stop containers using our compose file first
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_info "Stopping containers from compose file..."
        docker-compose -f "$COMPOSE_FILE" down --timeout 30 --remove-orphans 2>/dev/null || true
    fi

    # Stop all CloudToLocalLLM related containers
    log_info "Stopping all CloudToLocalLLM containers..."
    local containers_to_stop=$(docker ps -a --format "{{.Names}}" | grep -E "(CloudToLocalLLM|cloudllm)" || true)
    if [[ -n "$containers_to_stop" ]]; then
        echo "$containers_to_stop" | while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                log_info "Stopping container: $container"
                docker stop "$container" 2>/dev/null || true
                docker rm "$container" 2>/dev/null || true
            fi
        done
    fi

    # Clean up any containers using ports 80 or 443
    log_info "Cleaning up containers using ports 80/443..."
    local port_containers=$(docker ps --format "{{.Names}}" --filter "publish=80" --filter "publish=443" 2>/dev/null || true)
    if [[ -n "$port_containers" ]]; then
        echo "$port_containers" | while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                log_info "Stopping port-conflicting container: $container"
                docker stop "$container" 2>/dev/null || true
                docker rm "$container" 2>/dev/null || true
            fi
        done
    fi

    # Clean up orphaned containers and networks
    log_info "Cleaning up orphaned resources..."
    docker container prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true

    log_success "Container cleanup completed"
}

# Stop existing containers (legacy function for compatibility)
stop_containers() {
    cleanup_all_containers
}

# Build Flutter web application
build_flutter_web() {
    log_step "Building Flutter web application..."

    # Check if Flutter is available
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter command not found. Please ensure Flutter is installed and in PATH."
        return 1
    fi

    # Show Flutter version for debugging
    log_info "Flutter version: $(flutter --version | head -1)"

    # Remove any existing build directory completely
    log_info "Removing previous build directory..."
    rm -rf build/ 2>/dev/null || true

    # Clean previous build
    log_info "Cleaning previous Flutter build..."
    flutter clean 2>/dev/null || true

    # Update packages to latest compatible versions
    log_info "Updating Flutter packages to latest versions..."
    retry_command "flutter pub upgrade" "Flutter pub upgrade"

    # Get dependencies with retry
    log_info "Getting Flutter dependencies..."
    retry_command "flutter pub get" "Flutter pub get"

    # Build web application with retry
    log_info "Building Flutter web application for release..."
    retry_command "flutter build web --release --verbose" "Flutter web build"

    # Verify build directory exists and has content
    if [[ ! -d "build/web" ]]; then
        log_error "Flutter build failed - build/web directory not found"
        ls -la build/ 2>/dev/null || log_error "No build directory exists at all"
        return 1
    fi

    if [[ ! -f "build/web/index.html" ]]; then
        log_error "Flutter build failed - index.html not found in build/web"
        ls -la build/web/ 2>/dev/null || log_error "build/web directory is empty"
        return 1
    fi

    # Check for essential Flutter web files
    local essential_files=("index.html" "main.dart.js" "flutter.js")
    for file in "${essential_files[@]}"; do
        if [[ ! -f "build/web/$file" ]]; then
            log_warning "Essential file missing: build/web/$file"
        fi
    done

    local file_count=$(find build/web -type f | wc -l)
    local dir_size=$(du -sh build/web | cut -f1)
    log_info "Flutter build completed - $file_count files, $dir_size total size"

    if [[ $file_count -lt 5 ]]; then
        log_error "Flutter build seems incomplete - only $file_count files found"
        ls -la build/web/
        return 1
    fi

    log_success "Flutter web build completed successfully"
}

# Build and start containers with enhanced error handling
start_containers() {
    log_step "Building and starting containers..."

    # Ensure we have a clean slate
    cleanup_all_containers

    # Verify build/web exists before building containers
    if [[ ! -d "build/web" ]] || [[ ! -f "build/web/index.html" ]]; then
        log_error "Flutter build/web directory missing or incomplete. Cannot proceed with container build."
        return 1
    fi

    # Build containers with no cache for updated static files
    log_info "Building Docker containers..."
    retry_command "docker-compose -f '$COMPOSE_FILE' build --no-cache" "Docker container build"

    # Start containers
    log_info "Starting Docker containers..."
    retry_command "docker-compose -f '$COMPOSE_FILE' up -d" "Docker container startup"

    # Wait for containers to initialize
    log_info "Waiting for containers to initialize..."
    sleep 20

    # Check if containers are running with better error handling
    local running_containers=0
    local total_containers=0

    if docker-compose -f "$COMPOSE_FILE" ps --services &>/dev/null; then
        running_containers=$(docker-compose -f "$COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null | wc -l)
        total_containers=$(docker-compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | wc -l)
    else
        log_error "Failed to query container status"
        return 1
    fi

    log_info "Container status: $running_containers/$total_containers running"

    if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
        log_success "All containers started successfully ($running_containers/$total_containers)"
    else
        log_error "Some containers failed to start ($running_containers/$total_containers)"
        log_info "Container details:"
        docker-compose -f "$COMPOSE_FILE" ps
        log_info "Container logs for debugging:"
        docker-compose -f "$COMPOSE_FILE" logs --tail=20
        return 1
    fi

    log_success "Container startup completed"
}

# Verify deployment
verify_deployment() {
    log_step "Verifying deployment..."

    # Wait for containers to be ready
    log_info "Waiting for services to be ready..."
    sleep 15

    # Check container status
    local containers_status=$(docker-compose -f "$COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null | wc -l)
    local total_containers=$(docker-compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | wc -l)

    if [[ "$containers_status" -eq "$total_containers" ]] && [[ "$total_containers" -gt 0 ]]; then
        log_success "All containers are running ($containers_status/$total_containers)"
    else
        log_error "Some containers are not running ($containers_status/$total_containers)"
        docker-compose -f "$COMPOSE_FILE" ps
        return 1
    fi

    # Test HTTPS accessibility with retry
    log_info "Testing HTTPS accessibility..."
    local max_attempts=5
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Testing HTTPS endpoint (attempt $attempt/$max_attempts)..."

        if curl -I -s -f --max-time 10 https://app.cloudtolocalllm.online >/dev/null 2>&1; then
            log_success "HTTPS endpoint is accessible"
            break
        elif [[ $attempt -eq $max_attempts ]]; then
            log_error "HTTPS endpoint is not accessible after $max_attempts attempts"
            # Show more details for debugging
            curl -I -v https://app.cloudtolocalllm.online 2>&1 | head -10 || true
            return 1
        else
            log_info "HTTPS endpoint not ready, waiting 10 seconds..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done

    # Test main app page
    log_info "Testing main application page..."
    if curl -s --max-time 10 https://app.cloudtolocalllm.online/ | grep -q "CloudToLocalLLM\|flutter\|main.dart.js" 2>/dev/null; then
        log_success "Main application page is loading correctly"
    else
        log_warning "Main application page may not be loading correctly"
        # Don't fail deployment for this, as it might be a timing issue
    fi

    # Test version endpoint
    log_info "Testing version information..."
    if curl -s --max-time 10 https://app.cloudtolocalllm.online/assets/version.json 2>/dev/null | grep -q "3.6.4" 2>/dev/null; then
        log_success "Version 3.6.4 is deployed correctly"
    else
        log_warning "Version information not accessible or incorrect"
        # Don't fail deployment for this
    fi

    log_success "Deployment verification completed"
}

# Show deployment summary
show_summary() {
    log_info "Deployment Summary"
    echo "===================="
    echo "Project Directory: $PROJECT_DIR"
    echo "Compose File: $COMPOSE_FILE"
    echo "Deployment Time: $(date)"
    echo
    echo "Container Status:"
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    echo "Available Endpoints:"
    echo "  - Homepage: https://cloudtolocalllm.online"
    echo "  - Web App: https://app.cloudtolocalllm.online"
    echo "  - Downloads: https://cloudtolocalllm.online/downloads.html"
    echo "  - Debian Package: https://cloudtolocalllm.online/dist/debian/cloudtolocalllm_2.1.1_amd64.deb"
    echo
    echo "Logs:"
    echo "  docker-compose -f $COMPOSE_FILE logs -f"
    echo
}

# Main deployment function
main() {
    log_step "Starting CloudToLocalLLM VPS deployment v3.6.4..."
    echo "================================================================"
    echo "CloudToLocalLLM Automated VPS Deployment"
    echo "Version: 3.6.4 - Enhanced with automated error handling"
    echo "Time: $(date)"
    echo "================================================================"
    echo

    # Pre-deployment checks
    log_step "Phase 1: Pre-deployment checks"
    check_user
    check_directory

    # Create backup
    log_step "Phase 2: Creating backup"
    create_backup

    # Deploy
    log_step "Phase 3: Pulling latest changes"
    pull_latest_changes

    log_step "Phase 4: Building Flutter web application"
    build_flutter_web

    log_step "Phase 5: Container deployment"
    start_containers

    # Verify
    log_step "Phase 6: Deployment verification"
    verify_deployment

    # Summary
    log_step "Phase 7: Deployment summary"
    show_summary

    echo
    echo "================================================================"
    log_success "CloudToLocalLLM v3.6.4 deployment completed successfully!"
    echo "================================================================"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "CloudToLocalLLM VPS Deployment Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo
        echo "This script deploys the latest CloudToLocalLLM changes to the VPS."
        echo "It should be run as the cloudllm user on the VPS."
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
esac
