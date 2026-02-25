#!/bin/bash

##############################################################################
# AWS EKS Deployment Verification Script
#
# This script verifies that all components of the CloudToLocalLLM deployment
# on AWS EKS are running correctly and accessible.
#
# Usage: ./verify-deployment.sh [environment]
# Example: ./verify-deployment.sh development
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

##############################################################################
# Verification Functions
##############################################################################

verify_cluster_connectivity() {
  log_info "Verifying EKS cluster connectivity..."
  
  if kubectl cluster-info &> /dev/null; then
    log_success "Connected to EKS cluster"
  else
    log_error "Failed to connect to EKS cluster"
    return 1
  fi
}

verify_namespace_exists() {
  log_info "Verifying namespace exists..."
  
  if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_success "Namespace '$NAMESPACE' exists"
  else
    log_error "Namespace '$NAMESPACE' does not exist"
    return 1
  fi
}

verify_pods_running() {
  log_info "Verifying all pods are running..."
  
  local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$pods" ]; then
    log_warning "No pods found in namespace '$NAMESPACE'"
    return 0
  fi
  
  local all_running=true
  for pod in $pods; do
    local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    
    if [ "$status" = "Running" ]; then
      log_success "Pod '$pod' is running"
    else
      log_error "Pod '$pod' is in state: $status"
      all_running=false
    fi
  done
  
  return $([ "$all_running" = true ] && echo 0 || echo 1)
}

verify_pod_readiness() {
  log_info "Verifying pod readiness probes..."
  
  local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$pods" ]; then
    log_warning "No pods found in namespace '$NAMESPACE'"
    return 0
  fi
  
  local all_ready=true
  for pod in $pods; do
    local ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    
    if [ "$ready" = "True" ]; then
      log_success "Pod '$pod' is ready"
    else
      log_error "Pod '$pod' is not ready"
      all_ready=false
    fi
  done
  
  return $([ "$all_ready" = true ] && echo 0 || echo 1)
}

verify_services_accessible() {
  log_info "Verifying services are accessible..."
  
  local services=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$services" ]; then
    log_warning "No services found in namespace '$NAMESPACE'"
    return 0
  fi
  
  local all_accessible=true
  for service in $services; do
    local endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}')
    
    if [ -n "$endpoints" ]; then
      log_success "Service '$service' has endpoints"
    else
      log_warning "Service '$service' has no endpoints"
      all_accessible=false
    fi
  done
  
  return $([ "$all_accessible" = true ] && echo 0 || echo 1)
}

verify_dns_resolution() {
  log_info "Verifying DNS resolution for Cloudflare domains..."
  
  local all_resolved=true
  for domain in "${DOMAINS[@]}"; do
    if nslookup "$domain" &> /dev/null; then
      local ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
      if [ -n "$ip" ]; then
        log_success "Domain '$domain' resolves to $ip"
      else
        log_error "Domain '$domain' resolved but no IP found"
        all_resolved=false
      fi
    else
      log_error "Failed to resolve domain '$domain'"
      all_resolved=false
    fi
  done
  
  return $([ "$all_resolved" = true ] && echo 0 || echo 1)
}

verify_ssl_certificates() {
  log_info "Verifying SSL/TLS certificates..."
  
  local all_valid=true
  for domain in "${DOMAINS[@]}"; do
    if timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
      log_success "SSL certificate for '$domain' is valid"
    else
      log_error "SSL certificate for '$domain' is invalid or unreachable"
      all_valid=false
    fi
  done
  
  return $([ "$all_valid" = true ] && echo 0 || echo 1)
}

verify_ingress_configured() {
  log_info "Verifying Ingress is configured..."
  
  if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
    local ingress_count=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$ingress_count" -gt 0 ]; then
      log_success "Found $ingress_count Ingress resource(s)"
    else
      log_warning "No Ingress resources found"
    fi
  else
    log_warning "Ingress API not available"
  fi
}

verify_load_balancer() {
  log_info "Verifying Network Load Balancer..."
  
  local nlb=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}')
  
  if [ -n "$nlb" ]; then
    log_success "Network Load Balancer endpoint: $nlb"
  else
    log_warning "No LoadBalancer service found or endpoint not assigned yet"
  fi
}

verify_pod_logs() {
  log_info "Verifying pod logs for errors..."
  
  local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$pods" ]; then
    log_warning "No pods found in namespace '$NAMESPACE'"
    return 0
  fi
  
  local has_errors=false
  for pod in $pods; do
    local error_count=$(kubectl logs "$pod" -n "$NAMESPACE" 2>/dev/null | grep -i "error\|exception\|fatal" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
      log_warning "Pod '$pod' has $error_count error(s) in logs"
      has_errors=true
    else
      log_success "Pod '$pod' logs are clean"
    fi
  done
  
  return $([ "$has_errors" = false ] && echo 0 || echo 1)
}

verify_resource_limits() {
  log_info "Verifying resource limits are configured..."
  
  local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$pods" ]; then
    log_warning "No pods found in namespace '$NAMESPACE'"
    return 0
  fi
  
  local all_configured=true
  for pod in $pods; do
    local limits=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].resources.limits}')
    
    if [ -n "$limits" ] && [ "$limits" != "{}" ]; then
      log_success "Pod '$pod' has resource limits configured"
    else
      log_warning "Pod '$pod' does not have resource limits configured"
      all_configured=false
    fi
  done
  
  return $([ "$all_configured" = true ] && echo 0 || echo 1)
}

verify_health_endpoints() {
  log_info "Verifying health check endpoints..."
  
  local health_endpoints=(
    "https://api.cloudtolocalllm.online/health"
    "https://app.cloudtolocalllm.online/health"
  )
  
  local all_healthy=true
  for endpoint in "${health_endpoints[@]}"; do
    if timeout 5 curl -s -k "$endpoint" | grep -q "ok\|healthy\|running" 2>/dev/null; then
      log_success "Health endpoint '$endpoint' is responding"
    else
      log_warning "Health endpoint '$endpoint' is not responding or unreachable"
      all_healthy=false
    fi
  done
  
  return $([ "$all_healthy" = true ] && echo 0 || echo 1)
}

##############################################################################
# Main Execution
##############################################################################

main() {
  echo ""
  echo "=========================================="
  echo "AWS EKS Deployment Verification"
  echo "=========================================="
  echo "Environment: $ENVIRONMENT"
  echo "Namespace: $NAMESPACE"
  echo "Cluster: $CLUSTER_NAME"
  echo "Region: $REGION"
  echo ""
  
  # Run all verification checks
  verify_cluster_connectivity || true
  verify_namespace_exists || true
  verify_pods_running || true
  verify_pod_readiness || true
  verify_services_accessible || true
  verify_ingress_configured || true
  verify_load_balancer || true
  verify_dns_resolution || true
  verify_ssl_certificates || true
  verify_pod_logs || true
  verify_resource_limits || true
  verify_health_endpoints || true
  
  # Print summary
  echo ""
  echo "=========================================="
  echo "Verification Summary"
  echo "=========================================="
  echo -e "${GREEN}Passed: $PASSED${NC}"
  echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
  echo -e "${RED}Failed: $FAILED${NC}"
  echo ""
  
  if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    return 0
  else
    echo -e "${RED}✗ Some checks failed. Please review the output above.${NC}"
    return 1
  fi
}

# Run main function
main "$@"
