# Simplified Tunnel System Validation Testing Guide

## Overview

This guide provides comprehensive instructions for validating the Simplified Tunnel System deployment using automated testing scripts. The validation suite includes multiple testing approaches to ensure thorough coverage of system functionality, performance, and security.

## Validation Scripts

### Available Scripts

1. **Bash Script** (`validate_tunnel_deployment.sh`)
   - Comprehensive shell-based validation
   - Works on Linux, macOS, and WSL
   - Includes basic WebSocket testing with wscat

2. **Node.js Script** (`validate_tunnel_deployment.js`)
   - Advanced JavaScript-based validation
   - Enhanced WebSocket testing capabilities
   - JSON-formatted detailed results
   - Load testing and performance analysis

3. **PowerShell Script** (`validate_tunnel_deployment.ps1`)
   - Windows-native validation
   - PowerShell-based HTTP testing
   - Windows-specific security checks

4. **Comprehensive Runner** (`run_tunnel_validation.sh`)
   - Executes all validation scripts
   - Generates unified report
   - Cross-platform compatibility

## Prerequisites

### System Requirements

**All Platforms:**
- Internet connectivity to reach API endpoints
- Valid JWT token for authenticated tests (optional but recommended)

**Linux/macOS:**
- Bash 4.0+
- curl
- jq (for JSON processing)
- wscat (for WebSocket testing): `npm install -g wscat`

**Windows:**
- PowerShell 5.1+ or PowerShell Core 6+
- curl (included in Windows 10+)

**Node.js Testing:**
- Node.js 14+
- npm packages: `ws` (auto-installed if missing)

### Authentication Setup

To run the full validation suite, you'll need a valid JWT token:

1. **Obtain JWT Token:**
   ```bash
   # Method 1: Extract from browser developer tools
   # 1. Login to https://app.cloudtolocalllm.online
   # 2. Open Developer Tools (F12)
   # 3. Go to Application/Storage > Local Storage
   # 4. Find the JWT token
   
   # Method 2: Use Auth0 test token (if available)
   # Contact development team for test credentials
   ```

2. **Set Environment Variable:**
   ```bash
   # Linux/macOS
   export TEST_JWT_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..."
   
   # Windows PowerShell
   $env:TEST_JWT_TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..."
   
   # Windows CMD
   set TEST_JWT_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...
   ```

## Running Validations

### Quick Start

**Run All Validations (Recommended):**
```bash
# Linux/macOS
./scripts/deploy/run_tunnel_validation.sh

# Windows (Git Bash/WSL)
bash ./scripts/deploy/run_tunnel_validation.sh
```

**Individual Script Execution:**
```bash
# Bash validation
./scripts/deploy/validate_tunnel_deployment.sh

# Node.js validation
node ./scripts/deploy/validate_tunnel_deployment.js

# PowerShell validation (Windows)
powershell -File ./scripts/deploy/validate_tunnel_deployment.ps1
```

### Advanced Usage

**Custom API URL:**
```bash
# Test against staging environment
./scripts/deploy/run_tunnel_validation.sh -u https://staging-api.cloudtolocalllm.online

# Test against local development
./scripts/deploy/run_tunnel_validation.sh -u http://localhost:3000
```

**With Authentication:**
```bash
# Using command line argument
./scripts/deploy/run_tunnel_validation.sh -t "eyJ0eXAiOiJKV1Q..."

# Using environment variable
export TEST_JWT_TOKEN="eyJ0eXAiOiJKV1Q..."
./scripts/deploy/run_tunnel_validation.sh
```

**Skip Specific Validations:**
```bash
# Skip Node.js validation
./scripts/deploy/run_tunnel_validation.sh --skip-node

# Skip PowerShell validation
./scripts/deploy/run_tunnel_validation.sh --skip-powershell

# Run only bash validation
./scripts/deploy/run_tunnel_validation.sh --skip-node --skip-powershell
```

**Custom Results Directory:**
```bash
./scripts/deploy/run_tunnel_validation.sh -r /path/to/results
```

## Validation Test Categories

### 1. Infrastructure Health Tests

**Purpose:** Verify basic system availability and health

**Tests Include:**
- API health endpoint accessibility
- Tunnel system health status
- Response time validation
- Service availability checks

**Expected Results:**
- HTTP 200 responses from health endpoints
- "healthy" status in response bodies
- Response times < 2 seconds

### 2. Authentication and Authorization Tests

**Purpose:** Ensure security measures are properly implemented

**Tests Include:**
- Unauthenticated request rejection (401)
- Invalid token rejection (403)
- Valid token acceptance (200)
- Cross-user access prevention (403)

**Expected Results:**
- Proper HTTP status codes for each scenario
- JWT token validation working correctly
- User isolation enforced

### 3. WebSocket Connectivity Tests

**Purpose:** Validate real-time communication capabilities

**Tests Include:**
- WebSocket connection establishment
- Authentication via query parameters
- Ping/pong message exchange
- Connection stability

**Expected Results:**
- Successful WebSocket connections with valid tokens
- Proper message protocol handling
- Connection timeouts handled gracefully

### 4. Tunnel Proxy Tests

**Purpose:** Verify tunnel routing and proxy functionality

**Tests Include:**
- User-specific health endpoints
- Tunnel status reporting
- Metrics collection
- Request routing validation

**Expected Results:**
- Accurate user status reporting
- Proper metrics collection
- Correct request routing

### 5. Rate Limiting Tests

**Purpose:** Ensure abuse prevention mechanisms work

**Tests Include:**
- Rapid request submission
- Rate limit threshold detection
- Rate limit header validation
- Recovery after rate limit reset

**Expected Results:**
- HTTP 429 responses when limits exceeded
- Proper rate limit headers
- System recovery after limit reset

### 6. Error Handling Tests

**Purpose:** Validate proper error responses and handling

**Tests Include:**
- 404 responses for non-existent endpoints
- Malformed request handling
- Timeout handling
- Error message formatting

**Expected Results:**
- Appropriate HTTP status codes
- Consistent error message format
- Graceful handling of edge cases

### 7. Performance Tests

**Purpose:** Ensure acceptable system performance

**Tests Include:**
- Single request response time
- Concurrent request handling
- Load testing (basic)
- Resource utilization

**Expected Results:**
- Response times < 2 seconds for single requests
- Successful handling of concurrent requests
- Stable performance under load

### 8. Security Tests

**Purpose:** Verify security measures and headers

**Tests Include:**
- HTTPS enforcement
- Security header validation
- SSL certificate verification
- Origin validation

**Expected Results:**
- HTTP requests redirected to HTTPS
- Required security headers present
- Valid SSL certificates
- Proper origin checking

## Interpreting Results

### Success Indicators

**All Tests Passed:**
```
✓ API Health Check
✓ Tunnel Health Check
✓ WebSocket Connection
✓ Authentication Required
✓ Valid Token Authentication
...
DEPLOYMENT VALIDATION PASSED
```

**Key Metrics:**
- Success Rate: 100%
- Response Times: < 2000ms
- All security checks passed
- No authentication bypasses

### Failure Indicators

**Common Failure Patterns:**
```
✗ API Health Check - API not healthy or unreachable
✗ WebSocket Connection - Cannot connect to WebSocket endpoint
✗ Authentication Required - Endpoint accessible without authentication
```

**Investigation Steps:**
1. Check API server status and logs
2. Verify network connectivity
3. Validate configuration settings
4. Review authentication setup

### Partial Success

**Some Tests Skipped:**
```
⚠ WebSocket Connection - No test token available
⚠ Valid Token Authentication - No test token available
```

**Resolution:**
- Provide TEST_JWT_TOKEN environment variable
- Ensure token is valid and not expired
- Check token permissions and scopes

## Troubleshooting

### Common Issues

#### 1. Connection Timeouts
**Symptoms:**
- Tests fail with timeout errors
- Long response times

**Solutions:**
```bash
# Check network connectivity
ping api.cloudtolocalllm.online

# Test basic HTTP connectivity
curl -I https://api.cloudtolocalllm.online/api/health

# Check firewall settings
# Ensure ports 80, 443 are accessible
```

#### 2. Authentication Failures
**Symptoms:**
- All authenticated tests fail
- 401/403 errors consistently

**Solutions:**
```bash
# Verify token format
echo $TEST_JWT_TOKEN | cut -d. -f2 | base64 -d

# Check token expiration
# Use online JWT decoder to verify expiration

# Test token manually
curl -H "Authorization: Bearer $TEST_JWT_TOKEN" \
     https://api.cloudtolocalllm.online/api/tunnel/status
```

#### 3. WebSocket Connection Issues
**Symptoms:**
- WebSocket tests fail
- Connection refused errors

**Solutions:**
```bash
# Install wscat if missing
npm install -g wscat

# Test WebSocket manually
wscat -c "wss://api.cloudtolocalllm.online/ws/tunnel?token=$TEST_JWT_TOKEN"

# Check proxy/firewall WebSocket support
```

#### 4. Missing Dependencies
**Symptoms:**
- Scripts fail to run
- Command not found errors

**Solutions:**
```bash
# Install missing tools
# Linux/macOS
sudo apt-get install curl jq  # Ubuntu/Debian
brew install curl jq          # macOS

# Install Node.js dependencies
npm install -g wscat

# Windows - ensure PowerShell is updated
```

### Advanced Troubleshooting

#### Enable Verbose Logging
```bash
# Bash script
./scripts/deploy/validate_tunnel_deployment.sh -v

# Comprehensive runner
./scripts/deploy/run_tunnel_validation.sh --verbose

# Node.js script (set environment)
DEBUG=* node ./scripts/deploy/validate_tunnel_deployment.js
```

#### Manual Testing
```bash
# Test individual endpoints
curl -v https://api.cloudtolocalllm.online/api/health
curl -v https://api.cloudtolocalllm.online/api/tunnel/health

# Test with authentication
curl -v -H "Authorization: Bearer $TEST_JWT_TOKEN" \
     https://api.cloudtolocalllm.online/api/tunnel/status

# Test WebSocket connection
wscat -c "wss://api.cloudtolocalllm.online/ws/tunnel?token=$TEST_JWT_TOKEN"
```

#### Log Analysis
```bash
# Check validation logs
tail -f /tmp/tunnel-deployment-validation-*.log

# Check API server logs
docker-compose logs -f api-backend

# Check system logs
journalctl -u cloudtolocalllm-api -f
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Tunnel Deployment Validation

on:
  deployment_status:
    types: [success]

jobs:
  validate:
    runs-on: ubuntu-latest
    if: github.event.deployment_status.state == 'success'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '24'
    
    - name: Install dependencies
      run: |
        npm install -g wscat
        sudo apt-get update
        sudo apt-get install -y jq curl
    
    - name: Run validation
      env:
        API_BASE_URL: ${{ secrets.API_BASE_URL }}
        TEST_JWT_TOKEN: ${{ secrets.TEST_JWT_TOKEN }}
        TEST_USER_ID: ${{ secrets.TEST_USER_ID }}
      run: |
        chmod +x ./scripts/deploy/run_tunnel_validation.sh
        ./scripts/deploy/run_tunnel_validation.sh
    
    - name: Upload results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: validation-results
        path: /tmp/tunnel-validation-*/
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    environment {
        API_BASE_URL = credentials('api-base-url')
        TEST_JWT_TOKEN = credentials('test-jwt-token')
        TEST_USER_ID = credentials('test-user-id')
    }
    
    stages {
        stage('Setup') {
            steps {
                sh 'npm install -g wscat'
                sh 'chmod +x ./scripts/deploy/run_tunnel_validation.sh'
            }
        }
        
        stage('Validate Deployment') {
            steps {
                sh './scripts/deploy/run_tunnel_validation.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: '/tmp/tunnel-validation-*/**/*', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        failure {
            emailext (
                subject: "Tunnel Deployment Validation Failed",
                body: "The tunnel deployment validation has failed. Please check the attached results.",
                to: "${env.NOTIFICATION_EMAIL}"
            )
        }
    }
}
```

## Best Practices

### Pre-Deployment Validation
1. **Always run validation before production deployment**
2. **Test against staging environment first**
3. **Ensure all tests pass with 100% success rate**
4. **Review performance metrics and response times**

### Regular Health Checks
1. **Schedule periodic validation runs**
2. **Monitor for performance degradation**
3. **Set up alerts for validation failures**
4. **Track success rates over time**

### Security Validation
1. **Regularly rotate test JWT tokens**
2. **Validate authentication mechanisms**
3. **Test cross-user access prevention**
4. **Verify security headers and HTTPS enforcement**

### Documentation and Reporting
1. **Save validation reports for audit purposes**
2. **Document any test failures and resolutions**
3. **Share results with relevant stakeholders**
4. **Update validation scripts as system evolves**

## Support and Maintenance

### Updating Validation Scripts

When the tunnel system is updated, ensure validation scripts are also updated:

1. **Review new API endpoints and add tests**
2. **Update expected response formats**
3. **Add tests for new security measures**
4. **Update error handling expectations**

### Getting Help

If validation scripts fail or need updates:

1. **Check this documentation first**
2. **Review system logs and error messages**
3. **Contact the development team with:**
   - Validation results and logs
   - System configuration details
   - Steps to reproduce issues
   - Expected vs actual behavior

### Contributing

To improve the validation suite:

1. **Add new test cases for edge cases**
2. **Improve error handling and reporting**
3. **Add performance benchmarks**
4. **Enhance cross-platform compatibility**

## Conclusion

The Simplified Tunnel System validation suite provides comprehensive testing capabilities to ensure deployment success and system reliability. Regular use of these validation scripts helps maintain system quality and catch issues early in the deployment process.

For questions or issues with the validation scripts, refer to the troubleshooting section above or contact the development team with detailed information about the problem.