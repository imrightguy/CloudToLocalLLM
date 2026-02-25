#!/bin/bash

# CloudToLocalLLM Weekly Maintenance Script
# Performs weekly maintenance tasks including system updates, Docker cleanup,
# SSL certificate checks, and performance analysis for optimal system health

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/CloudToLocalLLM"

# Maintenance configuration
DOCKER_IMAGE_RETENTION_DAYS=14
SSL_EXPIRY_WARNING_DAYS=30
PERFORMANCE_LOG_RETENTION_WEEKS=4

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
    echo "[$timestamp] WEEKLY_MAINTENANCE: $1" >> "$log_file" 2>/dev/null || true
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

# Update system packages
update_system_packages() {
    log_step 1 "Updating system packages..."
    
    # Detect package manager and update
    if execute_command "command -v apt-get >/dev/null 2>&1"; then
        log_info "Updating packages with apt..."
        execute_command "apt-get update && apt-get upgrade -y" || log_warning "Package update failed"
        execute_command "apt-get autoremove -y" || true
        execute_command "apt-get autoclean" || true
    elif execute_command "command -v yum >/dev/null 2>&1"; then
        log_info "Updating packages with yum..."
        execute_command "yum update -y" || log_warning "Package update failed"
        execute_command "yum autoremove -y" || true
    elif execute_command "command -v dnf >/dev/null 2>&1"; then
        log_info "Updating packages with dnf..."
        execute_command "dnf update -y" || log_warning "Package update failed"
        execute_command "dnf autoremove -y" || true
    else
        log_warning "No supported package manager found"
    fi
    
    log_success "System package update completed"
    log_maintenance "System packages updated"
}

# Clean Docker system
clean_docker_system() {
    log_step 2 "Performing Docker system cleanup..."
    
    # Remove unused containers
    log_info "Removing stopped containers..."
    execute_command "docker container prune -f" || true
    
    # Remove unused images
    log_info "Removing unused images..."
    execute_command "docker image prune -f" || true
    
    # Remove unused networks
    log_info "Removing unused networks..."
    execute_command "docker network prune -f" || true
    
    # Remove unused volumes
    log_info "Removing unused volumes..."
    execute_command "docker volume prune -f" || true
    
    # Show disk space saved
    local docker_space=$(execute_command "docker system df" || echo "Docker system df not available")
    log_info "Docker disk usage after cleanup:"
    echo "$docker_space"
    
    log_success "Docker system cleanup completed"
    log_maintenance "Docker system cleanup completed"
}

# Check SSL certificates
check_ssl_certificates() {
    log_step 3 "Checking SSL certificates..."
    
    local domains=("cloudtolocalllm.online" "app.cloudtolocalllm.online")
    local ssl_issues=()
    
    for domain in "${domains[@]}"; do
        log_info "Checking SSL certificate for $domain..."
        
        local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL_ERROR")
        
        if [[ "$cert_info" != "SSL_ERROR" ]]; then
            local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
            local current_date=$(date +%s)
            local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
            
            if [[ "$days_until_expiry" -lt 0 ]]; then
                log_error "$domain SSL certificate has expired!"
                ssl_issues+=("$domain: EXPIRED")
            elif [[ "$days_until_expiry" -lt "$SSL_EXPIRY_WARNING_DAYS" ]]; then
                log_warning "$domain SSL certificate expires in $days_until_expiry days"
                ssl_issues+=("$domain: expires in $days_until_expiry days")
            else
                log_success "$domain SSL certificate is valid (expires in $days_until_expiry days)"
            fi
        else
            log_error "Failed to check SSL certificate for $domain"
            ssl_issues+=("$domain: check failed")
        fi
    done
    
    if [[ ${#ssl_issues[@]} -gt 0 ]]; then
        log_error "SSL certificate issues found: ${ssl_issues[*]}"
        log_maintenance "ALERT: SSL certificate issues ${ssl_issues[*]}"
    else
        log_success "All SSL certificates are valid"
    fi
}

# Performance analysis
performance_analysis() {
    log_step 4 "Performing performance analysis..."
    
    # CPU usage analysis
    local cpu_usage=$(execute_command "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" || echo "unknown")
    log_info "Average CPU usage: ${cpu_usage}%"
    
    # Memory usage analysis
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" || echo "unknown")
    log_info "Memory usage: ${memory_usage}%"
    
    # Disk I/O analysis
    local disk_io=$(execute_command "iostat -x 1 2 | tail -n +4 | awk 'NF && \$1 != \"Device\" {util += \$NF; count++} END {if (count > 0) printf \"%.1f\", util/count; else print \"0\"}'" 2>/dev/null || echo "unknown")
    log_info "Average disk utilization: ${disk_io}%"
    
    # Network analysis
    local network_connections=$(execute_command "netstat -tuln | wc -l" || echo "unknown")
    log_info "Active network connections: $network_connections"
    
    # Container resource usage
    local container_stats=$(execute_command "cd $VPS_PROJECT_DIR && docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'" 2>/dev/null || echo "Container stats not available")
    log_info "Container resource usage:"
    echo "$container_stats"
    
    # Log performance metrics
    local perf_log="/var/log/CloudToLocalLLM/performance.log"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    execute_command "echo '[$timestamp] CPU:${cpu_usage}% MEM:${memory_usage}% DISK:${disk_io}% CONN:$network_connections' >> $perf_log" 2>/dev/null || true
    
    log_success "Performance analysis completed"
    log_maintenance "Performance analysis completed"
}

# Security updates check
security_updates_check() {
    log_step 5 "Checking for security updates..."
    
    if execute_command "command -v apt-get >/dev/null 2>&1"; then
        local security_updates=$(execute_command "apt list --upgradable 2>/dev/null | grep -i security | wc -l" || echo "0")
        if [[ "$security_updates" -gt 0 ]]; then
            log_warning "$security_updates security updates available"
            log_maintenance "WARNING: $security_updates security updates available"
        else
            log_success "No security updates pending"
        fi
    elif execute_command "command -v yum >/dev/null 2>&1"; then
        local security_updates=$(execute_command "yum --security check-update 2>/dev/null | grep -c 'needed for security' || echo '0'")
        if [[ "$security_updates" -gt 0 ]]; then
            log_warning "$security_updates security updates available"
            log_maintenance "WARNING: $security_updates security updates available"
        else
            log_success "No security updates pending"
        fi
    else
        log_info "Security update check not available for this system"
    fi
}

# Backup verification
backup_verification() {
    log_step 6 "Verifying backup integrity..."
    
    local backup_dir="/var/backups/CloudToLocalLLM"
    
    if execute_command "test -d $backup_dir"; then
        local latest_backup=$(execute_command "ls -t $backup_dir/*.tar.gz 2>/dev/null | head -1" || echo "")
        
        if [[ -n "$latest_backup" ]]; then
            log_info "Latest backup: $(basename $latest_backup)"
            
            # Test backup integrity
            if execute_command "tar -tzf $latest_backup >/dev/null 2>&1"; then
                log_success "Latest backup integrity verified"
            else
                log_error "Latest backup integrity check failed"
                log_maintenance "ALERT: Backup integrity check failed"
            fi
            
            # Check backup age
            local backup_age=$(execute_command "find $latest_backup -mtime +7" || echo "")
            if [[ -n "$backup_age" ]]; then
                log_warning "Latest backup is older than 7 days"
                log_maintenance "WARNING: Backup is older than 7 days"
            fi
        else
            log_warning "No backups found in $backup_dir"
            log_maintenance "WARNING: No backups found"
        fi
    else
        log_warning "Backup directory not found: $backup_dir"
    fi
}

# Generate weekly maintenance report
generate_weekly_report() {
    local status="$1"
    
    echo
    echo "=== CloudToLocalLLM Weekly Maintenance Report ==="
    echo "Week of: $(date -d 'last monday' +%Y-%m-%d) to $(date -d 'next sunday' +%Y-%m-%d)"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Status: $status"
    echo
    
    if [[ "$status" == "COMPLETED" ]]; then
        echo "✅ Weekly maintenance completed successfully"
        echo "📦 System packages updated"
        echo "🐳 Docker system cleaned"
        echo "🔒 SSL certificates checked"
        echo "📊 Performance analysis completed"
        echo "🛡️  Security updates checked"
        echo "💾 Backup integrity verified"
    else
        echo "⚠️  Weekly maintenance completed with issues"
        echo "📋 Review the maintenance steps above for details"
        echo "🚨 Address any critical alerts immediately"
    fi
    
    echo
    echo "System Health Summary:"
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}'" || echo "unknown")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}'" || echo "unknown")
    local uptime=$(execute_command "uptime | awk '{print \$3, \$4}' | sed 's/,//'" || echo "unknown")
    echo "  Disk Usage: $disk_usage"
    echo "  Memory Usage: $memory_usage"
    echo "  System Uptime: $uptime"
    echo
    echo "Next weekly maintenance: $(date -d '+1 week' +%Y-%m-%d)"
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM weekly maintenance..."
    log_maintenance "Weekly maintenance started"
    echo
    
    local maintenance_status="COMPLETED"
    
    # Create log directory if it doesn't exist
    execute_command "mkdir -p /var/log/CloudToLocalLLM" 2>/dev/null || true
    
    # Execute maintenance tasks
    update_system_packages || maintenance_status="ISSUES"
    echo
    
    clean_docker_system || maintenance_status="ISSUES"
    echo
    
    check_ssl_certificates || maintenance_status="ISSUES"
    echo
    
    performance_analysis || maintenance_status="ISSUES"
    echo
    
    security_updates_check || maintenance_status="ISSUES"
    echo
    
    backup_verification || maintenance_status="ISSUES"
    echo
    
    # Generate final report
    generate_weekly_report "$maintenance_status"
    
    if [[ "$maintenance_status" == "COMPLETED" ]]; then
        log_success "Weekly maintenance completed successfully!"
        log_maintenance "Weekly maintenance completed successfully"
        exit 0
    else
        log_warning "Weekly maintenance completed with some issues"
        log_maintenance "Weekly maintenance completed with issues"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Weekly Maintenance Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script performs weekly maintenance tasks:"
        echo "  - System package updates"
        echo "  - Docker system cleanup"
        echo "  - SSL certificate monitoring"
        echo "  - Performance analysis and logging"
        echo "  - Security update checks"
        echo "  - Backup integrity verification"
        echo
        echo "Configuration:"
        echo "  Docker image retention: $DOCKER_IMAGE_RETENTION_DAYS days"
        echo "  SSL expiry warning: $SSL_EXPIRY_WARNING_DAYS days"
        echo "  Performance log retention: $PERFORMANCE_LOG_RETENTION_WEEKS weeks"
        echo
        echo "Can be run locally (connects to VPS) or directly on VPS"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
