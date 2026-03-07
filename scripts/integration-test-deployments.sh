#!/bin/bash
# ArgoCD Integration Test Script
# End-to-end testing for deployment scenarios and failure recovery
# Tests full deployment cycles, concurrent operations, and disaster recovery
# Usage: ./integration-test-deployments.sh [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="CloudToLocalLLM"
TEST_NAMESPACE="argocd-integration-test"
LOG_FILE="/var/log/integration-test-deployments.log"
REPORT_FILE="/tmp/integration-test-report-$(date +%Y%m%d_%H%M%S).json"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

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

# Function to setup test environment
setup_test_environment() {
    log "=== Setting Up Test Environment ==="

    # Create test namespace if it doesn't exist
    if ! kubectl get namespace $TEST_NAMESPACE &> /dev/null; then
        kubectl create namespace $TEST_NAMESPACE
        test_passed "test_namespace_created"
    else
        test_passed "test_namespace_exists"
    fi

    # Create test application
    cat > /tmp/test-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-integration-app
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/name: test-integration-app
    test: integration
spec:
  project: default
  source:
    repoURL: https://github.com/CloudToLocalLLM-online/CloudToLocalLLM
    targetRevision: main
    path: k8s/apps/local/api-backend/shared/base
  destination:
    server: https://kubernetes.default.svc
    namespace: $TEST_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

    kubectl apply -f /tmp/test-app.yaml
    test_passed "test_application_created"

    success "Test environment setup completed"
}

# Function to cleanup test environment
cleanup_test_environment() {
    log "=== Cleaning Up Test Environment ==="

    # Delete test application
    kubectl delete application test-integration-app -n $ARGOCD_NAMESPACE --ignore-not-found=true

    # Delete test namespace
    kubectl delete namespace $TEST_NAMESPACE --ignore-not-found=true

    # Clean up temporary files
    rm -f /tmp/test-app.yaml

    success "Test environment cleanup completed"
}

# Function to test full deployment cycle
test_full_deployment_cycle() {
    log "=== Testing Full Deployment Cycle ==="

    # Setup test environment
    setup_test_environment

    # Test application creation
    if kubectl get application test-integration-app -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_passed "application_creation"
    else
        test_failed "application_creation" "Test application not created"
        cleanup_test_environment
        return 1
    fi

    # Test initial sync
    argocd app sync test-integration-app
    argocd app wait test-integration-app --timeout 300

    local sync_status=$(argocd app get test-integration-app --output json | jq -r '.status.sync.status')
    if [ "$sync_status" = "Synced" ]; then
        test_passed "initial_sync_success"
    else
        test_failed "initial_sync_success" "Initial sync failed with status: $sync_status"
    fi

    # Test application health
    local health_status=$(argocd app get test-integration-app --output json | jq -r '.status.health.status')
    if [ "$health_status" = "Healthy" ]; then
        test_passed "application_health"
    else
        test_failed "application_health" "Application health check failed with status: $health_status"
    fi

    # Test resource creation
    local pod_count=$(kubectl get pods -n $TEST_NAMESPACE --no-headers | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        test_passed "resources_created"
    else
        test_failed "resources_created" "No pods created in test namespace"
    fi

    # Test configuration update
    argocd app set test-integration-app --revision HEAD~1 2>/dev/null || true
    argocd app sync test-integration-app
    argocd app wait test-integration-app --timeout 300

    local updated_sync_status=$(argocd app get test-integration-app --output json | jq -r '.status.sync.status')
    if [ "$updated_sync_status" = "Synced" ]; then
        test_passed "configuration_update"
    else
        test_failed "configuration_update" "Configuration update failed"
    fi

    # Cleanup
    cleanup_test_environment

    success "Full deployment cycle testing completed"
}

# Function to test failure recovery
test_failure_recovery() {
    log "=== Testing Failure Recovery ==="

    # Setup test environment
    setup_test_environment

    # Test sync failure recovery
    log "Testing sync failure recovery..."

    # Simulate sync failure by deleting a required resource
    kubectl delete deployment api-backend -n $TEST_NAMESPACE --ignore-not-found=true

    # Wait for ArgoCD to detect and recover
    sleep 30

    # Check if ArgoCD self-healed
    local pod_count=$(kubectl get pods -n $TEST_NAMESPACE --no-headers | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        test_passed "sync_failure_recovery"
    else
        test_failed "sync_failure_recovery" "Self-healing did not restore resources"
    fi

    # Test manual sync recovery
    argocd app sync test-integration-app --force
    argocd app wait test-integration-app --timeout 300

    local recovery_status=$(argocd app get test-integration-app --output json | jq -r '.status.sync.status')
    if [ "$recovery_status" = "Synced" ]; then
        test_passed "manual_sync_recovery"
    else
        test_failed "manual_sync_recovery" "Manual sync recovery failed"
    fi

    # Cleanup
    cleanup_test_environment

    success "Failure recovery testing completed"
}

# Function to test concurrent operations
test_concurrent_operations() {
    log "=== Testing Concurrent Operations ==="

    # Setup test environment
    setup_test_environment

    # Create multiple test applications
    for i in {1..3}; do
        cat > /tmp/test-app-$i.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-concurrent-app-$i
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/name: test-concurrent-app-$i
    test: concurrent
spec:
  project: default
  source:
    repoURL: https://github.com/CloudToLocalLLM-online/CloudToLocalLLM
    targetRevision: main
    path: k8s/apps/local/api-backend/shared/base
  destination:
    server: https://kubernetes.default.svc
    namespace: $TEST_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
        kubectl apply -f /tmp/test-app-$i.yaml
    done

    # Test concurrent sync
    log "Testing concurrent application sync..."
    for i in {1..3}; do
        argocd app sync test-concurrent-app-$i &
    done

    # Wait for all syncs to complete
    wait

    # Check all applications synced successfully
    local failed_syncs=0
    for i in {1..3}; do
        local status=$(argocd app get test-concurrent-app-$i --output json | jq -r '.status.sync.status')
        if [ "$status" != "Synced" ]; then
            failed_syncs=$((failed_syncs + 1))
        fi
    done

    if [ "$failed_syncs" -eq 0 ]; then
        test_passed "concurrent_sync_success"
    else
        test_failed "concurrent_sync_success" "$failed_syncs applications failed to sync concurrently"
    fi

    # Test concurrent resource creation
    local total_pods=$(kubectl get pods -n $TEST_NAMESPACE --no-headers | wc -l)
    if [ "$total_pods" -ge 3 ]; then
        test_passed "concurrent_resource_creation"
    else
        test_failed "concurrent_resource_creation" "Expected 3+ pods, got $total_pods"
    fi

    # Cleanup
    for i in {1..3}; do
        kubectl delete application test-concurrent-app-$i -n $ARGOCD_NAMESPACE --ignore-not-found=true
        rm -f /tmp/test-app-$i.yaml
    done
    cleanup_test_environment

    success "Concurrent operations testing completed"
}

# Function to test load scenarios
test_load_scenarios() {
    log "=== Testing Load Scenarios ==="

    # Setup test environment
    setup_test_environment

    # Test high-frequency sync operations
    log "Testing high-frequency sync operations..."

    local sync_count=0
    local success_count=0

    for i in {1..5}; do
        argocd app sync test-integration-app --force
        argocd app wait test-integration-app --timeout 300

        local status=$(argocd app get test-integration-app --output json | jq -r '.status.sync.status')
        sync_count=$((sync_count + 1))

        if [ "$status" = "Synced" ]; then
            success_count=$((success_count + 1))
        fi

        # Brief pause between syncs
        sleep 5
    done

    if [ "$success_count" -eq "$sync_count" ]; then
        test_passed "high_frequency_sync"
    else
        test_failed "high_frequency_sync" "Only $success_count/$sync_count high-frequency syncs succeeded"
    fi

    # Test resource scaling
    log "Testing resource scaling..."

    # Scale up application
    kubectl scale deployment api-backend -n $TEST_NAMESPACE --replicas=3

    # Wait for scaling
    sleep 30

    local scaled_pods=$(kubectl get pods -n $TEST_NAMESPACE -l app=api-backend --no-headers | wc -l)
    if [ "$scaled_pods" -eq 3 ]; then
        test_passed "resource_scaling_up"
    else
        test_failed "resource_scaling_up" "Expected 3 pods after scaling, got $scaled_pods"
    fi

    # Scale down
    kubectl scale deployment api-backend -n $TEST_NAMESPACE --replicas=1
    sleep 30

    local scaled_down_pods=$(kubectl get pods -n $TEST_NAMESPACE -l app=api-backend --no-headers | wc -l)
    if [ "$scaled_down_pods" -eq 1 ]; then
        test_passed "resource_scaling_down"
    else
        test_failed "resource_scaling_down" "Expected 1 pod after scaling down, got $scaled_down_pods"
    fi

    # Cleanup
    cleanup_test_environment

    success "Load scenarios testing completed"
}

# Function to test end-to-end deployment
test_e2e_deployment() {
    log "=== Testing End-to-End Deployment ==="

    # This test simulates the complete deployment SOP
    if [ -f "./scripts/deployment-sop.sh" ]; then
        # Test dry run
        if ./scripts/deployment-sop.sh -e test -a api-backend --dry-run; then
            test_passed "e2e_dry_run_success"
        else
            test_failed "e2e_dry_run_success" "Dry run failed"
        fi

        # Test actual deployment (in test environment)
        if ./scripts/deployment-sop.sh -e test -a api-backend; then
            test_passed "e2e_deployment_success"
        else
            test_failed "e2e_deployment_success" "End-to-end deployment failed"
        fi
    else
        test_skipped "e2e_deployment" "Deployment SOP script not found"
    fi

    success "End-to-end deployment testing completed"
}

# Function to verify tunnel-only ingress policy
test_tunnel_only_ingress_policy() {
    log "=== Testing Tunnel-Only Ingress Policy ==="

    if [ -f "./scripts/verify-k8s-tunnel-only.sh" ]; then
        if ./scripts/verify-k8s-tunnel-only.sh; then
            test_passed "tunnel_only_ingress_policy"
        else
            test_failed "tunnel_only_ingress_policy" "Tunnel-only ingress verification failed"
        fi
    else
        test_skipped "tunnel_only_ingress_policy" "scripts/verify-k8s-tunnel-only.sh not found"
    fi

    success "Tunnel-only ingress policy testing completed"
}

# Function to test disaster recovery
test_disaster_recovery() {
    log "=== Testing Disaster Recovery ==="

    # Create backup first
    if [ -f "./scripts/argocd-backup-restore.sh" ]; then
        ./scripts/argocd-backup-restore.sh backup --test-mode
        test_passed "backup_creation_success"
    else
        test_failed "backup_creation_success" "Backup script not found"
        return 1
    fi

    # Simulate disaster - delete ArgoCD namespace
    log "Simulating ArgoCD disaster..."
    kubectl delete namespace $ARGOCD_NAMESPACE --ignore-not-found=true

    # Wait for deletion
    sleep 30

    # Attempt recovery
    if ./scripts/argocd-backup-restore.sh restore /backup/argocd/*/ --disaster-recovery; then
        test_passed "disaster_recovery_success"
    else
        test_failed "disaster_recovery_success" "Disaster recovery failed"
    fi

    # Verify recovery
    if kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
        test_passed "argocd_namespace_restored"
    else
        test_failed "argocd_namespace_restored" "ArgoCD namespace not restored"
    fi

    # Check applications are back
    local app_count=$(kubectl get applications -n $ARGOCD_NAMESPACE --no-headers | wc -l)
    if [ "$app_count" -gt 0 ]; then
        test_passed "applications_restored"
    else
        test_failed "applications_restored" "No applications restored"
    fi

    success "Disaster recovery testing completed"
}

# Function to run full integration test suite
run_full_integration_suite() {
    log "=== Running Full Integration Test Suite ==="

    test_full_deployment_cycle
    test_failure_recovery
    test_concurrent_operations
    test_load_scenarios
    test_e2e_deployment
    test_tunnel_only_ingress_policy
    test_disaster_recovery

    success "Full integration test suite completed"
}

# Function to generate integration test report
generate_integration_report() {
    log "=== Generating Integration Test Report ==="

    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    cat > $REPORT_FILE << EOF
{
  "integration_test_summary": {
    "timestamp": "$DATE",
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "skipped_tests": $SKIPPED_TESTS,
    "success_rate": $success_rate
  },
  "test_categories": {
    "full_deployment_cycle": "tests complete deployment workflow",
    "failure_recovery": "tests automatic and manual recovery",
    "concurrent_operations": "tests multiple simultaneous operations",
    "load_scenarios": "tests performance under load",
    "e2e_deployment": "tests end-to-end deployment SOP",
    "disaster_recovery": "tests complete system recovery"
  },
  "critical_findings": [
    $(if [ $FAILED_TESTS -gt 0 ]; then echo "\"$FAILED_TESTS integration tests failed - critical issues detected\""; fi)
    $(if [ $success_rate -lt 100 ]; then echo "\"Integration test success rate: ${success_rate}% - below required 100%\""; fi)
    $(if [ $SKIPPED_TESTS -gt 0 ]; then echo "\"$SKIPPED_TESTS tests were skipped - incomplete test coverage\""; fi)
  ],
  "production_readiness": $([ $success_rate -eq 100 ] && [ $FAILED_TESTS -eq 0 ] && echo "true" || echo "false")
}
EOF

    success "Integration test report generated: $REPORT_FILE"

    # Display summary
    log "=== Integration Test Summary ==="
    log "Total Tests: $TOTAL_TESTS"
    log "Passed: $PASSED_TESTS"
    log "Failed: $FAILED_TESTS"
    log "Skipped: $SKIPPED_TESTS"
    log "Success Rate: ${success_rate}%"

    if [ $success_rate -eq 100 ] && [ $FAILED_TESTS -eq 0 ]; then
        success "🎉 ALL INTEGRATION TESTS PASSED! System is production-ready."
    else
        error "❌ INTEGRATION TEST FAILURES! DO NOT PROCEED TO PRODUCTION."
        error "Failed Tests: $FAILED_TESTS"
        error "Success Rate: ${success_rate}% (Required: 100%)"
        return 1
    fi
}

# Main execution function
main() {
    log "=== ArgoCD Integration Testing Started ==="

    # Parse command line arguments
    local run_full_suite=false
    local run_e2e=false
    local run_failure_recovery=false
    local run_concurrent=false
    local run_tunnel_only=false
    local generate_report=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --full-suite)
                run_full_suite=true
                shift
                ;;
            --e2e-deployment)
                run_e2e=true
                shift
                ;;
            --failure-recovery)
                run_failure_recovery=true
                shift
                ;;
            --concurrent-deployments)
                run_concurrent=true
                shift
                ;;
            --tunnel-only-checks)
                run_tunnel_only=true
                shift
                ;;
            --integration-tests)
                run_full_suite=true
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
                echo "  --full-suite              Run complete integration test suite"
                echo "  --e2e-deployment          Test end-to-end deployment workflow"
                echo "  --failure-recovery        Test failure recovery scenarios"
                echo "  --concurrent-deployments  Test concurrent deployment operations"
                echo "  --tunnel-only-checks      Verify tunnel-only ingress policy"
                echo "  --integration-tests       Run all integration tests with report"
                echo "  --generate-report         Generate detailed test report"
                echo "  --help                    Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Initialize log file
    echo "=== ArgoCD Integration Testing Started at $DATE ===" > $LOG_FILE

    # Determine what to run
    if [ "$run_full_suite" = true ] || [ $# -eq 0 ]; then
        run_full_integration_suite
        generate_report=true
    fi

    # Execute specific tests
    if [ "$run_e2e" = true ]; then
        test_e2e_deployment
    fi

    if [ "$run_failure_recovery" = true ]; then
        test_failure_recovery
    fi

    if [ "$run_concurrent" = true ]; then
        test_concurrent_operations
    fi

    if [ "$run_tunnel_only" = true ]; then
        test_tunnel_only_ingress_policy
    fi

    # Generate report if requested
    if [ "$generate_report" = true ]; then
        if ! generate_integration_report; then
            exit 1
        fi
    fi

    # Final status
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    if [ $success_rate -eq 100 ] && [ $FAILED_TESTS -eq 0 ]; then
        success "All integration tests completed successfully"
        exit 0
    else
        error "Integration tests completed with failures"
        error "Success Rate: ${success_rate}% | Failed Tests: $FAILED_TESTS"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
