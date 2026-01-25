# Tunnel System Troubleshooting Guide

## Quick Troubleshooting Flowchart

```
START
  │
  ├─> Is the tunnel connected?
  │   ├─ NO  ──> Check Connection Issues (Section 1)
  │   └─ YES ──> Continue
  │
  ├─> Are requests failing?
  │   ├─ YES ──> Check Request Issues (Section 2)
  │   └─ NO  ──> Continue
  │
  ├─> Is performance degraded?
  │   ├─ YES ──> Check Performance Issues (Section 3)
  │   └─ NO  ──> Continue
  │
  └─> Run Diagnostics (Section 4)
      └─> Contact Support with diagnostic report
```

## 1. Connection Issues

### Problem: Cannot Connect to Tunnel

**Symptoms:**
- Connection fails immediately
- Error: "Connection refused"
- Error code: TUNNEL_001

**Diagnosis Steps:**

1. **Check network connectivity:**
   ```bash
   # Test DNS resolution
   nslookup proxy.cloudtolocalllm.online
   
   # Test connectivity
   ping proxy.cloudtolocalllm.online
   
   # Test WebSocket port
   telnet proxy.cloudtolocalllm.online 443
   ```

2. **Check firewall settings:**
   - Ensure port 443 (HTTPS/WSS) is not blocked
   - Check corporate firewall rules
   - Verify VPN is not interfering
   - Check antivirus/security software

3. **Verify server availability:**
   ```bash
   # Check server health
   curl https://proxy.cloudtolocalllm.online/api/tunnel/health
   
   # Expected response:
   # {"status": "healthy", "activeConnections": 42, ...}
   ```

4. **Check JWT token:**
   - Verify token is not expired
   - Verify token is valid (not corrupted)
   - Check token format: `Bearer <token>`

**Solutions:**

| Issue | Solution |
|-------|----------|
| DNS resolution fails | Check DNS settings, try alternative DNS (8.8.8.8) |
| Firewall blocks connection | Whitelist proxy.cloudtolocalllm.online in firewall |
| Server unavailable | Wait for server to recover, check status page |
| Invalid JWT token | Re-authenticate, refresh token |
| Network timeout | Check network speed, try from different network |

**Example Log Output:**
```
[ERROR] Connection failed: Connection refused
[ERROR] Error code: TUNNEL_001
[ERROR] Category: network
[ERROR] Suggestion: Check your internet connection and firewall settings
[DEBUG] Server URL: wss://proxy.cloudtolocalllm.online
[DEBUG] Network conditions: Timeout after 30 seconds
```

---

### Problem: Connection Drops Frequently

**Symptoms:**
- Connection established but drops after a few seconds
- Frequent reconnection attempts
- Error: "Connection lost"

**Diagnosis Steps:**

1. **Check network stability:**
   ```bash
   # Monitor packet loss
   ping -c 100 proxy.cloudtolocalllm.online
   
   # Look for: 0% packet loss (good), >5% packet loss (bad)
   ```

2. **Check connection quality:**
   - Run diagnostics: `TunnelService.runDiagnostics()`
   - Check latency: Should be < 200ms
   - Check packet loss: Should be < 5%

3. **Check server logs:**
   ```bash
   # Get server logs
   kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm
   
   # Look for: Connection closed, timeout, error messages
   ```

4. **Check client configuration:**
   - Verify timeout settings are appropriate
   - Check if using unstable network profile
   - Verify heartbeat interval (should be 30 seconds)

**Solutions:**

| Issue | Solution |
|-------|----------|
| High packet loss | Switch to stable network, check WiFi signal |
| High latency | Move closer to router, reduce interference |
| Server timeout | Increase timeout in configuration |
| Unstable network | Use `TunnelConfig.unstableNetwork()` profile |
| Too many reconnections | Check server logs for errors |

**Example Log Output:**
```
[WARN] Connection lost after 15 seconds
[WARN] Reconnection attempt 1/10
[DEBUG] Latency: 250ms (high)
[DEBUG] Packet loss: 8% (high)
[DEBUG] Last activity: 15 seconds ago
[INFO] Reconnecting with 2 second delay...
```

---

### Problem: Authentication Fails

**Symptoms:**
- Error: "Authentication failed"
- Error code: TUNNEL_002 or TUNNEL_003
- Connection rejected immediately

**Diagnosis Steps:**

1. **Check JWT token:**
   ```bash
   # Decode JWT token (online tool or jwt-cli)
   jwt decode <token>
   
   # Check expiration: exp field should be in future
   # Check user ID: sub field should match your user ID
   ```

2. **Check Auth0 configuration:**
   - Verify Auth0 domain is correct
   - Verify client ID is correct
   - Verify redirect URI is configured

3. **Check token refresh:**
   ```bash
   # If token is expired, refresh it
   curl -X POST https://auth.cloudtolocalllm.online/oauth/token \
     -H "Content-Type: application/json" \
     -d '{
       "client_id": "YOUR_CLIENT_ID",
       "client_secret": "YOUR_CLIENT_SECRET",
       "grant_type": "refresh_token",
       "refresh_token": "YOUR_REFRESH_TOKEN"
     }'
   ```

**Solutions:**

| Issue | Solution |
|-------|----------|
| Token expired | Refresh token or re-authenticate |
| Invalid token | Check token format, re-authenticate |
| Auth0 misconfigured | Verify Auth0 settings in config |
| Token not sent | Check Authorization header format |
| User not authorized | Check user permissions in Auth0 |

**Example Log Output:**
```
[ERROR] Authentication failed
[ERROR] Error code: TUNNEL_003
[ERROR] Category: authentication
[ERROR] Message: Token expired
[ERROR] Suggestion: Please log in again
[DEBUG] Token expiration: 2024-01-15T10:00:00Z
[DEBUG] Current time: 2024-01-15T11:00:00Z
```

---

## 2. Request Issues

### Problem: Requests Timeout

**Symptoms:**
- Requests take > 30 seconds
- Error: "Request timeout"
- Error code: TUNNEL_007

**Diagnosis Steps:**

1. **Check server load:**
   ```bash
   # Get server diagnostics
   curl -H "Authorization: Bearer $TOKEN" \
     https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics
   
   # Look for: activeConnections, averageLatency, errorRate
   ```

2. **Check request size:**
   - Large payloads take longer to process
   - Check if payload is > 1MB
   - Consider splitting large requests

3. **Check SSH server:**
   - Verify SSH server is running
   - Check SSH server load
   - Verify SSH credentials are correct

4. **Check network latency:**
   ```bash
   # Measure latency
   ping proxy.cloudtolocalllm.online
   
   # Should be < 100ms for good performance
   ```

**Solutions:**

| Issue | Solution |
|-------|----------|
| Server overloaded | Wait for load to decrease, scale up server |
| Large payload | Split into smaller requests, compress data |
| SSH server slow | Check SSH server performance, optimize queries |
| High latency | Move closer to server, check network |
| Timeout too short | Increase timeout in configuration |

**Example Log Output:**
```
[WARN] Request timeout after 30 seconds
[WARN] Request ID: req-123
[DEBUG] Payload size: 5MB (large)
[DEBUG] Server latency: 25 seconds
[DEBUG] SSH server response time: 28 seconds
[INFO] Suggestion: Split large requests or increase timeout
```

---

### Problem: Requests Fail with Rate Limit Error

**Symptoms:**
- Error: "Rate limit exceeded"
- Error code: TUNNEL_005
- HTTP status: 429 Too Many Requests

**Diagnosis Steps:**

1. **Check request rate:**
   - Count requests per minute
   - Compare against limit (100 req/min for free tier)
   - Check if burst of requests

2. **Check user tier:**
   ```bash
   # Verify user tier in Auth0
   # Free: 100 req/min
   # Premium: 1000 req/min
   # Enterprise: 10000 req/min
   ```

3. **Check rate limit headers:**
   ```bash
   # Response headers show rate limit status
   X-RateLimit-Limit: 100
   X-RateLimit-Remaining: 0
   X-RateLimit-Reset: 1705318200
   ```

**Solutions:**

| Issue | Solution |
|-------|----------|
| Too many requests | Reduce request rate, implement throttling |
| Burst of requests | Spread requests over time, use queue |
| Free tier limit | Upgrade to premium tier |
| Rate limit reset | Wait for reset time (shown in header) |
| Concurrent requests | Reduce concurrent connections |

**Example Log Output:**
```
[ERROR] Rate limit exceeded
[ERROR] Error code: TUNNEL_005
[ERROR] Category: server
[DEBUG] Requests this minute: 105
[DEBUG] Limit: 100
[DEBUG] Reset in: 45 seconds
[INFO] Suggestion: Reduce request rate or upgrade to premium tier
```

---

### Problem: Requests Fail with Queue Full Error

**Symptoms:**
- Error: "Queue full"
- Error code: TUNNEL_006
- Requests are being dropped

**Diagnosis Steps:**

1. **Check queue size:**
   ```bash
   # Get diagnostics
   curl -H "Authorization: Bearer $TOKEN" \
     https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics
   
   # Look for: queueSize, queueFillPercentage
   ```

2. **Check request rate:**
   - Are requests being sent faster than processed?
   - Check for burst of requests
   - Check if SSH server is slow

3. **Check connection status:**
   - Is connection stable?
   - Are requests being processed?
   - Check for network issues

**Solutions:**

| Issue | Solution |
|-------|----------|
| Queue overflow | Reduce request rate, wait for queue to drain |
| Slow SSH server | Optimize SSH server, check performance |
| Network issues | Check network stability, reconnect |
| Too many concurrent requests | Reduce concurrency, implement throttling |
| Queue size too small | Increase queue size in configuration |

**Example Log Output:**
```
[ERROR] Queue full
[ERROR] Error code: TUNNEL_006
[DEBUG] Queue size: 100/100 (100% full)
[DEBUG] Requests per second: 50
[DEBUG] Processing rate: 30 req/sec
[INFO] Suggestion: Reduce request rate or increase queue size
```

---

## 3. Performance Issues

### Problem: High Latency

**Symptoms:**
- Requests take 200ms+ to complete
- Performance degraded
- Slow response times

**Diagnosis Steps:**

1. **Check latency metrics:**
   ```bash
   # Get diagnostics
   curl -H "Authorization: Bearer $TOKEN" \
     https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics
   
   # Look for: averageLatency, p95Latency, p99Latency
   ```

2. **Identify latency source:**
   - Network latency: Check ping time
   - Server latency: Check server load
   - SSH latency: Check SSH server performance
   - Processing latency: Check request complexity

3. **Check network conditions:**
   ```bash
   # Measure network latency
   ping -c 10 proxy.cloudtolocalllm.online
   
   # Should be < 50ms for good performance
   ```

4. **Check server load:**
   ```bash
   # Get server metrics
   curl https://proxy.cloudtolocalllm.online/api/tunnel/metrics
   
   # Look for: tunnel_request_latency_ms histogram
   ```

**Solutions:**

| Issue | Solution |
|-------|----------|
| High network latency | Move closer to server, check network |
| Server overloaded | Wait for load to decrease, scale up |
| SSH server slow | Optimize SSH server, check performance |
| Large payloads | Compress data, split requests |
| Inefficient queries | Optimize database queries |

**Example Log Output:**
```
[WARN] High latency detected
[WARN] Average latency: 250ms (target: < 100ms)
[DEBUG] Network latency: 50ms
[DEBUG] Server latency: 150ms
[DEBUG] SSH latency: 50ms
[INFO] Suggestion: Check server load or optimize queries
```

---

### Problem: High Error Rate

**Symptoms:**
- Many requests failing
- Error rate > 5%
- Errors in logs

**Diagnosis Steps:**

1. **Check error rate:**
   ```bash
   # Get diagnostics
   curl -H "Authorization: Bearer $TOKEN" \
     https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics
   
   # Look for: errorRate, errorsByCategory
   ```

2. **Identify error types:**
   - Network errors: Connection issues
   - Authentication errors: Token issues
   - Server errors: Server problems
   - Protocol errors: Protocol issues

3. **Check server logs:**
   ```bash
   # Get server logs
   kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm
   
   # Look for: ERROR, WARN, exception messages
   ```

4. **Check circuit breaker:**
   ```bash
   # Get diagnostics
   curl -H "Authorization: Bearer $TOKEN" \
     https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics
   
   # Look for: circuitBreaker.state (should be "closed")
   ```

**Solutions:**

| Issue | Solution |
|-------|----------|
| Network errors | Check network stability, reconnect |
| Authentication errors | Refresh token, re-authenticate |
| Server errors | Check server status, restart if needed |
| Protocol errors | Check protocol compatibility |
| Circuit breaker open | Wait for recovery (60 seconds) |

**Example Log Output:**
```
[ERROR] High error rate detected
[ERROR] Error rate: 8% (threshold: 5%)
[DEBUG] Total requests: 1000
[DEBUG] Failed requests: 80
[DEBUG] Error breakdown:
  - Network: 30
  - Authentication: 10
  - Server: 25
  - Protocol: 15
[INFO] Suggestion: Check server status and network connectivity
```

---

## 4. Diagnostic Tools and Commands

### Running Diagnostics

#### Client-Side Diagnostics

```dart
// Run full diagnostic suite
final report = await tunnelService.runDiagnostics();

// Print results
print('Diagnostic Report');
print('================');
print('Timestamp: ${report.timestamp}');
print('Total Tests: ${report.summary.totalTests}');
print('Passed: ${report.summary.passedTests}');
print('Failed: ${report.summary.failedTests}');
print('');

for (final test in report.tests) {
  final status = test.passed ? '✓' : '✗';
  print('$status ${test.name} (${test.duration.inMilliseconds}ms)');
  if (!test.passed && test.errorMessage != null) {
    print('  Error: ${test.errorMessage}');
  }
}

if (report.summary.recommendations.isNotEmpty) {
  print('');
  print('Recommendations:');
  for (final rec in report.summary.recommendations) {
    print('- $rec');
  }
}
```

#### Server-Side Diagnostics

```bash
# Get server diagnostics
curl -H "Authorization: Bearer $TOKEN" \
  https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics | jq .

# Get server health
curl https://proxy.cloudtolocalllm.online/api/tunnel/health | jq .

# Get server metrics
curl https://proxy.cloudtolocalllm.online/api/tunnel/metrics
```

#### Kubernetes Diagnostics

```bash
# Check pod status
kubectl get pods -n cloudtolocalllm -l app=streaming-proxy

# Check pod logs
kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm

# Check pod events
kubectl describe pod <pod-name> -n cloudtolocalllm

# Check resource usage
kubectl top pod <pod-name> -n cloudtolocalllm

# Check service status
kubectl get svc streaming-proxy -n cloudtolocalllm

# Check ingress status
kubectl get ingress -n cloudtolocalllm
```

### Enabling Debug Logging

#### Client-Side Debug Logging

```dart
// Enable debug logging
final config = TunnelConfig(
  logLevel: LogLevel.debug,
  // ... other settings
);

await tunnelService.connect(
  serverUrl: 'wss://proxy.cloudtolocalllm.online',
  authToken: authToken,
  config: config,
);
```

#### Server-Side Debug Logging

```bash
# Update configuration to enable debug logging
curl -X PUT \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"monitoring": {"logLevel": "debug"}}' \
  https://proxy.cloudtolocalllm.online/api/tunnel/config

# Check logs
kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm | grep DEBUG
```

### Monitoring Metrics

#### Prometheus Metrics

```bash
# Scrape metrics
curl https://proxy.cloudtolocalllm.online/api/tunnel/metrics

# Query specific metric
curl 'https://prometheus.cloudtolocalllm.online/api/v1/query?query=tunnel_active_connections'

# Query metric range
curl 'https://prometheus.cloudtolocalllm.online/api/v1/query_range?query=tunnel_request_latency_ms&start=1705314600&end=1705318200&step=60'
```

#### Grafana Dashboards

- **Tunnel System Dashboard**: Real-time metrics and performance
- **Error Rate Dashboard**: Error tracking and analysis
- **Connection Dashboard**: Connection metrics and health
- **Performance Dashboard**: Latency and throughput metrics

## 5. Common Issues and Solutions

### Issue: "Connection refused"

**Cause:** Server is not running or port is blocked

**Solution:**
1. Check server status: `curl https://proxy.cloudtolocalllm.online/api/tunnel/health`
2. Check firewall: Ensure port 443 is open
3. Check DNS: Verify proxy.cloudtolocalllm.online resolves correctly
4. Restart server: `kubectl rollout restart deployment/streaming-proxy -n cloudtolocalllm`

---

### Issue: "Token expired"

**Cause:** JWT token has expired

**Solution:**
1. Refresh token: Use refresh token to get new access token
2. Re-authenticate: Log in again to get new token
3. Check token expiration: Decode token to see expiration time

---

### Issue: "Rate limit exceeded"

**Cause:** Too many requests sent too quickly

**Solution:**
1. Reduce request rate: Implement throttling
2. Upgrade tier: Upgrade to premium for higher limits
3. Wait for reset: Check X-RateLimit-Reset header
4. Implement queue: Use request queue to spread requests

---

### Issue: "Circuit breaker open"

**Cause:** Too many failures detected

**Solution:**
1. Wait for recovery: Circuit breaker resets after 60 seconds
2. Check server: Verify SSH server is running
3. Check logs: Look for error patterns
4. Restart server: Restart streaming-proxy if needed

---

### Issue: "Queue full"

**Cause:** Too many requests queued

**Solution:**
1. Reduce request rate: Send fewer requests
2. Increase queue size: Update configuration
3. Check SSH server: Verify it's processing requests
4. Check network: Verify connection is stable

---

## 6. Getting Help

### Collecting Diagnostic Information

Before contacting support, collect:

1. **Diagnostic report:**
   ```dart
   final report = await tunnelService.runDiagnostics();
   // Save report to file
   ```

2. **Server diagnostics:**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics > diagnostics.json
   ```

3. **Logs:**
   ```bash
   # Client logs (from app)
   # Server logs
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm > server-logs.txt
   ```

4. **System information:**
   - OS and version
   - Network type (WiFi, wired, mobile)
   - Tunnel configuration
   - Error messages and codes

### Support Channels

- **Documentation**: https://docs.cloudtolocalllm.online
- **GitHub Issues**: https://github.com/cloudtolocalllm/issues
- **Email Support**: support@cloudtolocalllm.online
- **Community Forum**: https://forum.cloudtolocalllm.online

### Providing Feedback

Include in support request:
1. Description of issue
2. Steps to reproduce
3. Expected behavior
4. Actual behavior
5. Diagnostic report
6. Logs (client and server)
7. System information
8. Screenshots (if applicable)

## Conclusion

This troubleshooting guide covers the most common issues and their solutions. For issues not covered here, refer to the API documentation or contact support with diagnostic information.
