#!/bin/bash
# Domain Routing Fix Script for CloudToLocalLLM
# Automatically fixes common domain routing issues
# Addresses service mismatches, tunnel configuration, and connectivity problems
# Usage: ./fix-domain-routing.sh [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="cloudtolocalllm"
LOG_FILE="./fix-domain-routing.log"
BACKUP_DIR="./backup/domain-routing-$(date +%Y%m%d_%H%M%S)"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

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

# Function to create backup
create_backup() {
    log "=== Creating Backup ==="

    mkdir -p $BACKUP_DIR

    # Backup current tunnel configuration
    kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE -o yaml > $BACKUP_DIR/cloudflared-config.yaml 2>/dev/null || true

    # Backup service configurations
    kubectl get svc -n $CLOUDTOLOCLLM_NAMESPACE -o yaml > $BACKUP_DIR/services.yaml

    # Backup deployment configurations
    kubectl get deployments -n $CLOUDTOLOCLLM_NAMESPACE -o yaml > $BACKUP_DIR/deployments.yaml

    success "Backup created in: $BACKUP_DIR"
}

# Function to fix service port mismatches
fix_service_ports() {
    log "=== Fixing Service Port Mismatches ==="

    # Expected service configurations
    declare -A expected_ports=(
        ["web"]="8080"
        ["api-backend"]="8080"
        ["streaming-proxy"]="3001"
    )

    local fixes_applied=0

    for service in "${!expected_ports[@]}"; do
        local expected_port=${expected_ports[$service]}

        if kubectl get svc $service -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
            local current_port=$(kubectl get svc $service -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath="{.spec.ports[0].port}")

            if [ "$current_port" != "$expected_port" ]; then
                warning "Service $service port mismatch: current=$current_port, expected=$expected_port"

                # Create corrected service spec
                cat > /tmp/${service}-fix.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: $service
  namespace: $CLOUDTOLOCLLM_NAMESPACE
spec:
  ports:
  - port: $expected_port
    targetPort: $expected_port
    protocol: TCP
    name: http
  selector:
    app: $service
  type: ClusterIP
EOF

                kubectl apply -f /tmp/${service}-fix.yaml
                success "Fixed service $service port to $expected_port"
                fixes_applied=$((fixes_applied + 1))

                rm -f /tmp/${service}-fix.yaml
            else
                log "Service $service port is correct: $current_port"
            fi
        else
            warning "Service $service not found, skipping"
        fi
    done

    success "Applied $fixes_applied service port fixes"
}

# Function to fix missing services
fix_missing_services() {
    log "=== Fixing Missing Services ==="

    # Required services
    local required_services=("web" "api-backend" "streaming-proxy")

    local services_created=0

    for service in "${required_services[@]}"; do
        if ! kubectl get svc $service -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
            warning "Service $service is missing, creating..."

            # Determine port based on service
            local port="8080"
            if [ "$service" = "streaming-proxy" ]; then
                port="3001"
            fi

            # Create service
            cat > /tmp/${service}-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: $service
  namespace: $CLOUDTOLOCLLM_NAMESPACE
  labels:
    app: $service
spec:
  ports:
  - port: $port
    targetPort: $port
    protocol: TCP
    name: http
  selector:
    app: $service
  type: ClusterIP
EOF

            kubectl apply -f /tmp/${service}-service.yaml
            success "Created missing service: $service"
            services_created=$((services_created + 1))

            rm -f /tmp/${service}-service.yaml
        else
            log "Service $service already exists"
        fi
    done

    success "Created $services_created missing services"
}

# Function to fix Cloudflare tunnel configuration
fix_tunnel_configuration() {
    log "=== Fixing Cloudflare Tunnel Configuration ==="

    # Check if tunnel configuration exists
    if ! kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
        warning "Cloudflared config not found, creating..."

        # Create corrected tunnel configuration
        cat > /tmp/cloudflared-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: $CLOUDTOLOCLLM_NAMESPACE
data:
  config.yaml: |
    tunnel: 62da6c19-947b-4bf6-acad-100a73de4e0d
    metrics: 0.0.0.0:2000
    no-autoupdate: true
    ingress:
      # App Subdomain - Streaming Proxy (WS)
      - hostname: app.cloudtolocalllm.online
        path: /ws
        service: http://streaming-proxy.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:3001

      # App Subdomain - Streaming Proxy (API)
      - hostname: app.cloudtolocalllm.online
        path: /api/tunnel
        service: http://streaming-proxy.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:3001

      # App Subdomain - API Backend Health
      - hostname: app.cloudtolocalllm.online
        path: /health
        service: http://api-backend.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:8080

      # App Subdomain - API Backend
      - hostname: app.cloudtolocalllm.online
        path: /api
        service: http://api-backend.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:8080

      # App Subdomain - Web Frontend (Root)
      - hostname: app.cloudtolocalllm.online
        service: http://web.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:8080

      # API Subdomain - API Backend Health
      - hostname: api.cloudtolocalllm.online
        path: /health
        service: http://api-backend.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:8080

      # API Subdomain - API Backend (Root)
      - hostname: api.cloudtolocalllm.online
        service: http://api-backend.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:8080

      # Argo CD UI
      - hostname: argocd.cloudtolocalllm.online
        service: http://argocd-server.$ARGOCD_NAMESPACE.svc.cluster.local:80

      # Grafana UI
      - hostname: grafana.cloudtolocalllm.online
        service: http://grafana.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:3000

      # Root Domain - Web Frontend
      - hostname: cloudtolocalllm.online
        service: http://web.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local:8080

      # Catch-all 404
      - service: http_status:404
EOF

        kubectl apply -f /tmp/cloudflared-config.yaml
        success "Created Cloudflare tunnel configuration"

        rm -f /tmp/cloudflared-config.yaml
    else
        log "Cloudflared config already exists, checking for updates..."

        # Check if configuration needs updating
        local current_config=$(kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath='{.data.config\.yaml}')

        # Check for common issues in current config
        if ! echo "$current_config" | grep -q "streaming-proxy.$CLOUDTOLOCLLM_NAMESPACE.svc.cluster.local"; then
            warning "Tunnel config missing correct service references, updating..."

            # Update the configuration
            kubectl patch configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE --type merge -p '{
              "data": {
                "config.yaml": "tunnel: 62da6c19-947b-4bf6-acad-100a73de4e0d\nmetrics: 0.0.0.0:2000\nno-autoupdate: true\ningress:\n  # App Subdomain - Streaming Proxy (WS)\n  - hostname: app.cloudtolocalllm.online\n    path: /ws\n    service: http://streaming-proxy.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:3001\n  \n  # App Subdomain - Streaming Proxy (API)\n  - hostname: app.cloudtolocalllm.online\n    path: /api/tunnel\n    service: http://streaming-proxy.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:3001\n  \n  # App Subdomain - API Backend Health\n  - hostname: app.cloudtolocalllm.online\n    path: /health\n    service: http://api-backend.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:8080\n \n  # App Subdomain - API Backend\n  - hostname: app.cloudtolocalllm.online\n    path: /api\n    service: http://api-backend.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:8080\n \n  # App Subdomain - Web Frontend (Root)\n  - hostname: app.cloudtolocalllm.online\n    service: http://web.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:8080\n \n  # API Subdomain - API Backend Health\n  - hostname: api.cloudtolocalllm.online\n    path: /health\n    service: http://api-backend.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:8080\n \n  # API Subdomain - API Backend (Root)\n  - hostname: api.cloudtolocalllm.online\n    service: http://api-backend.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:8080\n   \n  # Argo CD UI\n  - hostname: argocd.cloudtolocalllm.online\n    service: http://argocd-server.'$ARGOCD_NAMESPACE'.svc.cluster.local:80\n \n  # Grafana UI\n  - hostname: grafana.cloudtolocalllm.online\n    service: http://grafana.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:3000\n \n  # Root Domain - Web Frontend\n  - hostname: cloudtolocalllm.online\n    service: http://web.'$CLOUDTOLOCLLM_NAMESPACE'.svc.cluster.local:8080\n   \n  # Catch-all 404\n  - service: http_status:404\n"
              }
            }'

            success "Updated Cloudflare tunnel configuration"
        else
            log "Tunnel configuration appears correct"
        fi
    fi
}

# Function to restart Cloudflare tunnel
restart_tunnel() {
    log "=== Restarting Cloudflare Tunnel ==="

    # Check if tunnel deployment exists
    if kubectl get deployment cloudflared -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
        log "Restarting cloudflared deployment..."
        kubectl rollout restart deployment/cloudflared -n $CLOUDTOLOCLLM_NAMESPACE

        # Wait for rollout to complete
        kubectl rollout status deployment/cloudflared -n $CLOUDTOLOCLLM_NAMESPACE --timeout=300s

        # Verify tunnel is running
        local running_pods=$(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers | wc -l)

        if [ "$running_pods" -gt 0 ]; then
            success "Cloudflare tunnel restarted successfully ($running_pods pods running)"
        else
            error "Cloudflare tunnel failed to restart"
            return 1
        fi
    else
        warning "Cloudflared deployment not found, skipping restart"
    fi
}

# Function to fix network policies
fix_network_policies() {
    log "=== Fixing Network Policies ==="

    # Check for overly restrictive policies
    local restrictive_policies=$(kubectl get networkpolicies -n $CLOUDTOLOCLLM_NAMESPACE --no-headers | wc -l)

    if [ "$restrictive_policies" -gt 0 ]; then
        warning "Found network policies that may block tunnel traffic"

        # Create a permissive network policy for tunnel traffic
        cat > /tmp/tunnel-network-policy.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-tunnel-traffic
  namespace: $CLOUDTOLOCLLM_NAMESPACE
spec:
  podSelector:
    matchLabels:
      app: cloudflared
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 3001
EOF

        kubectl apply -f /tmp/tunnel-network-policy.yaml
        success "Created permissive network policy for tunnel traffic"

        rm -f /tmp/tunnel-network-policy.yaml
    else
        log "No restrictive network policies found"
    fi
}

# Function to validate fixes
validate_fixes() {
    log "=== Validating Domain Routing Fixes ==="

    local validation_passed=0
    local validation_total=0

    # Test 1: Check services exist and have correct ports
    validation_total=$((validation_total + 1))
    local services_ok=true

    for service in web api-backend streaming-proxy; do
        if kubectl get svc $service -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
            local port=$(kubectl get svc $service -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath="{.spec.ports[0].port}")
            local expected_port="8080"
            [ "$service" = "streaming-proxy" ] && expected_port="3001"

            if [ "$port" = "$expected_port" ]; then
                log "✓ Service $service port correct: $port"
            else
                error "✗ Service $service port incorrect: expected $expected_port, got $port"
                services_ok=false
            fi
        else
            error "✗ Service $service not found"
            services_ok=false
        fi
    done

    if [ "$services_ok" = true ]; then
        validation_passed=$((validation_passed + 1))
        success "Service validation passed"
    fi

    # Test 2: Check tunnel configuration
    validation_total=$((validation_total + 1))
    if kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE &> /dev/null; then
        local config_valid=$(kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE -o jsonpath='{.data.config\.yaml}' | grep -c "svc.cluster.local")
        if [ "$config_valid" -gt 5 ]; then
            validation_passed=$((validation_passed + 1))
            success "Tunnel configuration validation passed"
        else
            error "Tunnel configuration appears incomplete"
        fi
    else
        error "Tunnel configuration not found"
    fi

    # Test 3: Check tunnel pods
    validation_total=$((validation_total + 1))
    local tunnel_pods=$(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers | wc -l)
    if [ "$tunnel_pods" -gt 0 ]; then
        validation_passed=$((validation_passed + 1))
        success "Tunnel pods validation passed ($tunnel_pods running)"
    else
        error "No tunnel pods running"
    fi

    # Calculate success rate
    local success_rate=$((validation_passed * 100 / validation_total))

    log "=== Validation Results ==="
    log "Passed: $validation_passed/$validation_total ($success_rate%)"

    if [ $success_rate -ge 80 ]; then
        success "🎉 Domain routing fixes validated successfully!"
        return 0
    else
        error "❌ Domain routing fixes validation failed - $((validation_total - validation_passed)) issues remain"
        return 1
    fi
}

# Function to generate fix report
generate_fix_report() {
    log "=== Generating Domain Routing Fix Report ==="

    local report_file="/tmp/domain-routing-fix-report-$(date +%Y%m%d_%H%M%S).json"

    cat > $report_file << EOF
{
  "domain_routing_fixes": {
    "timestamp": "$DATE",
    "backup_location": "$BACKUP_DIR",
    "fixes_applied": {
      "service_ports": "checked and corrected",
      "missing_services": "created if needed",
      "tunnel_configuration": "validated and updated",
      "tunnel_restart": "performed if necessary",
      "network_policies": "adjusted for tunnel traffic"
    },
    "current_status": {
      "services_correct": $(kubectl get svc -n $CLOUDTOLOCLLM_NAMESPACE --no-headers | wc -l),
      "tunnel_pods_running": $(kubectl get pods -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared --field-selector=status.phase=Running --no-headers | wc -l),
      "config_exists": $(kubectl get configmap cloudflared-config -n $CLOUDTOLOCLLM_NAMESPACE &>/dev/null && echo "true" || echo "false")
    },
    "next_steps": [
      "Test domain connectivity: curl https://app.cloudtolocalllm.online",
      "Check tunnel logs: kubectl logs -n $CLOUDTOLOCLLM_NAMESPACE -l app=cloudflared",
      "Verify DNS resolution: nslookup app.cloudtolocalllm.online",
      "Run diagnostic: ./scripts/domain-routing-diagnostic.sh --all-tests"
    ]
  }
}
EOF

    success "Fix report generated: $report_file"
    cat $report_file | jq '.' | tee -a $LOG_FILE
}

# Main execution function
main() {
    log "=== CloudToLocalLLM Domain Routing Fix Started ==="

    # Parse command line arguments
    local create_backup=true
    local fix_services=true
    local fix_tunnel=true
    local restart_tunnel=true
    local fix_network=true
    local validate_fixes=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-backup)
                create_backup=false
                shift
                ;;
            --services-only)
                fix_services=true
                fix_tunnel=false
                restart_tunnel=false
                fix_network=false
                shift
                ;;
            --tunnel-only)
                fix_services=false
                fix_tunnel=true
                restart_tunnel=true
                fix_network=false
                shift
                ;;
            --validate-only)
                create_backup=false
                fix_services=false
                fix_tunnel=false
                restart_tunnel=false
                fix_network=false
                validate_fixes=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --no-backup      Skip backup creation"
                echo "  --services-only  Fix only service configurations"
                echo "  --tunnel-only    Fix only tunnel configuration"
                echo "  --validate-only  Only run validation, no fixes"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Initialize log file
    echo "=== CloudToLocalLLM Domain Routing Fix Started at $DATE ===" > $LOG_FILE

    # Create backup if requested
    if [ "$create_backup" = true ]; then
        create_backup
    fi

    # Apply fixes
    if [ "$fix_services" = true ]; then
        fix_service_ports
        fix_missing_services
    fi

    if [ "$fix_tunnel" = true ]; then
        fix_tunnel_configuration
    fi

    if [ "$restart_tunnel" = true ]; then
        restart_tunnel
    fi

    if [ "$fix_network" = true ]; then
        fix_network_policies
    fi

    # Validate fixes
    if [ "$validate_fixes" = true ]; then
        if validate_fixes; then
            generate_fix_report
            success "Domain routing fixes completed successfully!"
            exit 0
        else
            error "Domain routing fixes validation failed!"
            exit 1
        fi
    fi

    success "Domain routing fix operations completed"
}

# Run main function with all arguments
main "$@"