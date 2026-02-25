#!/bin/bash

# CloudToLocalLLM - Google Cloud Run Cost Estimation Script
# This script helps estimate monthly costs for running CloudToLocalLLM on Google Cloud Run
#
# Usage: ./estimate-costs.sh [OPTIONS]

set -euo pipefail

# Default values (can be overridden)
MONTHLY_REQUESTS=10000
AVG_REQUEST_DURATION=200  # milliseconds
REGION="us-central1"
VERBOSE=false

# Cloud Run pricing (as of 2024, subject to change)
# Prices in USD per unit
CPU_PRICE_PER_VCPU_SECOND=0.00002400
MEMORY_PRICE_PER_GB_SECOND=0.00000250
REQUEST_PRICE_PER_MILLION=0.40

# Free tier limits (per month)
FREE_CPU_SECONDS=180000      # 50 vCPU-hours
FREE_MEMORY_SECONDS=360000   # 100 GB-hours
FREE_REQUESTS=2000000        # 2 million requests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service configurations
declare -A WEB_CONFIG=(
    [cpu]=1
    [memory]=1
    [instances_avg]=1
    [concurrency]=80
)

declare -A API_CONFIG=(
    [cpu]=2
    [memory]=2
    [instances_avg]=2
    [concurrency]=100
)

declare -A STREAMING_CONFIG=(
    [cpu]=1
    [memory]=1
    [instances_avg]=1
    [concurrency]=50
)

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
CloudToLocalLLM - Google Cloud Run Cost Estimation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --requests NUM          Monthly requests (default: $MONTHLY_REQUESTS)
    --duration MS           Average request duration in ms (default: $AVG_REQUEST_DURATION)
    --region REGION         Google Cloud region (default: $REGION)
    --verbose               Show detailed calculations
    --help, -h              Show this help message

EXAMPLES:
    $0                                      # Default estimation
    $0 --requests 100000 --duration 500    # High traffic scenario
    $0 --requests 1000 --duration 100      # Low traffic scenario
    $0 --verbose                           # Show detailed breakdown

PREDEFINED SCENARIOS:
    Use --requests with these values for common scenarios:
    - Light usage: 1000 requests/month
    - Medium usage: 50000 requests/month
    - High usage: 500000 requests/month
    - Enterprise: 2000000 requests/month

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --requests)
                MONTHLY_REQUESTS="$2"
                shift 2
                ;;
            --duration)
                AVG_REQUEST_DURATION="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
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

# Calculate cost for a service
calculate_service_cost() {
    local service_name="$1"
    local -n config=$2
    local request_percentage="$3"
    
    local cpu=${config[cpu]}
    local memory=${config[memory]}
    local instances_avg=${config[instances_avg]}
    local concurrency=${config[concurrency]}
    
    # Calculate service-specific requests
    local service_requests=$(echo "$MONTHLY_REQUESTS * $request_percentage / 100" | bc -l)
    
    # Calculate execution time (assuming requests are distributed evenly)
    local execution_seconds=$(echo "$service_requests * $AVG_REQUEST_DURATION / 1000" | bc -l)
    
    # Calculate CPU seconds
    local cpu_seconds=$(echo "$execution_seconds * $cpu" | bc -l)
    
    # Calculate memory GB-seconds
    local memory_gb_seconds=$(echo "$execution_seconds * $memory" | bc -l)
    
    # Calculate costs (after free tier)
    local cpu_cost=0
    local memory_cost=0
    local request_cost=0
    
    # CPU cost (after free tier)
    if (( $(echo "$cpu_seconds > $FREE_CPU_SECONDS" | bc -l) )); then
        local billable_cpu_seconds=$(echo "$cpu_seconds - $FREE_CPU_SECONDS" | bc -l)
        cpu_cost=$(echo "$billable_cpu_seconds * $CPU_PRICE_PER_VCPU_SECOND" | bc -l)
    fi
    
    # Memory cost (after free tier)
    if (( $(echo "$memory_gb_seconds > $FREE_MEMORY_SECONDS" | bc -l) )); then
        local billable_memory_seconds=$(echo "$memory_gb_seconds - $FREE_MEMORY_SECONDS" | bc -l)
        memory_cost=$(echo "$billable_memory_seconds * $MEMORY_PRICE_PER_GB_SECOND" | bc -l)
    fi
    
    # Request cost (after free tier)
    if (( $(echo "$service_requests > $FREE_REQUESTS" | bc -l) )); then
        local billable_requests=$(echo "$service_requests - $FREE_REQUESTS" | bc -l)
        request_cost=$(echo "$billable_requests / 1000000 * $REQUEST_PRICE_PER_MILLION" | bc -l)
    fi
    
    local total_cost=$(echo "$cpu_cost + $memory_cost + $request_cost" | bc -l)
    
    if [ "$VERBOSE" = true ]; then
        printf "  %-20s: %'d requests (%.1f%%)\n" "$service_name Requests" "$(printf "%.0f" "$service_requests")" "$request_percentage"
        printf "  %-20s: %.2f seconds\n" "Execution Time" "$execution_seconds"
        printf "  %-20s: %.2f vCPU-seconds\n" "CPU Usage" "$cpu_seconds"
        printf "  %-20s: %.2f GB-seconds\n" "Memory Usage" "$memory_gb_seconds"
        printf "  %-20s: \$%.4f\n" "CPU Cost" "$cpu_cost"
        printf "  %-20s: \$%.4f\n" "Memory Cost" "$memory_cost"
        printf "  %-20s: \$%.4f\n" "Request Cost" "$request_cost"
        printf "  %-20s: \$%.2f\n" "Total Cost" "$total_cost"
        echo
    else
        printf "  %-20s: \$%.2f/month\n" "$service_name" "$total_cost"
    fi
    
    echo "$total_cost"
}

# Calculate total costs
calculate_total_costs() {
    log_header "=== CloudToLocalLLM - Google Cloud Run Cost Estimation ==="
    echo
    
    log_info "Estimation Parameters:"
    printf "  %-20s: %'d requests/month\n" "Monthly Requests" "$MONTHLY_REQUESTS"
    printf "  %-20s: %d ms\n" "Avg Request Duration" "$AVG_REQUEST_DURATION"
    printf "  %-20s: %s\n" "Region" "$REGION"
    echo
    
    log_info "Service Costs:"
    
    # Calculate costs for each service
    # Assuming traffic distribution: Web 40%, API 50%, Streaming 10%
    local web_cost=$(calculate_service_cost "Web Service" WEB_CONFIG 40)
    local api_cost=$(calculate_service_cost "API Service" API_CONFIG 50)
    local streaming_cost=$(calculate_service_cost "Streaming Service" STREAMING_CONFIG 10)
    
    local total_cost=$(echo "$web_cost + $api_cost + $streaming_cost" | bc -l)
    
    echo
    log_header "=== Cost Summary ==="
    printf "  %-20s: \$%.2f/month\n" "Web Service" "$web_cost"
    printf "  %-20s: \$%.2f/month\n" "API Service" "$api_cost"
    printf "  %-20s: \$%.2f/month\n" "Streaming Service" "$streaming_cost"
    echo "  ────────────────────────────────"
    printf "  %-20s: \$%.2f/month\n" "Total Estimated Cost" "$total_cost"
    echo
    
    # Additional costs
    log_info "Additional Considerations:"
    echo "  • Networking (egress): ~\$0.12/GB (first 1GB free)"
    echo "  • Cloud SQL (if used): ~\$7-50/month depending on instance"
    echo "  • Load Balancer (if used): ~\$18/month + \$0.008/GB"
    echo "  • Custom domains: Free with Cloud Run"
    echo "  • SSL certificates: Free (Google-managed)"
    echo
    
    # Cost comparison
    log_header "=== Cost Comparison Scenarios ==="
    echo
    
    # Calculate costs for different scenarios
    local scenarios=(
        "1000:Light Usage"
        "10000:Medium Usage"
        "50000:High Usage"
        "100000:Very High Usage"
        "500000:Enterprise Usage"
    )
    
    printf "%-15s %-20s %-15s\n" "Scenario" "Requests/Month" "Est. Cost/Month"
    echo "────────────────────────────────────────────────────────"
    
    for scenario in "${scenarios[@]}"; do
        IFS=':' read -r requests name <<< "$scenario"
        
        # Quick calculation for comparison
        local quick_total=0
        for service_pct in 40 50 10; do
            local service_requests=$(echo "$requests * $service_pct / 100" | bc -l)
            local execution_time=$(echo "$service_requests * $AVG_REQUEST_DURATION / 1000" | bc -l)
            local service_cost=$(echo "$execution_time * 0.00005" | bc -l)  # Simplified calculation
            quick_total=$(echo "$quick_total + $service_cost" | bc -l)
        done
        
        printf "%-15s %-20s \$%-14.2f\n" "$name" "$(printf "%'d" "$requests")" "$quick_total"
    done
    
    echo
    log_header "=== Optimization Recommendations ==="
    echo
    
    if (( $(echo "$total_cost < 10" | bc -l) )); then
        log_success "Your estimated costs are very reasonable for Cloud Run!"
        echo "  • Consider setting minimum instances to 1 for better performance"
        echo "  • Monitor actual usage and adjust resources as needed"
    elif (( $(echo "$total_cost < 50" | bc -l) )); then
        log_info "Your costs are moderate. Consider these optimizations:"
        echo "  • Optimize request duration to reduce compute costs"
        echo "  • Use caching to reduce API calls"
        echo "  • Monitor cold start frequency"
    else
        log_warning "Your estimated costs are high. Consider:"
        echo "  • Comparing with VPS deployment costs"
        echo "  • Optimizing application performance"
        echo "  • Using Cloud Run minimum instances strategically"
        echo "  • Implementing request caching and optimization"
    fi
    
    echo
    log_info "Cost Monitoring Tips:"
    echo "  • Set up billing alerts in Google Cloud Console"
    echo "  • Monitor actual vs estimated costs weekly"
    echo "  • Use Cloud Monitoring to track resource usage"
    echo "  • Consider committed use discounts for predictable workloads"
    echo
    
    log_info "Next Steps:"
    echo "  1. Deploy to Cloud Run and monitor actual costs"
    echo "  2. Compare with your current VPS costs"
    echo "  3. Optimize based on real usage patterns"
    echo "  4. Set up cost alerts and monitoring"
}

# Main function
main() {
    # Check if bc is installed
    if ! command -v bc &> /dev/null; then
        log_error "bc (calculator) is required but not installed."
        log_error "Install with: sudo apt-get install bc (Ubuntu/Debian) or brew install bc (macOS)"
        exit 1
    fi
    
    parse_args "$@"
    calculate_total_costs
}

# Run main function with all arguments
main "$@"
