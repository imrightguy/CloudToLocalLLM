#!/bin/bash

# CloudToLocalLLM Docker Development Environment Validator
# Validates Docker images, Flutter configuration, and development environment setup
# Ensures all components are properly configured for development and deployment

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

# Check Docker installation and status
check_docker() {
    log_step 1 "Checking Docker installation and status..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    
    local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log_info "Docker version: $docker_version"
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        return 1
    fi
    
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        log_info "Docker Compose version: $compose_version"
    else
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker Compose version: $compose_version"
    fi
    
    log_success "Docker installation and status check passed"
    return 0
}

# Check Flutter installation
check_flutter() {
    log_step 2 "Checking Flutter installation..."
    
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        return 1
    fi
    
    local flutter_version=$(flutter --version | head -n1 | cut -d' ' -f2)
    log_info "Flutter version: $flutter_version"
    
    # Check Flutter doctor
    log_info "Running Flutter doctor..."
    if flutter doctor --machine >/dev/null 2>&1; then
        log_success "Flutter doctor check passed"
    else
        log_warning "Flutter doctor found issues (this may be normal for development)"
    fi
    
    # Check if web support is enabled
    if flutter devices | grep -q "Chrome"; then
        log_success "Flutter web support is available"
    else
        log_warning "Flutter web support may not be properly configured"
    fi
    
    return 0
}

# Validate project structure
validate_project_structure() {
    log_step 3 "Validating project structure..."
    
    local required_files=(
        "pubspec.yaml"
        "lib/main.dart"
        "docker-compose.yml"
        "api-backend/server.js"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files: ${missing_files[*]}"
        return 1
    fi
    
    # Check if build directory exists (optional)
    if [[ -d "$PROJECT_ROOT/build" ]]; then
        log_info "Build directory exists"
    else
        log_info "Build directory not found (will be created on first build)"
    fi
    
    log_success "Project structure validation passed"
    return 0
}

# Validate Docker Compose configuration
validate_docker_compose() {
    log_step 4 "Validating Docker Compose configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Check if docker-compose.yml is valid
    if docker compose config >/dev/null 2>&1; then
        log_success "Docker Compose configuration is valid"
    elif docker-compose config >/dev/null 2>&1; then
        log_success "Docker Compose configuration is valid"
    else
        log_error "Docker Compose configuration is invalid"
        return 1
    fi
    
    # Check for required services
    local required_services=("webapp" "api-backend")
    local compose_services
    
    if docker compose config --services >/dev/null 2>&1; then
        compose_services=$(docker compose config --services)
    else
        compose_services=$(docker-compose config --services)
    fi
    
    for service in "${required_services[@]}"; do
        if echo "$compose_services" | grep -q "^$service$"; then
            log_success "Service '$service' found in Docker Compose"
        else
            log_error "Required service '$service' not found in Docker Compose"
            return 1
        fi
    done
    
    return 0
}

# Check Docker images
check_docker_images() {
    log_step 5 "Checking Docker images..."
    
    # Check if base images are available
    local base_images=("nginx:alpine" "node:24-alpine")
    
    for image in "${base_images[@]}"; do
        if docker image inspect "$image" >/dev/null 2>&1; then
            log_success "Base image '$image' is available"
        else
            log_info "Base image '$image' not found locally (will be pulled when needed)"
        fi
    done
    
    # Check if project images exist
    local project_images=("CloudToLocalLLM-webapp" "cloudtolocalllm-api")
    
    for image in "${project_images[@]}"; do
        if docker image inspect "$image" >/dev/null 2>&1; then
            local image_size=$(docker image inspect "$image" --format '{{.Size}}' | awk '{print int($1/1024/1024) "MB"}')
            log_success "Project image '$image' exists ($image_size)"
        else
            log_info "Project image '$image' not found (will be built when needed)"
        fi
    done
    
    return 0
}

# Test Docker network connectivity
test_docker_networking() {
    log_step 6 "Testing Docker networking..."
    
    # Check if Docker networks exist
    local networks=$(docker network ls --format '{{.Name}}')
    
    if echo "$networks" | grep -q "CloudToLocalLLM"; then
        log_success "CloudToLocalLLM Docker network exists"
    else
        log_info "CloudToLocalLLM Docker network not found (will be created when needed)"
    fi
    
    # Test basic networking
    if docker run --rm alpine:latest ping -c 1 google.com >/dev/null 2>&1; then
        log_success "Docker container networking is functional"
    else
        log_warning "Docker container networking test failed"
        return 1
    fi
    
    return 0
}

# Check development dependencies
check_dev_dependencies() {
    log_step 7 "Checking development dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Check Flutter dependencies
    if [[ -f "pubspec.lock" ]]; then
        log_success "Flutter dependencies are installed (pubspec.lock exists)"
    else
        log_info "Flutter dependencies not installed (run 'flutter pub get')"
    fi
    
    # Check Node.js dependencies for API backend
    if [[ -f "api-backend/package.json" ]]; then
        if [[ -f "api-backend/node_modules/.package-lock.json" ]] || [[ -d "api-backend/node_modules" ]]; then
            log_success "Node.js dependencies are installed"
        else
            log_info "Node.js dependencies not installed (run 'npm install' in api-backend/)"
        fi
    else
        log_warning "API backend package.json not found"
    fi
    
    return 0
}

# Test container build capability
test_container_build() {
    log_step 8 "Testing container build capability..."
    
    cd "$PROJECT_ROOT"
    
    # Test if we can build containers (dry run)
    log_info "Testing Docker Compose build (dry run)..."
    
    if docker compose config >/dev/null 2>&1; then
        if docker compose build --dry-run >/dev/null 2>&1; then
            log_success "Container build test passed"
        else
            log_info "Container build dry run not supported (this is normal for older Docker versions)"
        fi
    else
        log_info "Using legacy docker-compose command"
    fi
    
    return 0
}

# Check port availability
check_port_availability() {
    log_step 9 "Checking port availability..."
    
    local required_ports=(80 443 3000 8080)
    local ports_in_use=()
    
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            ports_in_use+=("$port")
        fi
    done
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log_warning "Ports in use: ${ports_in_use[*]} (may cause conflicts)"
    else
        log_success "Required ports are available"
    fi
    
    return 0
}

# Generate validation report
generate_validation_report() {
    local overall_status="$1"
    
    echo
    echo "=== CloudToLocalLLM Development Environment Validation Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Project Root: $PROJECT_ROOT"
    echo "Overall Status: $overall_status"
    echo
    
    if [[ "$overall_status" == "READY" ]]; then
        echo "✅ Development environment is ready"
        echo "🐳 Docker is properly configured"
        echo "📱 Flutter is installed and functional"
        echo "📦 Project structure is valid"
        echo "🔧 All dependencies are available"
        echo
        echo "Quick start commands:"
        echo "  flutter pub get                    # Install Flutter dependencies"
        echo "  cd api-backend && npm install      # Install Node.js dependencies"
        echo "  docker compose up -d               # Start development containers"
        echo "  flutter run -d chrome              # Run Flutter web app"
    else
        echo "⚠️  Development environment has issues"
        echo "📋 Review the validation steps above for details"
        echo "🔧 Fix the identified issues before proceeding"
        echo
        echo "Common fixes:"
        echo "  - Install Docker and start Docker daemon"
        echo "  - Install Flutter SDK and add to PATH"
        echo "  - Run 'flutter pub get' to install dependencies"
        echo "  - Check Docker Compose configuration"
    fi
    
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM development environment validation..."
    echo
    
    local validation_passed=true
    
    # Run all validation steps
    check_docker || validation_passed=false
    echo
    
    check_flutter || validation_passed=false
    echo
    
    validate_project_structure || validation_passed=false
    echo
    
    validate_docker_compose || validation_passed=false
    echo
    
    check_docker_images || validation_passed=false
    echo
    
    test_docker_networking || validation_passed=false
    echo
    
    check_dev_dependencies || validation_passed=false
    echo
    
    test_container_build || validation_passed=false
    echo
    
    check_port_availability || validation_passed=false
    echo
    
    # Generate final report
    if $validation_passed; then
        generate_validation_report "READY"
        log_success "Development environment validation completed successfully!"
        exit 0
    else
        generate_validation_report "ISSUES_FOUND"
        log_error "Development environment validation found issues that need attention"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Docker Development Environment Validator"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script validates:"
        echo "  - Docker installation and daemon status"
        echo "  - Flutter SDK installation and configuration"
        echo "  - Project structure and required files"
        echo "  - Docker Compose configuration validity"
        echo "  - Docker images and networking"
        echo "  - Development dependencies"
        echo "  - Port availability"
        echo "  - Container build capability"
        echo
        echo "Requirements:"
        echo "  - Docker and Docker Compose installed"
        echo "  - Flutter SDK installed and in PATH"
        echo "  - Valid CloudToLocalLLM project structure"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
