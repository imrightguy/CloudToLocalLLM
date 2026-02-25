#!/bin/bash

##############################################################################
# AWS EKS Final Deployment Verification Script
#
# This script performs comprehensive final verification of the CloudToLocalLLM
# deployment on AWS EKS, including:
# - All services running on AWS EKS
# - Smoke tests on all endpoints
# - Cloudflare domain resolution
# - SSL/TLS certificate validation
# - End-to-end user flow testing
#
# Usage: ./final-deployment-verification.sh [environment]
# Example: ./final-deployment-verification.sh development
##############################################################################

set -e

# Configuration
NAMESPACE="${NAMESPACE:-CloudToLocalLLM}"
ENVIRONMENT="${1:-development}"
CLUSTER_NAME="cloudtolocalllm-eks"
REGION="${AWS_REGION:-us-east-1}"

# Cloudflare domains
DOMAINS=(
  "cloudtolocalllm.online"
  "app.cloudtolocalllm.online"
  "api.cloudtolocalllm.online"
  "auth.cloudtolocalllm.online"
)

# Health endpoints
HEALTH_ENDPOINTS=(
  "https://api.cloudtolocalllm.online/health"
  "https://app.cloudtolocalllm.online/health"
)

# Smoke test endpoints
SMOKE_TEST_ENDPOINTS=(
  "https://app.cloudtolocalllm.online"
  "https://api.cloudtolocalllm.online/health"
  "https://cloudtolocalllm.online"
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Verification results array
declare -a VERIFICATION_RESULTS

##############################################################################
# Helper Functions
##############################################################################

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASSED++))
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAILED++))
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARNINGS++))
}

add_verification_result() {
  local category="$1"
  local check="$2"
  local status="$3"
  local details="$4"
  
  VERIFICATION_RESULTS+=("$category|$check|$status|$details")
}

##############################################################################
# Verification Functions
##############################################################################

verify_all_services_running() {
  log_info "Verifying all services are running on AWS EKS..."
  
  # Check cluster connectivity
  if kubectl cluster-info &> /dev/null; then
    log_success "Connected to EKS cluster"
    add_verification_result "Services" "Cluster Connectivity" "PASSED" "Successfully connected to EKS cluster"
  else
    log_error "Cannot connect to EKS cluster"
    add_verification_result "Services" "Cluster Connectivity" "FAILED" "Cannot connect to EKS cluster"
    return 1
  fi
  
  # Check namespace
  if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_success "Namespace '$NAMESPACE' exists"
    add_verification_result "Services" "Namespace Exists" "PASSED" "Namespace '$NAMESPACE' exists"
  else
    log_error "Namespace '$NAMESPACE' does not exist"
    add_verification_result "Services" "Namespace Exists" "FAILED" "Namespace '$NAMESPACE' does not exist"
    return 1
  fi
  
  # Check all pods are running
  local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$pods" ]; then
    log_error "No pods found in namespace '$NAMESPACE'"
    add_verification_result "Services" "Running Pods" "FAILED" "No pods found"
    return 1
  fi
  
  local pod_count=$(echo "$pods" | wc -w)
  log_success "Found $pod_count running pod(s)"
  add_verification_result "Services" "Running Pods" "PASSED" "Found $pod_count running pod(s)"
  
  # Check all pods are ready
  local ready_count=0
  for pod in $pods; do
    local ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$ready" = "True" ]; then
      ((ready_count++))
    fi
  done
  
  if [ "$ready_count" -eq "$pod_count" ]; then
    log_success "All $pod_count pod(s) are ready"
    add_verification_result "Services" "Pod Readiness" "PASSED" "All $pod_count pod(s) are ready"
  else
    log_warning "Only $ready_count of $pod_count pod(s) are ready"
    add_verification_result "Services" "Pod Readiness" "WARNING" "Only $ready_count of $pod_count pod(s) are ready"
  fi
  
  # Check services
  local services=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  local service_count=$(echo "$services" | wc -w)
  log_success "Found $service_count service(s)"
  add_verification_result "Services" "Services Count" "PASSED" "Found $service_count service(s)"
}

verify_smoke_tests() {
  log_info "Performing smoke tests on all endpoints..."
  
  for endpoint in "${SMOKE_TEST_ENDPOINTS[@]}"; do
    if timeout 10 curl -s -k -o /dev/null -w "%{http_code}" "$endpoint" | grep -q "200"; then
      log_success "Smoke test passed for $endpoint"
      add_verification_result "Smoke Tests" "$endpoint" "PASSED" "Status: 200"
    else
      log_error "Smoke test failed for $endpoint"
      add_verification_result "Smoke Tests" "$endpoint" "FAILED" "Unexpected status"
    fi
  done
}

verify_cloudflare_domains() {
  log_info "Verifying all Cloudflare domains resolve correctly..."
  
  for domain in "${DOMAINS[@]}"; do
    if nslookup "$domain" &> /dev/null; then
      local ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
      if [ -n "$ip" ]; then
        log_success "Domain '$domain' resolves to $ip"
        add_verification_result "DNS Resolution" "$domain" "PASSED" "Resolves to $ip"
      else
        log_error "Domain '$domain' resolved but no IP found"
        add_verification_result "DNS Resolution" "$domain" "FAILED" "No IP found"
      fi
    else
      log_error "Failed to resolve domain '$domain'"
      add_verification_result "DNS Resolution" "$domain" "FAILED" "Resolution failed"
    fi
  done
}

verify_ssl_certificates() {
  log_info "Verifying SSL/TLS certificates are valid..."
  
  for domain in "${DOMAINS[@]}"; do
    if timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
      log_success "SSL certificate for '$domain' is valid"
      add_verification_result "SSL Certificates" "$domain" "PASSED" "Certificate is valid"
    else
      log_error "SSL certificate for '$domain' is invalid or unreachable"
      add_verification_result "SSL Certificates" "$domain" "FAILED" "Certificate invalid or unreachable"
    fi
  done
}

verify_health_endpoints() {
  log_info "Verifying health check endpoints..."
  
  for endpoint in "${HEALTH_ENDPOINTS[@]}"; do
    if timeout 10 curl -s -k "$endpoint" | grep -q "ok\|healthy\|running" 2>/dev/null; then
      log_success "Health endpoint '$endpoint' is responding"
      add_verification_result "Health Checks" "$endpoint" "PASSED" "Status: 200"
    else
      log_error "Health endpoint '$endpoint' is not responding"
      add_verification_result "Health Checks" "$endpoint" "FAILED" "Not responding"
    fi
  done
}

verify_end_to_end_flow() {
  log_info "Performing end-to-end user flow testing..."
  
  # Step 1: Access main domain
  log_info "Step 1: Accessing main domain..."
  if timeout 10 curl -s -k -o /dev/null -w "%{http_code}" "https://cloudtolocalllm.online" | grep -q "200"; then
    log_success "Main domain is accessible"
    add_verification_result "E2E Flow" "Main Domain Access" "PASSED" "Status: 200"
  else
    log_error "Main domain is not accessible"
    add_verification_result "E2E Flow" "Main Domain Access" "FAILED" "Not accessible"
  fi
  
  # Step 2: Access app domain
  log_info "Step 2: Accessing app domain..."
  if timeout 10 curl -s -k -o /dev/null -w "%{http_code}" "https://app.cloudtolocalllm.online" | grep -q "200"; then
    log_success "App domain is accessible"
    add_verification_result "E2E Flow" "App Domain Access" "PASSED" "Status: 200"
  else
    log_error "App domain is not accessible"
    add_verification_result "E2E Flow" "App Domain Access" "FAILED" "Not accessible"
  fi
  
  # Step 3: Check API health
  log_info "Step 3: Checking API health..."
  if timeout 10 curl -s -k "https://api.cloudtolocalllm.online/health" | grep -q "ok\|healthy\|running"; then
    log_success "API health check passed"
    add_verification_result "E2E Flow" "API Health Check" "PASSED" "Status: 200"
  else
    log_error "API health check failed"
    add_verification_result "E2E Flow" "API Health Check" "FAILED" "Health check failed"
  fi
  
  # Step 4: Verify no errors in pod logs
  log_info "Step 4: Checking pod logs for errors..."
  local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  local error_count=0
  
  for pod in $pods; do
    local pod_errors=$(kubectl logs "$pod" -n "$NAMESPACE" 2>/dev/null | grep -i "error\|exception\|fatal" | wc -l)
    error_count=$((error_count + pod_errors))
  done
  
  if [ "$error_count" -eq 0 ]; then
    log_success "No errors found in pod logs"
    add_verification_result "E2E Flow" "Pod Logs" "PASSED" "No errors found"
  else
    log_warning "Found $error_count error(s) in pod logs"
    add_verification_result "E2E Flow" "Pod Logs" "WARNING" "Found $error_count error(s)"
  fi
}

generate_verification_report() {
  echo ""
  echo "=========================================="
  echo "Final Deployment Verification Report"
  echo "=========================================="
  echo "Environment: $ENVIRONMENT"
  echo "Namespace: $NAMESPACE"
  echo "Cluster: $CLUSTER_NAME"
  echo "Region: $REGION"
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  
  # Group results by category
  local current_category=""
  for result in "${VERIFICATION_RESULTS[@]}"; do
    IFS='|' read -r category check status details <<< "$result"
    
    if [ "$category" != "$current_category" ]; then
      if [ -n "$current_category" ]; then
        echo ""
      fi
      echo -e "${YELLOW}$category:${NC}"
      current_category="$category"
    fi
    
    case "$status" in
      "PASSED")
        echo -e "  ${GREEN}[$status]${NC} $check"
        ;;
      "FAILED")
        echo -e "  ${RED}[$status]${NC} $check"
        ;;
      "WARNING")
        echo -e "  ${YELLOW}[$status]${NC} $check"
        ;;
    esac
    echo "    Details: $details"
  done
  
  # Summary
  echo ""
  echo "=========================================="
  echo "Summary"
  echo "=========================================="
  echo -e "${GREEN}Passed: $PASSED${NC}"
  echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
  echo -e "${RED}Failed: $FAILED${NC}"
  echo ""
  
  if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo -e "${GREEN}✓ AWS EKS deployment is ready for production${NC}"
    return 0
  else
    echo -e "${RED}✗ Some checks failed. Please review the output above.${NC}"
    return 1
  fi
}

##############################################################################
# Main Execution
##############################################################################

main() {
  echo ""
  echo "=========================================="
  echo "AWS EKS Final Deployment Verification"
  echo "=========================================="
  echo ""
  
  # Run all verification checks
  verify_all_services_running
  echo ""
  
  verify_smoke_tests
  echo ""
  
  verify_cloudflare_domains
  echo ""
  
  verify_ssl_certificates
  echo ""
  
  verify_health_endpoints
  echo ""
  
  verify_end_to_end_flow
  echo ""
  
  # Generate report
  generate_verification_report
}

# Run main function
main "$@"
