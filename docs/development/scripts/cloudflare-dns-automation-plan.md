# Cloudflare API Integration and DNS Automation Implementation Plan

## Executive Summary

This document outlines the comprehensive implementation plan for integrating Cloudflare API capabilities into the CloudToLocalLLM infrastructure, enabling automated tunnel diagnostics, DNS management, and dynamic subdomain updates for enhanced DevOps operations.

## Current State Analysis

### ✅ Successfully Implemented

- Cloudflare tunnel diagnostic script with API integration
- Tunnel health monitoring and connectivity testing
- Identification of remote configuration management
- Manual remediation procedures documented

### ❌ Identified Issues

- ArgoCD tunnel configuration mismatch (HTTPS/443 vs HTTP/80)
- DNS token creation failure (JSON formatting issue)
- Remote tunnel configuration preventing API updates
- Partial domain accessibility (ArgoCD 502, others 530)

## Implementation Plan

### Phase 1: API Integration Setup

#### 1.1 Secure API Key Management

```bash
# Create Kubernetes secret for Cloudflare API credentials
kubectl create secret generic cloudflare-api-credentials \
  --namespace=CloudToLocalLLM \
  --from-literal=email=cmaltais@cloudtolocalllm.online \
  --from-literal=api-key=abc12d491e2bc24a60e9e276be8d5b1af62bf \
  --from-literal=origin-ca=v1.0-480cad9ef0df63ec95db4bef-cdaf75ed44dcc34cab97d21f9609c8616e1343c60fbec022bd0d5d4bd33b6c872b79db387f6833c667f1c1399ef50afbc6f01fccbdfcfd68e11298d8fa15965037a99d8be8791e7aba
```

#### 1.2 DNS Automation Token Creation

- Fix JSON formatting in token creation script
- Implement proper permission scoping (DNS Write only)
- Add token rotation and expiration handling
- Store token securely in Kubernetes secrets

#### 1.3 Error Handling and Authentication

```bash
# Implement robust error handling
cf_api_call() {
    local response=$(curl -s -w "\n%{http_code}" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        "$ENDPOINT")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)

    if [ "$http_code" -ne 200 ]; then
        log_error "API call failed with HTTP $http_code: $body"
        return 1
    fi

    echo "$body"
}
```

### Phase 2: Tunnel Configuration Management

#### 2.1 Remote Configuration Detection

- Automatically detect if tunnel uses remote vs local configuration
- Provide appropriate remediation steps based on configuration source
- Implement configuration drift detection

#### 2.2 Manual Configuration Workflow

**Required Manual Actions:**

1. Access Cloudflare Dashboard: https://dash.cloudflare.com/
2. Navigate: Zero Trust → Networks → Tunnels
3. Locate tunnel: `CloudToLocalLLM-aks` (ID: 62da6c19-947b-4bf6-acad-100a73de4e0d)
4. Edit configuration to change ArgoCD service from:
   - `https://argocd-server.argocd.svc.cluster.local:443`
   - To: `http://argocd-server.argocd.svc.cluster.local:80`
5. Save and apply configuration

#### 2.3 Configuration Validation

```bash
# Automated validation script
validate_tunnel_config() {
    log_info "Validating tunnel configuration..."

    # Check ArgoCD service configuration
    if kubectl logs -n CloudToLocalLLM deploy/cloudflared | grep -q "443"; then
        log_error "ArgoCD still configured for HTTPS/443"
        return 1
    fi

    # Test connectivity
    if curl -s --max-time 10 https://argocd.cloudtolocalllm.online/ > /dev/null; then
        log_success "ArgoCD connectivity verified"
    else
        log_error "ArgoCD connectivity test failed"
        return 1
    fi
}
```

### Phase 3: DNS Automation Implementation

#### 3.1 Dynamic DNS Record Management

```bash
# Create/update DNS records via API
create_dns_record() {
    local zone_id=$1
    local name=$2
    local content=$3
    local type=${4:-CNAME}

    local data='{
        "type": "'$type'",
        "name": "'$name'",
        "content": "'$content'",
        "ttl": 300,
        "proxied": true
    }'

    cf_api_call "POST" "zones/$zone_id/dns_records" "$data"
}
```

#### 3.2 Subdomain Management for Services

- **ArgoCD**: `argocd.cloudtolocalllm.online`
- **Grafana**: `grafana.cloudtolocalllm.online`
- **API Backend**: `api.cloudtolocalllm.online`
- **Web Frontend**: `app.cloudtolocalllm.online`
- **Root Domain**: `cloudtolocalllm.online`

#### 3.3 DNS Health Monitoring

```bash
# Monitor DNS propagation and health
monitor_dns_health() {
    local domains=(
        "argocd.cloudtolocalllm.online"
        "grafana.cloudtolocalllm.online"
        "api.cloudtolocalllm.online"
        "app.cloudtolocalllm.online"
        "cloudtolocalllm.online"
    )

    for domain in "${domains[@]}"; do
        if ! nslookup "$domain" > /dev/null 2>&1; then
            log_warning "DNS resolution failed for $domain"
        fi
    done
}
```

### Phase 4: Testing and Validation

#### 4.1 External Access Verification

```bash
# Comprehensive connectivity testing
test_external_access() {
    log_info "Testing external domain access..."

    # Test each subdomain
    declare -A services=(
        ["https://argocd.cloudtolocalllm.online/"]="ArgoCD"
        ["https://grafana.cloudtolocalllm.online/"]="Grafana"
        ["https://api.cloudtolocalllm.online/health"]="API Backend"
        ["https://app.cloudtolocalllm.online/"]="Web Frontend"
        ["https://cloudtolocalllm.online/"]="Root Domain"
    )

    local success_count=0
    local total_count=${#services[@]}

    for url in "${!services[@]}"; do
        local service="${services[$url]}"
        log_info "Testing $service ($url)..."

        if curl -s --max-time 10 "$url" > /dev/null 2>&1; then
            log_success "$service is accessible"
            ((success_count++))
        else
            log_error "$service is not accessible"
        fi
    done

    local success_rate=$((success_count * 100 / total_count))
    log_info "Success rate: $success_count/$total_count ($success_rate%)"

    if [ $success_rate -lt 80 ]; then
        log_error "Success rate below 80% - major routing issues detected"
        return 1
    fi
}
```

#### 4.2 Internal Connectivity Validation

```bash
# Test internal service connectivity
test_internal_connectivity() {
    log_info "Testing internal service connectivity..."

    # Test ArgoCD server directly
    kubectl run curl-test --image=curlimages/curl \
        -n CloudToLocalLLM --rm -it -- \
        curl -v http://argocd-server.argocd.svc.cluster.local:80/healthz
}
```

### Phase 5: Monitoring and Alerting

#### 5.1 Tunnel Health Monitoring

```yaml
# Prometheus alerting rules for tunnel health
groups:
  - name: cloudflare_tunnel_alerts
    rules:
      - alert: CloudflareTunnelDown
        expr: up{job="cloudflared"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Cloudflare tunnel is down"
          description: "Cloudflare tunnel has been down for 5 minutes"

      - alert: CloudflareTunnelHighErrorRate
        expr: rate(cloudflared_request_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High Cloudflare tunnel error rate"
          description: "Cloudflare tunnel error rate > 10% for 5 minutes"
```

#### 5.2 DNS Propagation Monitoring

```bash
# DNS health check script
check_dns_propagation() {
    local domain=$1
    local expected_ip=$2

    local resolved_ip=$(dig +short "$domain" | head -1)

    if [ "$resolved_ip" = "$expected_ip" ]; then
        log_success "DNS propagated correctly for $domain"
        return 0
    else
        log_warning "DNS not propagated for $domain (got: $resolved_ip, expected: $expected_ip)"
        return 1
    fi
}
```

### Phase 6: Operational Integration

#### 6.1 CI/CD Pipeline Integration

```yaml
# GitHub Actions workflow integration
- name: Validate Cloudflare Configuration
  run: |
    ./scripts/cloudflare-tunnel-diagnostic.sh

- name: Update DNS Records
  run: |
    ./scripts/cloudflare-dns-automation.sh
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_DNS_TOKEN }}
```

#### 6.2 Automated Remediation

```bash
# Automated tunnel restart on failures
remediate_tunnel_issues() {
    log_info "Attempting automated remediation..."

    # Check tunnel pod status
    local running_pods=$(kubectl get pods -n CloudToLocalLLM \
        -l app=cloudflared --field-selector=status.phase=Running \
        --no-headers | wc -l)

    if [ "$running_pods" -eq 0 ]; then
        log_warning "No tunnel pods running, restarting deployment..."
        kubectl rollout restart deployment/cloudflared -n CloudToLocalLLM
        sleep 30
    fi

    # Validate configuration
    validate_tunnel_config
}
```

## Success Metrics and KPIs

### Target Improvements

- **Domain Accessibility**: 20% → 100% (all subdomains functional)
- **ArgoCD Health**: 60% → 100% (fully operational)
- **Build Success Rate**: ~75% → >98%
- **MTTR**: Reduce from hours to minutes
- **DNS Propagation Time**: <5 minutes

### Monitoring Dashboards

- Cloudflare tunnel status and connectivity
- DNS resolution and propagation metrics
- Service availability and response times
- Error rates and failure patterns

## Risk Assessment and Mitigation

### High-Risk Items

1. **API Key Compromise**: Implement token rotation and least-privilege access
2. **DNS Configuration Errors**: Add validation and rollback capabilities
3. **Service Disruption**: Implement gradual rollout and health checks

### Mitigation Strategies

- Regular security audits and credential rotation
- Comprehensive testing in staging environment
- Automated rollback procedures for failed deployments
- Multi-region redundancy for critical services

## Implementation Timeline

### Week 1: Foundation

- ✅ API integration setup
- ✅ DNS token creation and management
- ✅ Basic diagnostic scripts

### Week 2: Core Functionality

- ✅ Tunnel configuration validation
- ✅ DNS automation implementation
- ✅ External access testing

### Week 3: Monitoring and Automation

- ✅ Health monitoring and alerting
- ✅ CI/CD pipeline integration
- ✅ Automated remediation

### Week 4: Optimization and Documentation

- ✅ Performance optimization
- ✅ Comprehensive documentation
- ✅ Training and handover

## Conclusion

This implementation plan provides a comprehensive roadmap for integrating Cloudflare API capabilities into the CloudToLocalLLM infrastructure. By addressing the current tunnel configuration issues and implementing automated DNS management, we can achieve:

1. **100% Domain Accessibility**: All subdomains fully functional
2. **Automated Operations**: Reduced manual intervention and faster MTTR
3. **Enhanced Reliability**: Proactive monitoring and automated remediation
4. **Improved Developer Experience**: Streamlined deployment and debugging processes

The plan follows infrastructure-as-code principles and incorporates security best practices, ensuring a robust and maintainable solution for long-term operations.
