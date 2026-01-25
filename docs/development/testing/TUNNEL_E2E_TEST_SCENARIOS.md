# Tunnel End-to-End Test Scenarios

This document outlines the complete user flows that need to be tested for the SSH WebSocket tunnel enhancement.

## Test Scenario 1: User Login and Tunnel Connection Establishment

**Objective:** Verify that users can log in via Auth0 and establish a tunnel connection.

**Steps:**
1. User launches the application
2. User clicks "Login" button
3. Auth0 OAuth flow is initiated
4. User enters credentials and authenticates
5. Application receives JWT token
6. TunnelService is initialized with auth token
7. TunnelService connects to streaming-proxy server
8. WebSocket connection is established
9. SSH tunnel is created to local server

**Expected Results:**
- User is authenticated successfully
- JWT token is stored securely
- WebSocket connection shows "Connected" status
- Tunnel health metrics show active connection
- No errors in logs

**Requirements Verified:**
- Requirement 1: Connection Resilience (connection establishment)
- Requirement 4: Multi-Tenant Security (JWT validation)
- Requirement 6: WebSocket Connection Management (connection establishment)

---

## Test Scenario 2: Request Forwarding Through Tunnel

**Objective:** Verify that requests are correctly forwarded through the tunnel to the local server.

**Steps:**
1. User is logged in and tunnel is connected
2. User sends an Ollama API request (e.g., GET /api/tags)
3. Request is queued in PersistentRequestQueue
4. Request is forwarded through WebSocket to streaming-proxy
5. streaming-proxy validates request with RateLimiter
6. streaming-proxy forwards request through SSH tunnel
7. Local Ollama server processes request
8. Response is sent back through tunnel
9. Response is delivered to client
10. Metrics are recorded

**Expected Results:**
- Request is successfully forwarded
- Response is received with correct status code
- Response data matches expected format
- Metrics show request latency and success
- No data corruption during transmission

**Requirements Verified:**
- Requirement 3: Performance Monitoring (metrics collection)
- Requirement 5: Request Queuing (queue management)
- Requirement 6: WebSocket Connection Management (message handling)
- Requirement 7: SSH Protocol Enhancements (SSH forwarding)

---

## Test Scenario 3: Disconnection and Automatic Reconnection

**Objective:** Verify that the tunnel automatically reconnects after network failure.

**Steps:**
1. User is logged in and tunnel is connected
2. Simulate network failure (disconnect WiFi or kill connection)
3. TunnelService detects connection loss
4. ReconnectionManager initiates exponential backoff
5. Pending requests are queued
6. Network is restored
7. TunnelService reconnects to streaming-proxy
8. WebSocket connection is re-established
9. SSH tunnel is recreated
10. Queued requests are flushed
11. Metrics are updated

**Expected Results:**
- Connection loss is detected within 45 seconds
- Automatic reconnection is triggered
- Reconnection succeeds within 5 seconds
- Queued requests are preserved
- Queued requests are sent after reconnection
- Reconnection metrics are recorded
- User sees "Reconnecting..." status

**Requirements Verified:**
- Requirement 1: Connection Resilience (auto-reconnection)
- Requirement 3: Performance Monitoring (reconnection metrics)
- Requirement 5: Request Queuing (queue persistence)
- Requirement 6: WebSocket Connection Management (heartbeat detection)

---

## Test Scenario 4: Error Scenarios

### 4a: Authentication Failure (Invalid JWT Token)

**Steps:**
1. User attempts to connect with invalid JWT token
2. streaming-proxy validates token
3. Token validation fails
4. Error response is sent to client

**Expected Results:**
- Connection is rejected with 401 Unauthorized
- Error message indicates authentication failure
- User is prompted to re-authenticate
- Error is logged with audit trail

**Requirements Verified:**
- Requirement 2: Enhanced Error Handling (error categorization)
- Requirement 4: Multi-Tenant Security (JWT validation)

### 4b: Network Failure (Server Unreachable)

**Steps:**
1. User attempts to connect to unreachable server
2. Connection attempt times out
3. Error is caught and categorized

**Expected Results:**
- Connection fails with clear error message
- Error suggests checking network/firewall
- Automatic reconnection is triggered
- Error is logged

**Requirements Verified:**
- Requirement 1: Connection Resilience (error recovery)
- Requirement 2: Enhanced Error Handling (error categorization)

### 4c: Server Error (streaming-proxy returns 500)

**Steps:**
1. User sends request while server is experiencing error
2. streaming-proxy returns 500 error
3. CircuitBreaker detects failure
4. Request is retried or queued

**Expected Results:**
- Error is caught and handled gracefully
- CircuitBreaker enters OPEN state after threshold
- Requests are queued during outage
- CircuitBreaker recovers after timeout
- User sees appropriate error message

**Requirements Verified:**
- Requirement 2: Enhanced Error Handling (error recovery)
- Requirement 5: Request Queuing (backpressure)

### 4d: Rate Limit Exceeded

**Steps:**
1. User sends requests exceeding rate limit (>100 req/min)
2. RateLimiter detects violation
3. Request is rejected with 429 Too Many Requests

**Expected Results:**
- Request is rejected with 429 status
- Error message indicates rate limit exceeded
- Retry-After header is provided
- Metrics record rate limit violation
- User is notified

**Requirements Verified:**
- Requirement 3: Performance Monitoring (rate limit metrics)
- Requirement 4: Multi-Tenant Security (rate limiting)

---

## Test Scenario 5: Configuration Changes

**Objective:** Verify that configuration changes are applied correctly.

**Steps:**
1. User is logged in and tunnel is connected
2. User opens Tunnel Settings
3. User changes profile from "Stable" to "Unstable"
4. Configuration is validated
5. Configuration is saved
6. TunnelService is notified of config change
7. Tunnel reconnects with new configuration
8. New settings are applied

**Expected Results:**
- Configuration is validated before saving
- Configuration is persisted to SharedPreferences
- Tunnel reconnects if necessary
- New settings are applied to reconnection logic
- Metrics show configuration change event

**Requirements Verified:**
- Requirement 9: Configuration and Customization (config management)
- Requirement 1: Connection Resilience (reconnection with new config)

---

## Test Scenario 6: Graceful Shutdown and State Restoration

**Objective:** Verify that pending requests are preserved during shutdown and restored on restart.

**Steps:**
1. User is logged in and tunnel is connected
2. User sends multiple requests
3. Some requests are still pending
4. User closes application
5. TunnelService initiates graceful shutdown
6. Pending requests are persisted
7. SSH disconnect message is sent
8. WebSocket is closed with code 1000
9. Application exits
10. User restarts application
11. TunnelService loads persisted requests
12. Tunnel reconnects
13. Persisted requests are sent

**Expected Results:**
- Pending requests are persisted to disk
- Graceful shutdown completes within 10 seconds
- SSH disconnect message is sent
- WebSocket closes with proper close code
- Persisted requests are restored on restart
- Restored requests are sent after reconnection
- No data loss

**Requirements Verified:**
- Requirement 8: Graceful Shutdown and Cleanup (shutdown handling)
- Requirement 5: Request Queuing (persistence)
- Requirement 1: Connection Resilience (state restoration)

---

## Test Scenario 7: Diagnostics

**Objective:** Verify that diagnostics provide accurate information about tunnel health.

**Steps:**
1. User is logged in
2. User opens Tunnel Settings
3. User clicks "Run Diagnostics"
4. Diagnostic tests are executed:
   - DNS Resolution test
   - WebSocket Connectivity test
   - SSH Authentication test
   - Tunnel Establishment test
   - Data Transfer test
   - Latency test
   - Throughput test
5. Results are displayed to user

**Expected Results:**
- All tests complete within 30 seconds
- Test results are accurate
- Failed tests show error messages
- Recommendations are provided for failures
- Results can be shared for support

**Requirements Verified:**
- Requirement 2: Enhanced Error Handling (diagnostics)
- Requirement 11: Monitoring and Observability (diagnostics endpoint)

---

## Test Scenario 8: Multi-Tenant Isolation

**Objective:** Verify that user tunnels are completely isolated from each other.

**Steps:**
1. User A logs in and connects tunnel
2. User B logs in and connects tunnel
3. User A sends request through tunnel
4. User B sends request through tunnel
5. Verify that User A's data doesn't leak to User B
6. Verify that User A's connection pool is separate from User B's
7. Verify that User A's rate limit is independent from User B's

**Expected Results:**
- Each user has separate connection pool
- Each user has separate rate limit quota
- User A's requests don't affect User B's quota
- User A's data is not visible to User B
- Metrics are tracked separately per user

**Requirements Verified:**
- Requirement 4: Multi-Tenant Security (isolation)
- Requirement 3: Performance Monitoring (per-user metrics)

---

## Test Execution Plan

### Phase 1: Manual Testing (Week 1)
- Execute scenarios 1-3 manually
- Verify basic functionality
- Document any issues

### Phase 2: Automated Testing (Week 2)
- Create automated tests for scenarios 1-8
- Run tests in CI/CD pipeline
- Measure code coverage

### Phase 3: Load Testing (Week 3)
- Test with 100+ concurrent connections
- Test with 1000+ requests per second
- Measure performance metrics

### Phase 4: Chaos Testing (Week 4)
- Simulate random network failures
- Simulate server crashes
- Verify recovery mechanisms

---

## Success Criteria

- All 8 test scenarios pass
- No data loss during failures
- Automatic reconnection succeeds >99% of the time
- Graceful shutdown completes within 10 seconds
- Diagnostics provide accurate information
- Multi-tenant isolation is verified
- Performance metrics meet requirements
- No security vulnerabilities found

