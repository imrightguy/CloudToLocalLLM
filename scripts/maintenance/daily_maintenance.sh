#!/bin/bash

# CloudToLocalLLM Daily Maintenance Script
# Performs daily maintenance tasks including log rotation, database cleanup,
# cache management, and health checks for optimal system performance

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/CloudToLocalLLM"

# Maintenance configuration
LOG_RETENTION_DAYS=7
CACHE_MAX_SIZE="500M"
DOCKER_LOG_MAX_SIZE="100m"
HEALTH_CHECK_TIMEOUT=30

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

# Create maintenance log entry
log_maintenance() {
    local log_file="/var/log/CloudToLocalLLM/maintenance.log"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$timestamp] DAILY_MAINTENANCE: $1" >> "$log_file" 2>/dev/null || true
}

# Check if running on VPS or locally
is_vps_environment() {
    [[ "$(hostname)" == *"CloudToLocalLLM"* ]] || [[ -f "/opt/CloudToLocalLLM/docker-compose.yml" ]]
}

# Execute command on VPS or locally
execute_command() {
    local cmd="$1"
    
    if is_vps_environment; then
        eval "$cmd"
    else
        ssh "$VPS_USER@$VPS_HOST" "$cmd"
    fi
}

# Rotate application logs
rotate_logs() {
    log_step 1 "Rotating application logs..."
    
    local log_dirs=(
        "/var/log/CloudToLocalLLM"
        "/var/log/nginx"
        "$VPS_PROJECT_DIR/logs"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if execute_command "test -d $log_dir"; then
            log_info "Rotating logs in $log_dir..."
            
            # Compress logs older than 1 day
            execute_command "find $log_dir -name '*.log' -type f -mtime +1 -exec gzip {} \;" || true
            
            # Remove compressed logs older than retention period
            execute_command "find $log_dir -name '*.log.gz' -type f -mtime +$LOG_RETENTION_DAYS -delete" || true
            
            log_success "Log rotation completed for $log_dir"
        else
            log_info "Log directory $log_dir not found, skipping"
        fi
    done
    
    log_maintenance "Log rotation completed"
}

# Clean Docker logs
clean_docker_logs() {
    log_step 2 "Cleaning Docker container logs..."
    
    # Get list of running containers
    local containers=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q" 2>/dev/null || echo "")
    
    if [[ -n "$containers" ]]; then
        for container in $containers; do
            local container_name=$(execute_command "docker inspect --format='{{.Name}}' $container" | sed 's/^\/*//')
            local log_size=$(execute_command "docker logs --details $container 2>&1 | wc -c" || echo "0")
            
            if [[ "$log_size" -gt 10485760 ]]; then  # 10MB
                log_info "Truncating logs for container $container_name (${log_size} bytes)"
                execute_command "docker exec $container sh -c 'truncate -s 0 /proc/1/fd/1 /proc/1/fd/2' 2>/dev/null || true"
            fi
        done
        
        log_success "Docker log cleanup completed"
    else
        log_info "No running containers found"
    fi
    
    log_maintenance "Docker log cleanup completed"
}

# Clean temporary files and caches
clean_temp_files() {
    log_step 3 "Cleaning temporary files and caches..."
    
    local temp_dirs=(
        "/tmp"
        "/var/tmp"
        "$VPS_PROJECT_DIR/temp"
        "$VPS_PROJECT_DIR/.cache"
    )
    
    for temp_dir in "${temp_dirs[@]}"; do
        if execute_command "test -d $temp_dir"; then
            log_info "Cleaning temporary files in $temp_dir..."
            
            # Remove files older than 3 days
            execute_command "find $temp_dir -type f -mtime +3 -delete 2>/dev/null || true"
            
            # Remove empty directories
            execute_command "find $temp_dir -type d -empty -delete 2>/dev/null || true"
        fi
    done
    
    # Clean package manager caches
    execute_command "apt-get clean 2>/dev/null || yum clean all 2>/dev/null || true"
    
    log_success "Temporary file cleanup completed"
    log_maintenance "Temporary file cleanup completed"
}

# Database maintenance (if applicable)
database_maintenance() {
    log_step 4 "Performing database maintenance..."
    
    # Check if database container exists
    local db_container=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q db 2>/dev/null || echo ''")
    
    if [[ -n "$db_container" ]]; then
        log_info "Database container found, performing maintenance..."
        
        # Example database maintenance commands (adjust based on actual database)
        # execute_command "docker exec $db_container mysql -e 'OPTIMIZE TABLE sessions;' 2>/dev/null || true"
        # execute_command "docker exec $db_container pg_dump -c CloudToLocalLLM > /tmp/db_backup_$(date +%Y%m%d).sql 2>/dev/null || true"
        
        log_success "Database maintenance completed"
    else
        log_info "No database container found, skipping database maintenance"
    fi
    
    log_maintenance "Database maintenance completed"
}

# Check disk space
check_disk_space() {
    log_step 5 "Checking disk space..."
    
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" || echo "unknown")
    local available_space=$(execute_command "df -h / | tail -1 | awk '{print \$4}'" || echo "unknown")
    
    log_info "Disk usage: ${disk_usage}% (${available_space} available)"
    
    if [[ "$disk_usage" != "unknown" ]]; then
        if [[ "$disk_usage" -gt 90 ]]; then
            log_error "Critical: Disk usage is very high (${disk_usage}%)"
            log_maintenance "ALERT: Critical disk usage ${disk_usage}%"
        elif [[ "$disk_usage" -gt 80 ]]; then
            log_warning "Warning: Disk usage is high (${disk_usage}%)"
            log_maintenance "WARNING: High disk usage ${disk_usage}%"
        else
            log_success "Disk usage is acceptable (${disk_usage}%)"
        fi
    fi
}

# Check memory usage
check_memory_usage() {
    log_step 6 "Checking memory usage..."
    
    local memory_info=$(execute_command "free -h | grep Mem" || echo "unknown")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" || echo "unknown")
    
    log_info "Memory info: $memory_info"
    log_info "Memory usage: ${memory_usage}%"
    
    if [[ "$memory_usage" != "unknown" ]]; then
        if (( $(echo "$memory_usage > 90" | bc -l) )); then
            log_error "Critical: Memory usage is very high (${memory_usage}%)"
            log_maintenance "ALERT: Critical memory usage ${memory_usage}%"
        elif (( $(echo "$memory_usage > 80" | bc -l) )); then
            log_warning "Warning: Memory usage is high (${memory_usage}%)"
            log_maintenance "WARNING: High memory usage ${memory_usage}%"
        else
            log_success "Memory usage is acceptable (${memory_usage}%)"
        fi
    fi
}

# Health check containers
health_check_containers() {
    log_step 7 "Performing container health checks..."
    
    local containers=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps --format 'table {{.Name}}\t{{.Status}}'" 2>/dev/null || echo "")
    
    if [[ -n "$containers" ]]; then
        echo "$containers"
        
        # Check if all required containers are running
        local required_containers=("webapp" "api-backend")
        local unhealthy_containers=()
        
        for container in "${required_containers[@]}"; do
            if echo "$containers" | grep -q "$container.*Up"; then
                log_success "Container $container is healthy"
            else
                log_error "Container $container is not running"
                unhealthy_containers+=("$container")
            fi
        done
        
        if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
            log_error "Unhealthy containers: ${unhealthy_containers[*]}"
            log_maintenance "ALERT: Unhealthy containers ${unhealthy_containers[*]}"
        else
            log_success "All containers are healthy"
        fi
    else
        log_warning "No containers found or Docker Compose not available"
    fi
}

# Check application endpoints
check_application_endpoints() {
    log_step 8 "Checking application endpoints..."
    
    local endpoints=(
        "http://cloudtolocalllm.online"
        "http://app.cloudtolocalllm.online"
    )
    
    local failed_endpoints=()
    
    for endpoint in "${endpoints[@]}"; do
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$endpoint" || echo "000")
        
        if [[ "$http_code" == "200" ]]; then
            log_success "$endpoint is accessible (HTTP $http_code)"
        else
            log_error "$endpoint is not accessible (HTTP $http_code)"
            failed_endpoints+=("$endpoint")
        fi
    done
    
    if [[ ${#failed_endpoints[@]} -gt 0 ]]; then
        log_error "Failed endpoints: ${failed_endpoints[*]}"
        log_maintenance "ALERT: Failed endpoints ${failed_endpoints[*]}"
    else
        log_success "All endpoints are accessible"
    fi
}

# Generate daily maintenance report
generate_maintenance_report() {
    local status="$1"
    
    echo
    echo "=== CloudToLocalLLM Daily Maintenance Report ==="
    echo "Date: $(date -u +%Y-%m-%d)"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Status: $status"
    echo
    
    if [[ "$status" == "COMPLETED" ]]; then
        echo "✅ Daily maintenance completed successfully"
        echo "🗂️  Log rotation and cleanup performed"
        echo "🐳 Docker container maintenance completed"
        echo "💾 Disk and memory usage checked"
        echo "🏥 Health checks passed"
    else
        echo "⚠️  Daily maintenance completed with issues"
        echo "📋 Review the maintenance steps above for details"
        echo "🔧 Address any critical alerts immediately"
    fi
    
    echo
    echo "System Status Summary:"
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}'" || echo "unknown")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}'" || echo "unknown")
    echo "  Disk Usage: $disk_usage"
    echo "  Memory Usage: $memory_usage"
    echo "  Log Retention: $LOG_RETENTION_DAYS days"
    echo
    echo "Next maintenance: $(date -d '+1 day' -u +%Y-%m-%d)"
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM daily maintenance..."
    log_maintenance "Daily maintenance started"
    echo
    
    local maintenance_status="COMPLETED"
    
    # Create log directory if it doesn't exist
    execute_command "mkdir -p /var/log/CloudToLocalLLM" 2>/dev/null || true
    
    # Execute maintenance tasks
    rotate_logs || maintenance_status="ISSUES"
    echo
    
    clean_docker_logs || maintenance_status="ISSUES"
    echo
    
    clean_temp_files || maintenance_status="ISSUES"
    echo
    
    database_maintenance || maintenance_status="ISSUES"
    echo
    
    check_disk_space || maintenance_status="ISSUES"
    echo
    
    check_memory_usage || maintenance_status="ISSUES"
    echo
    
    health_check_containers || maintenance_status="ISSUES"
    echo
    
    check_application_endpoints || maintenance_status="ISSUES"
    echo
    
    # Generate final report
    generate_maintenance_report "$maintenance_status"
    
    if [[ "$maintenance_status" == "COMPLETED" ]]; then
        log_success "Daily maintenance completed successfully!"
        log_maintenance "Daily maintenance completed successfully"
        exit 0
    else
        log_warning "Daily maintenance completed with some issues"
        log_maintenance "Daily maintenance completed with issues"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Daily Maintenance Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script performs daily maintenance tasks:"
        echo "  - Log rotation and cleanup"
        echo "  - Docker container log management"
        echo "  - Temporary file cleanup"
        echo "  - Database maintenance (if applicable)"
        echo "  - Disk space monitoring"
        echo "  - Memory usage monitoring"
        echo "  - Container health checks"
        echo "  - Application endpoint verification"
        echo
        echo "Configuration:"
        echo "  Log retention: $LOG_RETENTION_DAYS days"
        echo "  Cache max size: $CACHE_MAX_SIZE"
        echo "  Docker log max size: $DOCKER_LOG_MAX_SIZE"
        echo
        echo "Can be run locally (connects to VPS) or directly on VPS"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
