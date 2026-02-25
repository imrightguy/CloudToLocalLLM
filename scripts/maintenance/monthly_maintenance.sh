#!/bin/bash

# CloudToLocalLLM Monthly Maintenance Script
# Performs monthly maintenance tasks including full system backup, security updates,
# disk space analysis, and performance optimization for long-term system health

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/CloudToLocalLLM"

# Maintenance configuration
BACKUP_RETENTION_MONTHS=6
LOG_ARCHIVE_MONTHS=3
PERFORMANCE_REPORT_MONTHS=12

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

log_phase() {
    echo -e "${MAGENTA}=== PHASE $1: $2 ===${NC}"
}

# Create maintenance log entry
log_maintenance() {
    local log_file="/var/log/CloudToLocalLLM/maintenance.log"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$timestamp] MONTHLY_MAINTENANCE: $1" >> "$log_file" 2>/dev/null || true
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

# Full system backup
full_system_backup() {
    log_phase 1 "FULL SYSTEM BACKUP"
    
    local backup_date=$(date +%Y%m%d)
    local backup_dir="/var/backups/CloudToLocalLLM"
    local backup_file="cloudtolocalllm_full_backup_${backup_date}.tar.gz"
    
    log_step 1.1 "Creating full system backup..."
    
    # Create backup directory
    execute_command "mkdir -p $backup_dir"
    
    # Create comprehensive backup
    log_info "Backing up application files..."
    execute_command "cd $VPS_PROJECT_DIR && tar -czf $backup_dir/$backup_file \
        --exclude='*.log' \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='build/web' \
        . 2>/dev/null || true"
    
    # Backup configuration files
    log_info "Backing up system configuration..."
    execute_command "tar -czf $backup_dir/system_config_${backup_date}.tar.gz \
        /etc/nginx/ \
        /etc/ssl/ \
        /etc/systemd/system/CloudToLocalLLM* \
        /var/log/CloudToLocalLLM/ \
        2>/dev/null || true"
    
    # Verify backup integrity
    if execute_command "test -f $backup_dir/$backup_file"; then
        local backup_size=$(execute_command "du -h $backup_dir/$backup_file | cut -f1")
        log_success "Full backup created: $backup_file ($backup_size)"
        
        # Test backup integrity
        if execute_command "tar -tzf $backup_dir/$backup_file >/dev/null 2>&1"; then
            log_success "Backup integrity verified"
        else
            log_error "Backup integrity check failed"
            return 1
        fi
    else
        log_error "Backup creation failed"
        return 1
    fi
    
    log_maintenance "Full system backup completed: $backup_file"
}

# Clean old backups
clean_old_backups() {
    log_step 1.2 "Cleaning old backups..."
    
    local backup_dir="/var/backups/CloudToLocalLLM"
    
    if execute_command "test -d $backup_dir"; then
        # Remove backups older than retention period
        local old_backups=$(execute_command "find $backup_dir -name '*.tar.gz' -mtime +$((BACKUP_RETENTION_MONTHS * 30))" || echo "")
        
        if [[ -n "$old_backups" ]]; then
            echo "$old_backups" | while read -r backup; do
                execute_command "rm -f $backup"
                log_info "Removed old backup: $(basename $backup)"
            done
            log_success "Old backup cleanup completed"
        else
            log_info "No old backups to remove"
        fi
        
        # Show current backup status
        local backup_count=$(execute_command "ls -1 $backup_dir/*.tar.gz 2>/dev/null | wc -l" || echo "0")
        local backup_size=$(execute_command "du -sh $backup_dir 2>/dev/null | cut -f1" || echo "unknown")
        log_info "Current backups: $backup_count files ($backup_size total)"
    fi
}

# Security audit and updates
security_audit() {
    log_phase 2 "SECURITY AUDIT AND UPDATES"
    
    log_step 2.1 "Performing security audit..."
    
    # Check for failed login attempts
    local failed_logins=$(execute_command "grep 'Failed password' /var/log/auth.log 2>/dev/null | wc -l" || echo "0")
    if [[ "$failed_logins" -gt 100 ]]; then
        log_warning "$failed_logins failed login attempts found in auth.log"
        log_maintenance "WARNING: $failed_logins failed login attempts"
    else
        log_success "Failed login attempts: $failed_logins (acceptable)"
    fi
    
    # Check for suspicious network connections
    local suspicious_connections=$(execute_command "netstat -tuln | grep -E ':(22|80|443|3000)' | wc -l" || echo "0")
    log_info "Active connections on monitored ports: $suspicious_connections"
    
    # Check file permissions on critical files
    log_step 2.2 "Checking file permissions..."
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/ssh/sshd_config"
        "$VPS_PROJECT_DIR/docker-compose.yml"
    )
    
    for file in "${critical_files[@]}"; do
        if execute_command "test -f $file"; then
            local perms=$(execute_command "stat -c '%a' $file" || echo "unknown")
            log_info "$(basename $file): $perms"
        fi
    done
    
    # Update security packages
    log_step 2.3 "Installing security updates..."
    if execute_command "command -v apt-get >/dev/null 2>&1"; then
        execute_command "apt-get update && apt-get upgrade -y" || log_warning "Security update failed"
    elif execute_command "command -v yum >/dev/null 2>&1"; then
        execute_command "yum update -y --security" || log_warning "Security update failed"
    fi
    
    log_success "Security audit completed"
    log_maintenance "Security audit and updates completed"
}

# Disk space analysis and optimization
disk_space_analysis() {
    log_phase 3 "DISK SPACE ANALYSIS AND OPTIMIZATION"
    
    log_step 3.1 "Analyzing disk usage..."
    
    # Overall disk usage
    local disk_info=$(execute_command "df -h /" || echo "Disk info not available")
    log_info "Root filesystem usage:"
    echo "$disk_info"
    
    # Directory size analysis
    log_info "Largest directories in /opt/CloudToLocalLLM:"
    execute_command "du -sh $VPS_PROJECT_DIR/* 2>/dev/null | sort -hr | head -10" || true
    
    # Log file analysis
    log_step 3.2 "Analyzing log files..."
    local log_dirs=("/var/log" "/var/log/CloudToLocalLLM")
    
    for log_dir in "${log_dirs[@]}"; do
        if execute_command "test -d $log_dir"; then
            local log_size=$(execute_command "du -sh $log_dir 2>/dev/null | cut -f1" || echo "unknown")
            log_info "$log_dir: $log_size"
            
            # Find largest log files
            execute_command "find $log_dir -name '*.log' -type f -exec du -h {} + 2>/dev/null | sort -hr | head -5" || true
        fi
    done
    
    # Archive old logs
    log_step 3.3 "Archiving old logs..."
    local archive_date=$(date -d "$LOG_ARCHIVE_MONTHS months ago" +%Y%m%d)
    
    for log_dir in "${log_dirs[@]}"; do
        if execute_command "test -d $log_dir"; then
            # Archive logs older than retention period
            execute_command "find $log_dir -name '*.log' -mtime +$((LOG_ARCHIVE_MONTHS * 30)) -exec gzip {} \;" || true
            
            # Remove very old archived logs
            execute_command "find $log_dir -name '*.log.gz' -mtime +$((LOG_ARCHIVE_MONTHS * 60)) -delete" || true
        fi
    done
    
    log_success "Disk space analysis and optimization completed"
    log_maintenance "Disk space analysis completed"
}

# Performance optimization
performance_optimization() {
    log_phase 4 "PERFORMANCE OPTIMIZATION"
    
    log_step 4.1 "Optimizing system performance..."
    
    # Clear system caches
    log_info "Clearing system caches..."
    execute_command "sync && echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null || true
    
    # Optimize Docker
    log_info "Optimizing Docker..."
    execute_command "docker system prune -af --volumes" || true
    
    # Update locate database
    log_info "Updating locate database..."
    execute_command "updatedb" 2>/dev/null || true
    
    # Generate performance report
    log_step 4.2 "Generating performance report..."
    local perf_report="/var/log/CloudToLocalLLM/monthly_performance_$(date +%Y%m).log"
    
    execute_command "cat > $perf_report << EOF
CloudToLocalLLM Monthly Performance Report
Date: $(date -u +%Y-%m-%d)
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

System Information:
- Hostname: \$(hostname)
- Uptime: \$(uptime)
- Kernel: \$(uname -r)
- CPU Info: \$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
- Memory: \$(free -h | grep Mem | awk '{print \$2}')

Disk Usage:
\$(df -h)

Memory Usage:
\$(free -h)

Top Processes by CPU:
\$(ps aux --sort=-%cpu | head -10)

Top Processes by Memory:
\$(ps aux --sort=-%mem | head -10)

Docker Container Stats:
\$(cd $VPS_PROJECT_DIR && docker stats --no-stream 2>/dev/null || echo 'Docker stats not available')

Network Connections:
\$(netstat -tuln | wc -l) active connections

Load Average:
\$(uptime | awk '{print \$10, \$11, \$12}')
EOF" 2>/dev/null || true
    
    log_success "Performance optimization completed"
    log_maintenance "Performance optimization completed"
}

# System health check
system_health_check() {
    log_phase 5 "COMPREHENSIVE SYSTEM HEALTH CHECK"
    
    log_step 5.1 "Running system health checks..."
    
    # Check critical services
    local services=("nginx" "docker" "ssh")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if execute_command "systemctl is-active $service >/dev/null 2>&1"; then
            log_success "Service $service is running"
        else
            log_error "Service $service is not running"
            failed_services+=("$service")
        fi
    done
    
    # Check application containers
    local containers=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q" 2>/dev/null || echo "")
    if [[ -n "$containers" ]]; then
        local running_containers=$(echo "$containers" | wc -l)
        log_success "$running_containers application containers are running"
    else
        log_error "No application containers found"
        failed_services+=("containers")
    fi
    
    # Check SSL certificates
    if [[ -f "$SCRIPT_DIR/../ssl/check_certificates.sh" ]]; then
        log_info "Running SSL certificate check..."
        "$SCRIPT_DIR/../ssl/check_certificates.sh" || true
    fi
    
    # Overall health assessment
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "System health check passed"
    else
        log_error "System health issues found: ${failed_services[*]}"
        log_maintenance "ALERT: System health issues ${failed_services[*]}"
    fi
}

# Generate monthly report
generate_monthly_report() {
    local status="$1"
    
    echo
    echo "=== CloudToLocalLLM Monthly Maintenance Report ==="
    echo "Month: $(date +%B\ %Y)"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Status: $status"
    echo
    
    if [[ "$status" == "COMPLETED" ]]; then
        echo "✅ Monthly maintenance completed successfully"
        echo "💾 Full system backup created and verified"
        echo "🛡️  Security audit and updates completed"
        echo "💽 Disk space analysis and optimization performed"
        echo "⚡ Performance optimization completed"
        echo "🏥 Comprehensive system health check passed"
    else
        echo "⚠️  Monthly maintenance completed with issues"
        echo "📋 Review the maintenance phases above for details"
        echo "🚨 Address any critical alerts immediately"
    fi
    
    echo
    echo "System Summary:"
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}'" || echo "unknown")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}'" || echo "unknown")
    local uptime=$(execute_command "uptime | awk '{print \$3, \$4}' | sed 's/,//'" || echo "unknown")
    local backup_count=$(execute_command "ls -1 /var/backups/CloudToLocalLLM/*.tar.gz 2>/dev/null | wc -l" || echo "0")
    
    echo "  Disk Usage: $disk_usage"
    echo "  Memory Usage: $memory_usage"
    echo "  System Uptime: $uptime"
    echo "  Available Backups: $backup_count"
    echo
    echo "Next monthly maintenance: $(date -d '+1 month' +%Y-%m-%d)"
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM monthly maintenance..."
    log_maintenance "Monthly maintenance started"
    echo
    
    local maintenance_status="COMPLETED"
    
    # Create log directory if it doesn't exist
    execute_command "mkdir -p /var/log/CloudToLocalLLM" 2>/dev/null || true
    
    # Execute maintenance phases
    full_system_backup || maintenance_status="ISSUES"
    clean_old_backups || maintenance_status="ISSUES"
    echo
    
    security_audit || maintenance_status="ISSUES"
    echo
    
    disk_space_analysis || maintenance_status="ISSUES"
    echo
    
    performance_optimization || maintenance_status="ISSUES"
    echo
    
    system_health_check || maintenance_status="ISSUES"
    echo
    
    # Generate final report
    generate_monthly_report "$maintenance_status"
    
    if [[ "$maintenance_status" == "COMPLETED" ]]; then
        log_success "Monthly maintenance completed successfully!"
        log_maintenance "Monthly maintenance completed successfully"
        exit 0
    else
        log_warning "Monthly maintenance completed with some issues"
        log_maintenance "Monthly maintenance completed with issues"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Monthly Maintenance Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script performs monthly maintenance tasks:"
        echo "  - Full system backup creation and verification"
        echo "  - Old backup cleanup"
        echo "  - Security audit and updates"
        echo "  - Disk space analysis and optimization"
        echo "  - Performance optimization"
        echo "  - Comprehensive system health check"
        echo
        echo "Configuration:"
        echo "  Backup retention: $BACKUP_RETENTION_MONTHS months"
        echo "  Log archive: $LOG_ARCHIVE_MONTHS months"
        echo "  Performance reports: $PERFORMANCE_REPORT_MONTHS months"
        echo
        echo "Can be run locally (connects to VPS) or directly on VPS"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
