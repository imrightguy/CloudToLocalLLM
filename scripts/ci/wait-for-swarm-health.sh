#!/bin/bash
# CloudToLocalLLM - Docker Swarm Health Check Script for CI/CD
# Waits for all containers to report healthy before proceeding
#
# Usage: ./wait-for-swarm-health.sh [OPTIONS]
# Run this script on the Docker Swarm manager node

set -euo pipefail

# Configuration
MAX_ATTEMPTS=${MAX_ATTEMPTS:-18}  # 18 attempts * 10s = 3 minutes (user choice)
POLL_INTERVAL=${POLL_INTERVAL:-10}
STACK_NAME=${STACK_NAME:-CloudToLocalLLM}

# Services to check (order matters - dependencies first)
SERVICES=(
  "${STACK_NAME}_postgres"
  "${STACK_NAME}_redis"
  "${STACK_NAME}_api-backend"
  "${STACK_NAME}_streaming-proxy"
  "${STACK_NAME}_web"
  "${STACK_NAME}_cloudflared"
)

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

# Check if a service exists
service_exists() {
    local service_name="$1"
    docker service inspect "$service_name" &>/dev/null
    return $?
}

# Get service replicas status
get_service_replicas() {
    local service_name="$1"
    docker service ls --filter "name=${service_name}" --format "{{.Replicas}}" 2>/dev/null || echo "0/0"
}

# Check if service has desired replicas running
check_service_running() {
    local service_name="$1"
    local replicas
    replicas=$(get_service_replicas "$service_name")
    
    # Parse replicas (e.g., "2/2" or "1/2")
    local running="${replicas%%/*}"
    local desired="${replicas##*/}"
    
    if [[ "$running" == "$desired" && "$desired" != "0" ]]; then
        return 0
    fi
    return 1
}

# Check container health status for a service
check_service_health() {
    local service_name="$1"
    local health_status="unknown"
    
    # Get all task IDs for the service
    local tasks
    tasks=$(docker service ps "$service_name" --filter "desired-state=running" --format "{{.ID}}" 2>/dev/null)
    
    if [[ -z "$tasks" ]]; then
        echo "no_tasks"
        return 1
    fi
    
    # Check each task's container health
    local all_healthy=true
    local has_health_check=false
    
    for task_id in $tasks; do
        # Get the container ID from task
        local container_id
        container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$task_id" 2>/dev/null | head -c 12)
        
        if [[ -n "$container_id" ]]; then
            # Check container health
            local container_health
            container_health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no_healthcheck{{end}}' "$container_id" 2>/dev/null || echo "unknown")
            
            if [[ "$container_health" == "no_healthcheck" ]]; then
                # Container has no health check defined, check if running
                local container_running
                container_running=$(docker inspect --format '{{.State.Running}}' "$container_id" 2>/dev/null || echo "false")
                if [[ "$container_running" == "true" ]]; then
                    health_status="running"
                else
                    all_healthy=false
                    health_status="not_running"
                fi
            elif [[ "$container_health" == "healthy" ]]; then
                has_health_check=true
                health_status="healthy"
            elif [[ "$container_health" == "starting" ]]; then
                has_health_check=true
                all_healthy=false
                health_status="starting"
            else
                has_health_check=true
                all_healthy=false
                health_status="$container_health"
            fi
        fi
    done
    
    if $all_healthy; then
        if $has_health_check; then
            echo "healthy"
        else
            echo "running"
        fi
        return 0
    else
        echo "$health_status"
        return 1
    fi
}

# Direct HTTP health check for services with endpoints
check_http_health() {
    local service_name="$1"
    local port="$2"
    local endpoint="${3:-/health}"
    
    # Get container IP through Docker network
    local container_id
    container_id=$(docker service ps "$service_name" --filter "desired-state=running" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [[ -z "$container_id" ]]; then
        return 1
    fi
    
    # Try to reach the health endpoint
    local response
    response=$(docker exec $(docker ps -q --filter "name=${service_name}" | head -1) wget -q -O - --timeout=5 "http://127.0.0.1:${port}${endpoint}" 2>/dev/null) || return 1
    
    echo "$response"
    return 0
}

# Check all services health
check_all_services() {
    local all_healthy=true
    local results=()
    
    echo ""
    log_info "Checking service health status..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-35s %-12s %-15s\n" "SERVICE" "REPLICAS" "HEALTH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for service in "${SERVICES[@]}"; do
        local replicas="N/A"
        local health="unknown"
        local status_color="$YELLOW"
        
        if service_exists "$service"; then
            replicas=$(get_service_replicas "$service")
            health=$(check_service_health "$service")
            
            case "$health" in
                "healthy"|"running")
                    status_color="$GREEN"
                    ;;
                "starting")
                    status_color="$YELLOW"
                    all_healthy=false
                    ;;
                *)
                    status_color="$RED"
                    all_healthy=false
                    ;;
            esac
        else
            health="not_found"
            status_color="$RED"
            all_healthy=false
        fi
        
        printf "%-35s %-12s ${status_color}%-15s${NC}\n" "$service" "$replicas" "$health"
        results+=("$service:$health")
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if $all_healthy; then
        return 0
    else
        return 1
    fi
}

# Main health check loop
main() {
    log_info "Docker Swarm Health Check for ${STACK_NAME}"
    log_info "Max wait time: $((MAX_ATTEMPTS * POLL_INTERVAL)) seconds"
    log_info "Poll interval: ${POLL_INTERVAL} seconds"
    echo ""
    
    # Verify Docker is available
    if ! docker info &>/dev/null; then
        log_error "Cannot connect to Docker daemon"
        exit 1
    fi
    
    # Verify stack exists
    if ! docker stack ls | grep -q "$STACK_NAME"; then
        log_error "Stack '${STACK_NAME}' not found"
        docker stack ls
        exit 1
    fi
    
    local attempt=1
    while [[ $attempt -le $MAX_ATTEMPTS ]]; do
        log_info "Health check attempt ${attempt}/${MAX_ATTEMPTS}"
        
        if check_all_services; then
            log_success "All services are healthy!"
            echo ""
            
            # Output for GitHub Actions
            if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
                echo "all_healthy=true" >> "$GITHUB_OUTPUT"
            fi
            
            # Final status dump
            log_info "Final service status:"
            docker stack services "$STACK_NAME"
            
            exit 0
        fi
        
        if [[ $attempt -lt $MAX_ATTEMPTS ]]; then
            log_warning "Not all services healthy. Waiting ${POLL_INTERVAL}s before retry..."
            sleep "$POLL_INTERVAL"
        fi
        
        ((attempt++))
    done
    
    # Timeout reached
    log_error "Health check timeout! Not all services became healthy within $((MAX_ATTEMPTS * POLL_INTERVAL)) seconds"
    echo ""
    
    # Output for GitHub Actions
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "all_healthy=false" >> "$GITHUB_OUTPUT"
    fi
    
    # Dump detailed diagnostics
    log_info "=== DIAGNOSTIC INFORMATION ==="
    echo ""
    
    log_info "Stack services:"
    docker stack services "$STACK_NAME" || true
    echo ""
    
    log_info "Stack tasks:"
    docker stack ps "$STACK_NAME" --no-trunc || true
    echo ""
    
    log_info "Recent container logs for unhealthy services:"
    for service in "${SERVICES[@]}"; do
        local health
        health=$(check_service_health "$service" 2>/dev/null)
        if [[ "$health" != "healthy" && "$health" != "running" ]]; then
            log_warning "Logs for ${service}:"
            docker service logs "$service" --tail 20 2>/dev/null || echo "  (no logs available)"
            echo ""
        fi
    done
    
    exit 1
}

# Run main function
main "$@"
