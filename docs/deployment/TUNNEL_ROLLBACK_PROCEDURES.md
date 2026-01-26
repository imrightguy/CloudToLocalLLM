# Simplified Tunnel System Rollback Procedures

## Overview

This document provides comprehensive rollback procedures for the Simplified Tunnel System deployment. These procedures ensure rapid recovery in case of deployment issues, maintaining system availability and user experience.

## Rollback Decision Matrix

### When to Rollback

**Immediate Rollback Required:**

- [ ] Critical security vulnerabilities discovered
- [ ] Complete system failure (>90% error rate)
- [ ] Data corruption or loss detected
- [ ] Authentication system compromised
- [ ] Performance degradation >500% from baseline

**Rollback Recommended:**

- [ ] Error rate >10% for >15 minutes
- [ ] User complaints about functionality loss
- [ ] Desktop client connection failures >50%
- [ ] Response time degradation >200% from baseline
- [ ] Memory leaks or resource exhaustion

**Monitor and Evaluate:**

- [ ] Error rate 5-10% for <15 minutes
- [ ] Minor performance degradation <100%
- [ ] Non-critical feature issues
- [ ] Cosmetic or UI issues

## Pre-Rollback Checklist

Before initiating rollback procedures:

1. **Assess Impact:**
   - [ ] Determine scope of issues
   - [ ] Identify affected users/systems
   - [ ] Estimate downtime requirements
   - [ ] Document current system state

2. **Gather Information:**
   - [ ] Collect error logs and metrics
   - [ ] Identify root cause if possible
   - [ ] Document reproduction steps
   - [ ] Capture system configuration

3. **Notify Stakeholders:**
   - [ ] Alert operations team
   - [ ] Notify development team
   - [ ] Prepare user communication
   - [ ] Update status page if applicable

4. **Prepare Rollback Environment:**
   - [ ] Verify backup integrity
   - [ ] Confirm rollback target version
   - [ ] Check rollback script functionality
   - [ ] Ensure necessary access permissions

## Rollback Procedures

### Phase 1: Emergency Rollback (Critical Issues)

**Timeline: 5-15 minutes**

#### 1.1 Immediate System Stabilization

**Stop New Deployments:**

```bash
# Disable CI/CD pipelines
# Stop any ongoing deployments
docker-compose down --remove-orphans

# Prevent new container starts
sudo systemctl stop docker  # If necessary for complete isolation
```

**Isolate Affected Services:**

```bash
# Stop problematic services immediately
docker-compose stop api-backend
docker-compose stop streaming-proxy

# Redirect traffic if possible
# Update load balancer to bypass affected services
```

#### 1.2 Revert API Backend

**Docker Compose Rollback:**

```bash
# Navigate to deployment directory
cd /opt/cloudtolocalllm

# Stop current services
docker-compose down api-backend

# Revert to previous version
git stash  # Save current changes
git checkout <previous_stable_commit>

# Rebuild and restart with previous version
docker-compose build api-backend
docker-compose up -d api-backend

# Verify service health
docker-compose ps
docker-compose logs api-backend
```

**Direct Deployment Rollback:**

```bash
# Stop current service
sudo systemctl stop cloudtolocalllm-api

# Revert code to previous version
cd /opt/cloudtolocalllm
git stash
git checkout <previous_stable_commit>

# Restore previous dependencies
cd api-backend
npm ci  # Install exact versions from package-lock.json

# Restart service
sudo systemctl start cloudtolocalllm-api
sudo systemctl status cloudtolocalllm-api
```

#### 1.3 Revert Nginx Configuration

```bash
# Restore previous nginx configuration
sudo cp /etc/nginx/sites-available/cloudtolocalllm.backup \
       /etc/nginx/sites-available/cloudtolocalllm

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Verify nginx status
sudo systemctl status nginx
```

#### 1.4 Verify Emergency Rollback

```bash
# Test basic connectivity
curl -I https://api.cloudtolocalllm.online/api/health

# Test legacy bridge endpoints (if applicable)
curl -I https://api.cloudtolocalllm.online/api/bridge/health

# Check WebSocket endpoints
wscat -c "wss://api.cloudtolocalllm.online/ws/bridge"

# Monitor error rates
tail -f /var/log/nginx/error.log
docker-compose logs -f api-backend
```

### Phase 2: Comprehensive Rollback (Systematic Issues)

**Timeline: 15-45 minutes**

#### 2.1 Database Rollback (if applicable)

**Backup Current State:**

```bash
# Create snapshot of current database state
pg_dump cloudtolocalllm > /backup/rollback-$(date +%Y%m%d-%H%M%S).sql

# Or for other databases
mysqldump cloudtolocalllm > /backup/rollback-$(date +%Y%m%d-%H%M%S).sql
```

**Restore Previous State:**

```bash
# Restore from pre-deployment backup
psql cloudtolocalllm < /backup/pre-deployment-$(date +%Y%m%d).sql

# Verify database integrity
psql -c "SELECT version();" cloudtolocalllm
```

#### 2.2 Configuration Rollback

**Environment Variables:**

```bash
# Restore previous environment configuration
sudo cp /opt/cloudtolocalllm/.env.backup /opt/cloudtolocalllm/.env

# Restart services to pick up changes
docker-compose restart api-backend
```

**SSL Certificates:**

```bash
# Restore previous certificates if updated
sudo cp /etc/letsencrypt/live/api.cloudtolocalllm.online/fullchain.pem.backup \
       /etc/letsencrypt/live/api.cloudtolocalllm.online/fullchain.pem

sudo cp /etc/letsencrypt/live/api.cloudtolocalllm.online/privkey.pem.backup \
       /etc/letsencrypt/live/api.cloudtolocalllm.online/privkey.pem

# Reload nginx
sudo systemctl reload nginx
```

#### 2.3 Container Image Rollback

**Identify Previous Images:**

```bash
# List available images
docker images | grep cloudtolocalllm

# Tag previous stable image
docker tag cloudtolocalllm-api:previous cloudtolocalllm-api:latest
```

**Update Docker Compose:**

```yaml
# Update docker-compose.yml to use previous image
services:
  api-backend:
    image: cloudtolocalllm-api:previous
    # ... rest of configuration
```

**Deploy Previous Images:**

```bash
# Pull previous images if from registry
docker-compose pull

# Restart with previous images
docker-compose up -d --force-recreate api-backend
```

### Phase 3: Desktop Client Rollback

**Timeline: 30-60 minutes**

#### 3.1 Prepare Previous Client Version

**Download Previous Version:**

```bash
# Download from GitHub releases
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/download/v3.10.2/cloudtolocalllm-linux.AppImage
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/download/v3.10.2/cloudtolocalllm-windows.exe

# Verify checksums
sha256sum cloudtolocalllm-linux.AppImage
```

#### 3.2 Update Distribution Channels

**Auto-Update System:**

```bash
# Update auto-update server to serve previous version
# Update version manifest
cat > /var/www/updates/version.json << EOF
{
  "version": "3.10.2",
  "url": "https://releases.cloudtolocalllm.online/v3.10.2/",
  "mandatory": true,
  "changelog": "Rollback to stable version due to deployment issues"
}
EOF
```

**Package Repositories:**

```bash
# Update DEB repository
reprepro -b /var/www/apt remove stable cloudtolocalllm
reprepro -b /var/www/apt includedeb stable cloudtolocalllm_3.10.2_amd64.deb

# Update AppImage repository
cp cloudtolocalllm-3.10.2.AppImage /var/www/releases/latest/cloudtolocalllm.AppImage
```

#### 3.3 User Communication

**Immediate Notification:**

```bash
# Send push notification to connected clients
curl -X POST https://api.cloudtolocalllm.online/api/admin/broadcast \
  -H "Authorization: Bearer <admin_token>" \
  -d '{
    "message": "System maintenance in progress. Please update your desktop client.",
    "type": "warning",
    "action": "update_required"
  }'
```

**Email/Web Notification:**

- Update status page with rollback information
- Send email to affected users
- Post on social media/community channels

### Phase 4: Validation and Monitoring

**Timeline: 15-30 minutes**

#### 4.1 System Health Validation

**Automated Health Checks:**

```bash
#!/bin/bash
# health-check-rollback.sh

echo "=== Rollback Health Check ==="

# Test API endpoints
echo "Testing API health..."
curl -f https://api.cloudtolocalllm.online/api/health || echo "API health check failed"

# Test WebSocket connections
echo "Testing WebSocket..."
timeout 10 wscat -c "wss://api.cloudtolocalllm.online/ws/bridge" || echo "WebSocket test failed"

# Test database connectivity
echo "Testing database..."
psql -c "SELECT 1;" cloudtolocalllm || echo "Database test failed"

# Check service status
echo "Checking services..."
docker-compose ps | grep -v "Up" && echo "Some services are down"

# Test user authentication
echo "Testing authentication..."
curl -f -H "Authorization: Bearer <test_token>" \
     https://api.cloudtolocalllm.online/api/user/profile || echo "Auth test failed"

echo "=== Health Check Complete ==="
```

#### 4.2 Performance Validation

**Load Testing:**

```bash
# Run basic load test
ab -n 100 -c 10 https://api.cloudtolocalllm.online/api/health

# Test WebSocket connections
node test-websocket-load.js

# Monitor response times
curl -w "@curl-format.txt" -s -o /dev/null https://api.cloudtolocalllm.online/api/health
```

**Metrics Validation:**

```bash
# Check error rates
curl https://api.cloudtolocalllm.online/api/metrics | jq '.errorRate'

# Check response times
curl https://api.cloudtolocalllm.online/api/metrics | jq '.averageResponseTime'

# Check connection counts
curl https://api.cloudtolocalllm.online/api/metrics | jq '.activeConnections'
```

#### 4.3 User Experience Validation

**Desktop Client Testing:**

1. Test connection establishment
2. Verify authentication flow
3. Test basic chat functionality
4. Verify model selection works
5. Test reconnection after network interruption

**Web Interface Testing:**

1. Test login flow
2. Verify chat interface loads
3. Test message sending/receiving
4. Verify streaming responses work
5. Test error handling

## Post-Rollback Procedures

### Immediate Actions (0-2 hours)

#### 1. Incident Documentation

**Create Incident Report:**

```markdown
# Incident Report: Simplified Tunnel System Rollback

**Date:** [Date and Time]
**Duration:** [Start Time] - [End Time]
**Severity:** [Critical/High/Medium/Low]

## Summary
[Brief description of the issue and rollback]

## Timeline
- [Time]: Issue first detected
- [Time]: Rollback decision made
- [Time]: Rollback initiated
- [Time]: System restored
- [Time]: Validation completed

## Root Cause
[Analysis of what caused the issue]

## Impact
- Users affected: [Number/Percentage]
- Services impacted: [List]
- Downtime: [Duration]

## Resolution
[Steps taken to resolve the issue]

## Lessons Learned
[What can be improved for next time]

## Action Items
- [ ] [Action item 1]
- [ ] [Action item 2]
```

#### 2. Stakeholder Communication

**Internal Communication:**

```bash
# Send incident report to team
# Update project management tools
# Schedule post-mortem meeting
```

**External Communication:**

```bash
# Update status page
# Send user notification about resolution
# Post on community channels
```

#### 3. System Monitoring

**Enhanced Monitoring:**

```bash
# Increase monitoring frequency
# Set up additional alerts
# Monitor user feedback channels
```

### Short-term Actions (2-24 hours)

#### 1. Root Cause Analysis

**Log Analysis:**

```bash
# Analyze logs from failed deployment
grep -i error /var/log/cloudtolocalllm/*.log

# Check system metrics during incident
# Review performance data
# Analyze user behavior patterns
```

**Code Review:**

```bash
# Review changes that caused issues
git diff <previous_stable_commit> <failed_commit>

# Identify problematic changes
# Plan fixes for identified issues
```

#### 2. Fix Development

**Issue Resolution:**

```bash
# Create hotfix branch
git checkout -b hotfix/tunnel-deployment-fix

# Implement fixes
# Add additional tests
# Update deployment procedures
```

**Testing:**

```bash
# Run comprehensive test suite
# Perform integration testing
# Conduct load testing
# Security testing if applicable
```

#### 3. Deployment Planning

**Improved Deployment Strategy:**

```bash
# Plan gradual rollout
# Implement feature flags
# Add deployment validation steps
# Enhance monitoring and alerting
```

### Long-term Actions (1-7 days)

#### 1. Process Improvements

**Deployment Process:**

- [ ] Implement blue-green deployment
- [ ] Add automated rollback triggers
- [ ] Enhance pre-deployment testing
- [ ] Improve deployment validation

**Monitoring and Alerting:**

- [ ] Add more comprehensive health checks
- [ ] Implement predictive alerting
- [ ] Enhance error tracking
- [ ] Improve performance monitoring

#### 2. Documentation Updates

**Update Procedures:**

- [ ] Update deployment guide
- [ ] Enhance rollback procedures
- [ ] Improve troubleshooting guide
- [ ] Update operational runbooks

#### 3. Team Training

**Knowledge Sharing:**

- [ ] Conduct post-mortem session
- [ ] Share lessons learned
- [ ] Update team procedures
- [ ] Provide additional training if needed

## Rollback Testing and Validation

### Regular Rollback Drills

**Monthly Rollback Testing:**

```bash
#!/bin/bash
# rollback-drill.sh

echo "=== Rollback Drill Starting ==="

# Create test deployment
git checkout -b rollback-test-$(date +%Y%m%d)

# Make minor change for testing
echo "# Rollback test $(date)" >> README.md
git add README.md
git commit -m "Rollback test deployment"

# Deploy test change
docker-compose build api-backend
docker-compose up -d api-backend

# Wait for deployment
sleep 30

# Initiate rollback
echo "Initiating rollback..."
git checkout main
docker-compose build api-backend
docker-compose up -d api-backend

# Validate rollback
./health-check-rollback.sh

echo "=== Rollback Drill Complete ==="
```

### Rollback Automation

**Automated Rollback Triggers:**

```bash
#!/bin/bash
# auto-rollback-monitor.sh

while true; do
  # Check error rate
  ERROR_RATE=$(curl -s https://api.cloudtolocalllm.online/api/metrics | jq '.errorRate')
  
  if (( $(echo "$ERROR_RATE > 10" | bc -l) )); then
    echo "High error rate detected: $ERROR_RATE%"
    echo "Initiating automatic rollback..."
    
    # Trigger rollback
    ./emergency-rollback.sh
    
    # Send alert
    curl -X POST https://hooks.slack.com/services/... \
      -d '{"text":"Automatic rollback triggered due to high error rate"}'
    
    break
  fi
  
  sleep 60
done
```

## Emergency Contacts and Escalation

### Contact Information

**Primary On-Call:**

- Name: [Primary Engineer]
- Phone: [Phone Number]
- Email: [Email Address]

**Secondary On-Call:**

- Name: [Secondary Engineer]
- Phone: [Phone Number]
- Email: [Email Address]

**Management Escalation:**

- Name: [Engineering Manager]
- Phone: [Phone Number]
- Email: [Email Address]

### Escalation Procedures

**Level 1 (0-15 minutes):**

- Automated monitoring alerts
- On-call engineer response
- Initial assessment and triage

**Level 2 (15-30 minutes):**

- Escalate to secondary on-call
- Involve additional team members
- Consider rollback decision

**Level 3 (30+ minutes):**

- Management notification
- External communication
- Post-incident review planning

## Conclusion

These rollback procedures provide a comprehensive framework for handling deployment issues with the Simplified Tunnel System. Regular testing and updates of these procedures ensure rapid recovery and minimal user impact during incidents.

Key success factors:

- **Preparation**: Regular backups and tested procedures
- **Speed**: Quick decision-making and execution
- **Communication**: Clear stakeholder notification
- **Learning**: Post-incident analysis and improvement

For questions or updates to these procedures, contact the engineering team or update this document through the standard change management process.
