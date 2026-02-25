#!/bin/bash

# CloudToLocalLLM - Google Cloud Run Health Check Script
# This script monitors the health and performance of deployed Cloud Run services
#
# Usage: ./health-check.sh [OPTIONS]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/cloudrun/.env.cloudrun"

# Default values
REGION=""
PROJECT_ID=""
VERBOSE=false
CONTINUOUS=false
INTERVAL=30
OUTPUT_FORMAT="table"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service names
SERVICES=("CloudToLocalLLM-web" "cloudtolocalllm-api" "CloudToLocalLLM-streaming")

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
CloudToLocalLLM - Google Cloud Run Health Check Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --project PROJECT_ID    Google Cloud Project ID
    --region REGION         Google Cloud region
    --continuous            Run continuous monitoring
    --interval SECONDS      Interval for continuous monitoring (default: 30)
    --format FORMAT         Output format: table, json, csv (default: table)
    --verbose               Show detailed information
    --help, -h              Show this help message

EXAMPLES:
    $0                                      # One-time health check
    $0 --continuous --interval 60           # Monitor every 60 seconds
    $0 --format json                        # Output in JSON format
    $0 --project my-project --region us-west1  # Specify project and region

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                PROJECT_ID="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --continuous)
                CONTINUOUS=true
                shift
                ;;
            --interval)
                INTERVAL="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
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
    if [ -f "$ENV_FILE" ]; then
        log_info "Loading environment configuration..."
        source "$ENV_FILE"
        
        # Use values from env file if not provided via command line
        if [ -z "$PROJECT_ID" ]; then
            PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-}"
        fi
        if [ -z "$REGION" ]; then
            REGION="${GOOGLE_CLOUD_REGION:-us-central1}"
        fi
    fi
    
    # Validate required variables
    if [ -z "$PROJECT_ID" ]; then
        log_error "Project ID is required. Set via --project or in $ENV_FILE"
        exit 1
    fi
    
    if [ -z "$REGION" ]; then
        log_error "Region is required. Set via --region or in $ENV_FILE"
        exit 1
    fi
    
    # Set gcloud project
    gcloud config set project "$PROJECT_ID" --quiet
}

# Check if service exists
service_exists() {
    local service_name="$1"
    gcloud run services describe "$service_name" \
        --platform=managed \
        --region="$REGION" \
        --format="value(metadata.name)" \
        2>/dev/null | grep -q "$service_name"
}

# Get service URL
get_service_url() {
    local service_name="$1"
    gcloud run services describe "$service_name" \
        --platform=managed \
        --region="$REGION" \
        --format="value(status.url)" \
        2>/dev/null || echo ""
}

# Get service status
get_service_status() {
    local service_name="$1"
    gcloud run services describe "$service_name" \
        --platform=managed \
        --region="$REGION" \
        --format="value(status.conditions[0].status)" \
        2>/dev/null || echo "Unknown"
}

# Get service metrics
get_service_metrics() {
    local service_name="$1"
    local url="$2"
    
    # Initialize metrics
    local http_status="N/A"
    local response_time="N/A"
    local health_status="Unknown"
    
    if [ -n "$url" ]; then
        # Test health endpoint
        local health_url="$url/health"
        local start_time=$(date +%s%N)
        
        if http_response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$health_url" 2>/dev/null); then
            local end_time=$(date +%s%N)
            response_time=$(echo "scale=3; ($end_time - $start_time) / 1000000" | bc)
            http_status="$http_response"
            
            if [ "$http_response" = "200" ]; then
                health_status="Healthy"
            else
                health_status="Unhealthy"
            fi
        else
            health_status="Unreachable"
            http_status="Error"
        fi
    fi
    
    echo "$http_status,$response_time,$health_status"
}

# Get service instances
get_service_instances() {
    local service_name="$1"
    gcloud run services describe "$service_name" \
        --platform=managed \
        --region="$REGION" \
        --format="value(status.traffic[0].percent)" \
        2>/dev/null || echo "0"
}

# Perform health check for a single service
check_service_health() {
    local service_name="$1"
    
    if ! service_exists "$service_name"; then
        echo "$service_name,Not Deployed,N/A,N/A,N/A,N/A"
        return
    fi
    
    local url=$(get_service_url "$service_name")
    local status=$(get_service_status "$service_name")
    local metrics=$(get_service_metrics "$service_name" "$url")
    local instances=$(get_service_instances "$service_name")
    
    IFS=',' read -r http_status response_time health_status <<< "$metrics"
    
    echo "$service_name,$status,$url,$http_status,$response_time,$health_status"
}

# Output results in table format
output_table() {
    local results=("$@")
    
    log_header "=== CloudToLocalLLM Health Check Results ==="
    echo
    printf "%-25s %-12s %-15s %-12s %-15s\n" "Service" "Status" "HTTP Code" "Response Time" "Health"
    echo "────────────────────────────────────────────────────────────────────────────────────"
    
    for result in "${results[@]}"; do
        IFS=',' read -r service status url http_code response_time health <<< "$result"
        
        # Color coding for status
        local status_color=""
        local health_color=""
        
        case "$status" in
            "True") status_color="${GREEN}Ready${NC}" ;;
            "False") status_color="${RED}Not Ready${NC}" ;;
            "Unknown") status_color="${YELLOW}Unknown${NC}" ;;
            "Not Deployed") status_color="${YELLOW}Not Deployed${NC}" ;;
            *) status_color="$status" ;;
        esac
        
        case "$health" in
            "Healthy") health_color="${GREEN}Healthy${NC}" ;;
            "Unhealthy") health_color="${RED}Unhealthy${NC}" ;;
            "Unreachable") health_color="${RED}Unreachable${NC}" ;;
            *) health_color="$health" ;;
        esac
        
        printf "%-25s %-20s %-15s %-12s %-15s\n" \
            "$service" \
            "$status_color" \
            "$http_code" \
            "${response_time}ms" \
            "$health_color"
    done
    
    echo
}

# Output results in JSON format
output_json() {
    local results=("$@")
    
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"project_id\": \"$PROJECT_ID\","
    echo "  \"region\": \"$REGION\","
    echo "  \"services\": ["
    
    local first=true
    for result in "${results[@]}"; do
        IFS=',' read -r service status url http_code response_time health <<< "$result"
        
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        echo -n "    {"
        echo -n "\"name\": \"$service\", "
        echo -n "\"status\": \"$status\", "
        echo -n "\"url\": \"$url\", "
        echo -n "\"http_code\": \"$http_code\", "
        echo -n "\"response_time_ms\": \"$response_time\", "
        echo -n "\"health\": \"$health\""
        echo -n "}"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Output results in CSV format
output_csv() {
    local results=("$@")
    
    echo "Service,Status,URL,HTTP_Code,Response_Time_MS,Health"
    for result in "${results[@]}"; do
        echo "$result"
    done
}

# Perform health check for all services
perform_health_check() {
    local timestamp=$(date)
    local results=()
    
    if [ "$VERBOSE" = true ]; then
        log_info "Checking health of Cloud Run services..."
        log_info "Project: $PROJECT_ID"
        log_info "Region: $REGION"
        log_info "Timestamp: $timestamp"
        echo
    fi
    
    # Check each service
    for service in "${SERVICES[@]}"; do
        if [ "$VERBOSE" = true ]; then
            log_info "Checking $service..."
        fi
        
        local result=$(check_service_health "$service")
        results+=("$result")
    done
    
    # Output results based on format
    case "$OUTPUT_FORMAT" in
        "json")
            output_json "${results[@]}"
            ;;
        "csv")
            output_csv "${results[@]}"
            ;;
        "table"|*)
            output_table "${results[@]}"
            ;;
    esac
    
    # Summary
    if [ "$OUTPUT_FORMAT" = "table" ]; then
        local healthy_count=0
        local total_count=${#results[@]}
        
        for result in "${results[@]}"; do
            IFS=',' read -r service status url http_code response_time health <<< "$result"
            if [ "$health" = "Healthy" ]; then
                ((healthy_count++))
            fi
        done
        
        if [ "$healthy_count" -eq "$total_count" ]; then
            log_success "All services are healthy ($healthy_count/$total_count)"
        else
            log_warning "Some services are unhealthy ($healthy_count/$total_count healthy)"
        fi
        
        if [ "$VERBOSE" = true ]; then
            echo
            log_info "Detailed service information:"
            for service in "${SERVICES[@]}"; do
                if service_exists "$service"; then
                    local url=$(get_service_url "$service")
                    echo "  $service: $url"
                fi
            done
        fi
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Check prerequisites
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud SDK (gcloud) is not installed"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null && [ "$OUTPUT_FORMAT" = "table" ]; then
        log_error "bc (calculator) is required for response time calculations"
        exit 1
    fi
    
    load_env_config
    
    if [ "$CONTINUOUS" = true ]; then
        log_info "Starting continuous monitoring (interval: ${INTERVAL}s, format: $OUTPUT_FORMAT)"
        log_info "Press Ctrl+C to stop"
        echo
        
        while true; do
            perform_health_check
            
            if [ "$OUTPUT_FORMAT" = "table" ]; then
                echo
                log_info "Next check in ${INTERVAL} seconds..."
                echo
            fi
            
            sleep "$INTERVAL"
        done
    else
        perform_health_check
    fi
}

# Handle Ctrl+C gracefully
trap 'echo; log_info "Monitoring stopped"; exit 0' INT

# Run main function with all arguments
main "$@"
