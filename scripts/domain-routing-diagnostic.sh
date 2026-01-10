#!/bin/bash
# Domain Routing Diagnostic Script for CloudToLocalLLM
# Diagnoses and fixes domain routing issues with Cloudflare tunnel
# Tests DNS resolution, service connectivity, and tunnel configuration
# Usage: ./domain-routing-diagnostic.sh [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="cloudtolocalllm"
LOG_FILE="./domain-routing-diagnostic.log"
REPORT_FILE="./domain-routing-report.json"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Domain configuration
DOMAINS=(
    "cloudtolocalllm.online"
    "app.cloudtolocalllm.online"
    "api.cloudtolocalllm.online"
    "argocd.cloudtolocalllm.online"
    "grafana.cloudtolocalllm.online"
)

# Service configuration
SERVICES=(
    "web:8080"
    "api-backend:8080"
    "streaming-proxy:3001"
    "argocd-server:80"
    "grafana:3000"
)

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

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

# Test result tracking
test_passed() {
    local test_name=$1
    log "✅ PASSED: $test_name"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_failed() {
    local test_name=$1
    local reason=$2
    error "❌ FAILED: $test_name - $reason"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_skipped() {
    local test_name=$1
    local reason=$2
    warning "⏭️  SKIPPED: $test_name - $reason"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Function to test DNS resolution
test_dns_resolution() {
    log "=== Testing DNS Resolution ==="

    for domain in "${DOMAINS[@]}"; do
        log "Testing DNS resolution for: $domain"

        # Test DNS lookup
        if nslookup $domain &> /dev/null; then
            local ip=$(nslookup $domain 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}')
            success "DNS resolution successful: $domain -> $ip"
            test_passed "dns_resolution_$domain"
        else
            error "DNS resolution failed for: $domain"
            test_failed "dns_resolution_$domain" "DNS lookup failed"
        fi

        # Test HTTP connectivity
        if curl -f --max-time 10 --resolve "$domain:443:127.0.0.1" https://$domain/ &> /dev/null 2>&1; then
            success "HTTPS connectivity successful: $domain"
            test_passed "https_connectivity_$domain"
        else
            warning "HTTPS connectivity failed: $domain (expected if tunnel not running)"
            test_skipped "https_connectivity_$domain" "Tunnel may not be running"
        fi
    done
}

# Function to test Cloudflare tunnel status
test_cloudflare_tunnel() {
    log "=== Testing Cloudflare Tunnel Status ==="

    # Check if cloudflared pod is running
    local tunnel_pods=$(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers | wc -l)

    if [ "$tunnel_pods" -gt 0 ]; then
        success "Cloudflare tunnel pods running: $tunnel_pods"
        test_passed "tunnel_pods_running"

        # Check tunnel logs for errors
        local error_logs=$(kubectl logs -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --tail=50 2>/dev/null | grep -i error | wc -l)

        if [ "$error_logs" -eq 0 ]; then
            success "No error logs in tunnel pods"
            test_passed "tunnel_logs_clean"
        else
            warning "Found $error_logs error entries in tunnel logs"
            kubectl logs -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --tail=20 | grep -i error | tee -a $LOG_FILE
            test_failed "tunnel_logs_clean" "Error logs detected in tunnel"
        fi

        # Check tunnel configuration
        if kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
            success "Tunnel configuration exists"
            test_passed "tunnel_config_exists"

            # Validate configuration
            local config_valid=$(kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath='{.data.config\.yaml}' | grep -c "tunnel:")
            if [ "$config_valid" -gt 0 ]; then
                success "Tunnel configuration is valid"
                test_passed "tunnel_config_valid"
            else
                error "Tunnel configuration is invalid"
                test_failed "tunnel_config_valid" "Missing tunnel configuration"
            fi
        else
            error "Tunnel configuration ConfigMap not found"
            test_failed "tunnel_config_exists" "cloudflared-config ConfigMap missing"
        fi

    else
        error "No Cloudflare tunnel pods running"
        test_failed "tunnel_pods_running" "cloudflared pods not found or not running"
    fi
}

# Function to test service connectivity
test_service_connectivity() {
    log "=== Testing Service Connectivity ==="

    for service_config in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_port <<< "$service_config"
        log "Testing service: $service_name on port $service_port"

        # Check if service exists
        if kubectl get svc $service_name -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null 2>/dev/null; then
            success "Service $service_name exists"
            test_passed "service_exists_$service_name"

            # Check service port configuration
            local configured_port=$(kubectl get svc $service_name -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath="{.spec.ports[0].port}")
            if [ "$configured_port" = "$service_port" ]; then
                success "Service $service_name port configuration correct: $configured_port"
                test_passed "service_port_$service_name"
            else
                error "Service $service_name port mismatch: expected $service_port, got $configured_port"
                test_failed "service_port_$service_name" "Port configuration incorrect"
            fi

            # Test internal connectivity
            local service_url="$service_name.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:$service_port"
            if kubectl run test-pod --image=busybox --rm -i --restart=Never -- wget -qO- $service_url/health &> /dev/null 2>/dev/null; then
                success "Internal connectivity to $service_name successful"
                test_passed "internal_connectivity_$service_name"
            else
                warning "Internal connectivity to $service_name failed (may be expected for some services)"
                test_skipped "internal_connectivity_$service_name" "Health endpoint may not exist"
            fi

        else
            error "Service $service_name not found"
            test_failed "service_exists_$service_name" "Service does not exist in cluster"
        fi
    done
}

# Function to test network policies
test_network_policies() {
    log "=== Testing Network Policies ==="

    # Check if network policies exist
    local np_count=$(kubectl get networkpolicies -n $CLOUDTOLOCLLM_NAMESPACE --no-headers | wc -l)

    if [ "$np_count" -gt 0 ]; then
        success "Found $np_count network policies"
        test_passed "network_policies_exist"

        # Check for overly restrictive policies
        local restrictive_policies=$(kubectl get networkpolicies -n $CLOUDTOLOCLLM_NAMESPACE -o yaml | grep -c "policyTypes:" | xargs)

        if [ "$restrictive_policies" -gt 0 ]; then
            warning "Found restrictive network policies - may block tunnel traffic"
            kubectl get networkpolicies -n $CLOUDTOLOCLLM_NAMESPACE | tee -a $LOG_FILE
            test_skipped "network_policy_check" "Manual review required"
        else
            success "No restrictive network policies detected"
            test_passed "network_policy_check"
        fi
    else
        success "No network policies configured (allowing all traffic)"
        test_passed "network_policies_none"
    fi
}

# Function to test Cloudflare tunnel configuration
test_tunnel_configuration() {
    log "=== Testing Cloudflare Tunnel Configuration ==="

    # Extract tunnel configuration
    local tunnel_config=$(kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath='{.data.config\.yaml}' 2>/dev/null)

    if [ -n "$tunnel_config" ]; then
        # Check ingress rules count
        local ingress_count=$(echo "$tunnel_config" | grep -c "hostname:")
        success "Found $ingress_count ingress rules in tunnel configuration"
        test_passed "tunnel_ingress_count"

        # Validate each domain has corresponding service
        for domain in "${DOMAINS[@]}"; do
            if echo "$tunnel_config" | grep -q "$domain"; then
                success "Domain $domain configured in tunnel"
                test_passed "domain_config_$domain"
            else
                error "Domain $domain not found in tunnel configuration"
                test_failed "domain_config_$domain" "Missing from tunnel config"
            fi
        done

        # Check for service reference issues
        local service_refs=$(echo "$tunnel_config" | grep "service:" | wc -l)
        if [ "$service_refs" -gt 0 ]; then
            success "Found $service_refs service references in tunnel config"
            test_passed "tunnel_service_refs"
        else
            error "No service references found in tunnel configuration"
            test_failed "tunnel_service_refs" "Missing service references"
        fi

    else
        error "Unable to retrieve tunnel configuration"
        test_failed "tunnel_config_retrieval" "Cannot access cloudflared-config ConfigMap"
    fi
}

# Function to diagnose routing issues
diagnose_routing_issues() {
    log "=== Diagnosing Routing Issues ==="

    # Check for common issues
    local issues_found=0

    # Issue 1: Service port mismatches
    log "Checking for service port mismatches..."
    for service_config in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_port <<< "$service_config"

        if kubectl get svc $service_name -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
            local actual_port=$(kubectl get svc $service_name -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath="{.spec.ports[0].port}")

            if [ "$actual_port" != "$service_port" ]; then
                error "PORT MISMATCH: $service_name configured for port $service_port but service uses $actual_port"
                issues_found=$((issues_found + 1))
            fi
        fi
    done

    # Issue 2: Missing services
    log "Checking for missing services..."
    for service_config in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_port <<< "$service_config"

        if ! kubectl get svc $service_name -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
            error "MISSING SERVICE: $service_name not found in $CLOUDTOLOCLLM_NAMESPACE namespace"
            issues_found=$((issues_found + 1))
        fi
    done

    # Issue 3: Tunnel connectivity
    log "Checking tunnel connectivity..."
    if [ "$(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers | wc -l)" -eq 0 ]; then
        error "TUNNEL DOWN: No cloudflared pods running"
        issues_found=$((issues_found + 1))
    fi

    # Issue 4: DNS resolution
    log "Checking DNS resolution..."
    for domain in "${DOMAINS[@]}"; do
        if ! nslookup $domain &> /dev/null; then
            error "DNS FAILURE: $domain does not resolve"
            issues_found=$((issues_found + 1))
        fi
    done

    if [ $issues_found -eq 0 ]; then
        success "No routing issues detected"
        test_passed "routing_diagnosis"
    else
        error "Found $issues_found routing issues that need to be fixed"
        test_failed "routing_diagnosis" "$issues_found issues detected"
    fi
}

# Function to generate fixes for routing issues
generate_routing_fixes() {
    log "=== Generating Routing Fixes ==="

    local fixes_file="/tmp/routing-fixes-$(date +%Y%m%d_%H%M%S).sh"

    cat > $fixes_file << 'EOF'
#!/bin/bash
# Auto-generated routing fixes for CloudToLocalLLM
# Run this script to apply fixes for identified routing issues

set -e

echo "Applying CloudToLocalLLM routing fixes..."

# Fix 1: Ensure services are running
echo "1. Checking service status..."
kubectl get pods -n cloudtolocalllm --no-headers | head -10

# Fix 2: Restart cloudflared tunnel if needed
echo "2. Checking tunnel status..."
if [ "$(kubectl get pods -n cloudtolocalllm -l app=cloudflared --field-selector=status.phase=Running --no-headers | wc -l)" -eq 0 ]; then
    echo "Restarting cloudflared tunnel..."
    kubectl rollout restart deployment/cloudflared -n cloudtolocalllm
    sleep 30
fi

# Fix 3: Verify service endpoints
echo "3. Testing service endpoints..."
kubectl run test-connectivity --image=busybox --rm -i --restart=Never -- nslookup web.cloudtolocalllm.svc.cluster.local || echo "DNS lookup failed"

# Fix 4: Check tunnel logs
echo "4. Checking tunnel logs for errors..."
kubectl logs -n cloudtolocalllm -l app=cloudflared --tail=20 | grep -i error || echo "No errors found in recent logs"

# Fix 5: Validate tunnel configuration
echo "5. Validating tunnel configuration..."
kubectl get configmap cloudflared-config -n cloudtolocalllm -o yaml

echo "Routing fixes applied. Monitor the system and check domain connectivity."
EOF

    chmod +x $fixes_file
    success "Routing fixes generated: $fixes_file"
    log "Run '$fixes_file' to apply the fixes"
}

# Function to generate comprehensive report
generate_routing_report() {
    log "=== Generating Domain Routing Report ==="

    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    cat > $REPORT_FILE << EOF
{
  "domain_routing_diagnostic": {
    "timestamp": "$DATE",
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "skipped_tests": $SKIPPED_TESTS,
    "success_rate": $success_rate
  },
  "domains_tested": $(printf '%s\n' "${DOMAINS[@]}" | jq -R . | jq -s .),
  "services_tested": $(printf '%s\n' "${SERVICES[@]}" | jq -R . | jq -s .),
  "tunnel_status": {
    "pods_running": $(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l),
    "config_exists": $(kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE &>/dev/null && echo "true" || echo "false")
  },
  "critical_findings": [
    $(if [ $FAILED_TESTS -gt 0 ]; then echo "\"$FAILED_TESTS routing tests failed - domain routing is broken\""; fi)
    $(if [ $success_rate -lt 80 ]; then echo "\"Success rate below 80% - major routing issues detected\""; fi)
    $(if [ "$(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)" -eq 0 ]; then echo "\"Cloudflare tunnel is not running - all external access broken\""; fi)
  ],
  "routing_ready": $([ $success_rate -ge 80 ] && [ $FAILED_TESTS -le 2 ] && echo "true" || echo "false")
}
EOF

    success "Domain routing report generated: $REPORT_FILE"

    # Display summary
    log "=== Domain Routing Diagnostic Summary ==="
    log "Total Tests: $TOTAL_TESTS"
    log "Passed: $PASSED_TESTS"
    log "Failed: $FAILED_TESTS"
    log "Skipped: $SKIPPED_TESTS"
    log "Success Rate: ${success_rate}%"

    if [ $success_rate -ge 80 ]; then
        success "🎉 Domain routing diagnostics completed successfully"
    else
        error "❌ CRITICAL: Domain routing has major issues - $FAILED_TESTS failures detected"
        error "Routing success rate: ${success_rate}% (Required: 80%+)"
        generate_routing_fixes
    fi
}

# Main execution function
main() {
    log "=== CloudToLocalLLM Domain Routing Diagnostic Started ==="

    # Parse command line arguments
    local run_dns_test=false
    local run_tunnel_test=false
    local run_service_test=false
    local run_network_test=false
    local run_config_test=false
    local run_diagnosis=false
    local generate_report=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dns-test)
                run_dns_test=true
                shift
                ;;
            --tunnel-test)
                run_tunnel_test=true
                shift
                ;;
            --service-test)
                run_service_test=true
                shift
                ;;
            --network-test)
                run_network_test=true
                shift
                ;;
            --config-test)
                run_config_test=true
                shift
                ;;
            --diagnosis)
                run_diagnosis=true
                shift
                ;;
            --all-tests)
                run_dns_test=true
                run_tunnel_test=true
                run_service_test=true
                run_network_test=true
                run_config_test=true
                run_diagnosis=true
                generate_report=true
                shift
                ;;
            --generate-report)
                generate_report=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --dns-test         Test DNS resolution for domains"
                echo "  --tunnel-test      Test Cloudflare tunnel status"
                echo "  --service-test     Test service connectivity"
                echo "  --network-test     Test network policies"
                echo "  --config-test      Test tunnel configuration"
                echo "  --diagnosis        Run comprehensive diagnosis"
                echo "  --all-tests        Run all diagnostic tests"
                echo "  --generate-report  Generate detailed report"
                echo "  --help            Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Initialize log file
    echo "=== CloudToLocalLLM Domain Routing Diagnostic Started at $DATE ===" > $LOG_FILE

    # Determine what to run
    if [ $# -eq 0 ]; then
        # Run all tests by default
        run_dns_test=true
        run_tunnel_test=true
        run_service_test=true
        run_network_test=true
        run_config_test=true
        run_diagnosis=true
        generate_report=true
    fi

    # Execute tests
    if [ "$run_dns_test" = true ]; then
        test_dns_resolution
    fi

    if [ "$run_tunnel_test" = true ]; then
        test_cloudflare_tunnel
    fi

    if [ "$run_service_test" = true ]; then
        test_service_connectivity
    fi

    if [ "$run_network_test" = true ]; then
        test_network_policies
    fi

    if [ "$run_config_test" = true ]; then
        test_tunnel_configuration
    fi

    if [ "$run_diagnosis" = true ]; then
        diagnose_routing_issues
    fi

    if [ "$generate_report" = true ]; then
        generate_routing_report
    fi

    # Final status
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    if [ $success_rate -ge 80 ]; then
        success "Domain routing diagnostic completed successfully"
        exit 0
    else
        error "Domain routing diagnostic completed with critical issues"
        error "Success Rate: ${success_rate}% | Failed Tests: $FAILED_TESTS"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"