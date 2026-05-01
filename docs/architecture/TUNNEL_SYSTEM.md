# SSH WebSocket Tunnel System Architecture

> Status: legacy/fallback architecture.
>
> CloudToLocalLLM's current product direction is Tailscale-first secure device mesh with one isolated cloud connector container per user. New multi-device and cloud-connector work should start with [Secure Device Mesh](SECURE_DEVICE_MESH.md). Keep this document for historical context and for any fallback path that still explicitly requires custom SSH/WebSocket tunneling.

## System Overview

The SSH WebSocket Tunnel System is a production-ready tunneling solution that enables secure, reliable communication between cloud-based services and local SSH servers. It bridges the gap between cloud applications and local resources through a resilient WebSocket transport layer with comprehensive error handling, performance monitoring, and multi-tenant security.

### Purpose

Enable users to securely access local SSH servers from cloud applications without exposing those servers to the internet, while maintaining high reliability, performance, and security standards.

### Goals

1. **Reliability**: Automatic recovery from network failures with zero data loss
2. **Performance**: Sub-100ms latency overhead with support for 1000+ concurrent connections
3. **Security**: Multi-tenant isolation with comprehensive audit logging
4. **Observability**: Real-time metrics and structured logging for troubleshooting
5. **Developer Experience**: Clear APIs, comprehensive documentation, and testing infrastructure

### Key Features

- **Connection Resilience**: Automatic reconnection with exponential backoff and jitter
- **Request Queuing**: Priority-based request queuing with disk persistence
- **Error Handling**: Comprehensive error categorization and recovery strategies
- **Performance Monitoring**: Real-time metrics collection and Prometheus integration
- **Multi-Tenant Security**: Strict user isolation with JWT validation and rate limiting
- **WebSocket Management**: Robust connection management with heartbeat monitoring
- **SSH Enhancements**: Modern SSH protocol with multiplexing and compression
- **Graceful Shutdown**: Clean resource cleanup and state persistence
- **Configuration**: Flexible configuration with predefined profiles
- **Observability**: Structured logging, OpenTelemetry tracing, and health checks

## System Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Desktop/Web Client                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  Tunnel Service  │  │  Request Queue   │  │  Metrics      │ │
│  │  - Connection    │  │  - Priority      │  │  - Latency    │ │
│  │  - Reconnection  │  │  - Backpressure  │  │  - Throughput │ │
│  │  - Health Check  │  │  - Persistence   │  │  - Errors     │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
│           │                      │                     │         │
│           └──────────────────────┴─────────────────────┘         │
│                              │                                   │
│                    ┌─────────▼─────────┐                        │
│                    │  WebSocket Client │                        │
│                    │  - Heartbeat      │                        │
│                    │  - Compression    │                        │
│                    │  - TLS 1.3        │                        │
│                    └─────────┬─────────┘                        │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                    WebSocket  │  (wss://)
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                      Streaming Proxy Server                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  WebSocket       │  │  Auth Middleware │  │  Rate Limiter │ │
│  │  Handler         │  │  - JWT Validate  │  │  - Per User   │ │
│  │  - Upgrade       │  │  - Token Refresh │  │  - Per IP     │ │
│  │  - Heartbeat     │  │  - Audit Log     │  │  - DDoS       │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬───────┘ │
│           │                     │                     │         │
│           └─────────────────────┴─────────────────────┘         │
│                              │                                   │
│                    ┌─────────▼─────────┐                        │
│                    │  Connection Pool  │                        │
│                    │  - Per User       │                        │
│                    │  - SSH Sessions   │                        │
│                    │  - Cleanup        │                        │
│                    └─────────┬─────────┘                        │
│                              │                                   │
│  ┌──────────────────┐  ┌─────▼──────────┐  ┌───────────────┐  │
│  │  Metrics         │  │  SSH Tunnel    │  │  Circuit      │  │
│  │  Collector       │  │  Manager       │  │  Breaker      │  │
│  │  - Prometheus    │  │  - Forward     │  │  - Failure    │  │
│  │  - OpenTelemetry │  │  - Multiplex   │  │  - Recovery   │  │
│  └──────────────────┘  └────────┬───────┘  └───────────────┘  │
└──────────────────────────────────┼──────────────────────────────┘
                                   │
                        SSH over   │  WebSocket
                                   │
┌──────────────────────────────────▼──────────────────────────────┐
│                      Local SSH Server                            │
│                      (User's Machine)                            │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow Sequence Diagram

```
Client                WebSocket              Server              SSH Server
  │                      │                      │                    │
  │  1. Connect          │                      │                    │
  ├─────────────────────>│                      │                    │
  │                      │  2. Upgrade          │                    │
  │                      ├─────────────────────>│                    │
  │                      │  3. Validate JWT     │                    │
  │                      │<─────────────────────┤                    │
  │  4. Connected        │                      │                    │
  │<─────────────────────┤                      │                    │
  │                      │                      │                    │
  │  5. Forward Request  │                      │                    │
  ├─────────────────────>│                      │                    │
  │                      │  6. Check Rate Limit │                    │
  │                      │  7. Get Connection   │                    │
  │                      │  8. Forward via SSH  │                    │
  │                      ├─────────────────────────────────────────>│
  │                      │                      │  9. Process        │
  │                      │                      │<─────────────────┤
  │  10. Response        │  11. Response        │                    │
  │<─────────────────────┤<─────────────────────┤                    │
  │                      │                      │                    │
  │  12. Heartbeat Ping  │                      │                    │
  ├─────────────────────>│                      │                    │
  │  13. Heartbeat Pong  │                      │                    │
  │<─────────────────────┤                      │                    │
```

## Component Responsibilities

### Client-Side Components

#### TunnelService

- **Purpose**: Manages the complete tunnel lifecycle from the client perspective
- **Responsibilities**:
  - Establish and maintain WebSocket connections
  - Implement reconnection logic with exponential backoff
  - Maintain connection state and health metrics
  - Provide public API for tunnel operations
  - Coordinate with other client components
- **Key Methods**:
  - `connect()`: Establish tunnel connection
  - `disconnect()`: Close tunnel gracefully
  - `forwardRequest()`: Send request through tunnel
  - `runDiagnostics()`: Execute diagnostic tests

#### RequestQueue

- **Purpose**: Buffer and manage requests during network issues or high load
- **Responsibilities**:
  - Queue requests with priority levels (high, normal, low)
  - Implement backpressure when queue reaches 80% capacity
  - Persist high-priority requests to disk
  - Restore persisted requests on startup
  - Flush queued requests after reconnection
- **Key Features**:
  - Priority-based processing
  - Disk persistence for reliability
  - Backpressure signaling
  - Configurable queue size

#### MetricsCollector

- **Purpose**: Track and expose client-side performance metrics
- **Responsibilities**:
  - Record request latency and success/failure
  - Track connection state changes
  - Calculate connection quality indicators
  - Export metrics for UI display
  - Log metrics for debugging
- **Key Metrics**:
  - Request latency (average, p95, p99)
  - Success rate
  - Reconnection count
  - Connection uptime
  - Error counts by category

#### WebSocketClient

- **Purpose**: Handle WebSocket protocol details and transport
- **Responsibilities**:
  - Manage WebSocket connection lifecycle
  - Implement ping/pong heartbeat (30-second interval)
  - Handle compression and encryption
  - Manage connection upgrades
  - Detect connection loss within 45 seconds
- **Key Features**:
  - TLS 1.3 encryption
  - Permessage-deflate compression
  - Automatic heartbeat
  - Connection loss detection

### Server-Side Components

#### WebSocketHandler

- **Purpose**: Accept and manage WebSocket connections from clients
- **Responsibilities**:
  - Handle WebSocket upgrade requests
  - Implement heartbeat monitoring
  - Route messages to appropriate handlers
  - Manage connection lifecycle
  - Handle graceful disconnection
- **Key Features**:
  - Connection upgrade handling
  - Heartbeat monitoring
  - Message routing
  - Lifecycle management

#### AuthMiddleware

- **Purpose**: Validate and manage user authentication
- **Responsibilities**:
  - Validate JWT tokens on every request
  - Handle token expiration and refresh
  - Implement audit logging
  - Enforce user isolation
  - Manage user context
- **Key Features**:
  - JWT validation
  - Token refresh
  - Audit logging
  - User context management

#### RateLimiter

- **Purpose**: Prevent abuse and ensure fair resource allocation
- **Responsibilities**:
  - Enforce per-user rate limits (100 req/min)
  - Enforce per-IP rate limits for DDoS protection
  - Track rate limit violations
  - Provide rate limit metrics
  - Support configurable limits per user tier
- **Key Features**:
  - Token bucket algorithm
  - Per-user limits
  - Per-IP limits
  - Violation tracking

#### ConnectionPool

- **Purpose**: Manage SSH connections efficiently
- **Responsibilities**:
  - Maintain SSH connections per user
  - Enforce connection limits (max 3 per user)
  - Handle connection cleanup
  - Provide connection reuse
  - Track connection health
- **Key Features**:
  - Per-user connection management
  - Connection limits
  - Automatic cleanup
  - Health tracking

#### SSHTunnelManager

- **Purpose**: Handle SSH protocol operations
- **Responsibilities**:
  - Manage SSH connections and channels
  - Implement channel multiplexing
  - Handle SSH keep-alive
  - Provide error recovery
  - Support SSH compression
- **Key Features**:
  - Channel multiplexing
  - Keep-alive messages
  - Compression support
  - Error recovery

#### CircuitBreaker

- **Purpose**: Prevent cascading failures
- **Responsibilities**:
  - Monitor request failures
  - Detect failure patterns
  - Stop forwarding when threshold exceeded
  - Implement automatic recovery
  - Provide failure metrics
- **Key Features**:
  - Failure detection
  - Automatic state transitions
  - Recovery mechanism
  - Metrics tracking

#### MetricsCollector

- **Purpose**: Collect and expose server-side metrics
- **Responsibilities**:
  - Track connection metrics
  - Track request metrics
  - Track performance metrics
  - Expose Prometheus metrics
  - Implement OpenTelemetry tracing
- **Key Metrics**:
  - Active connections
  - Request count and success rate
  - Latency percentiles
  - Error rates by category
  - Throughput

## Design Decisions and Rationales

### Why Circuit Breaker Pattern?

**Problem**: When the SSH server becomes unavailable or slow, the tunnel system can become overwhelmed with requests, leading to cascading failures and resource exhaustion.

**Solution**: Implement a circuit breaker that monitors failure rates and stops forwarding requests when a threshold is exceeded. This prevents the system from wasting resources on requests that will fail.

**Benefits**:

- Prevents cascading failures
- Reduces resource consumption
- Allows backend to recover
- Provides clear failure signals
- Enables automatic recovery

**Implementation**:

- Failure threshold: 5 consecutive failures
- Recovery timeout: 60 seconds
- Half-open state: Test recovery with limited requests

### Why Request Queue?

**Problem**: Network interruptions cause requests to be lost, and users have no visibility into what happened to their requests.

**Solution**: Implement a request queue that buffers requests during network issues and automatically flushes them after reconnection.

**Benefits**:

- Zero data loss during network issues
- Transparent to application
- Priority-based processing
- Disk persistence for reliability
- Backpressure signaling

**Implementation**:

- Priority levels: high (interactive), normal (batch), low (background)
- Disk persistence for high-priority requests
- Backpressure at 80% queue capacity
- Automatic flush after reconnection

### Why Connection Pool?

**Problem**: Creating a new SSH connection for each request is expensive and inefficient, leading to high latency and resource consumption.

**Solution**: Implement a connection pool that reuses SSH connections across multiple requests.

**Benefits**:

- Reduced connection overhead
- Lower latency
- Better resource utilization
- Improved throughput
- Per-user isolation

**Implementation**:

- Per-user connection management
- Max 3 connections per user
- Automatic cleanup of idle connections
- Connection health monitoring

### Why Exponential Backoff?

**Problem**: When the server is unavailable, immediately retrying can overwhelm it and delay recovery.

**Solution**: Implement exponential backoff with jitter to gradually increase retry delays.

**Benefits**:

- Reduces server load during recovery
- Faster recovery than fixed delays
- Prevents thundering herd
- Configurable limits

**Implementation**:

- Base delay: 2 seconds
- Exponential multiplier: 2x per attempt
- Jitter: 30% random variation
- Max delay: 60 seconds
- Max attempts: 10

## Security Architecture

### Authentication

**JWT Token Validation**:

- Every request validates JWT token
- Token expiration checked on every request
- Expired tokens trigger refresh or re-authentication
- Invalid tokens result in immediate disconnection

**Token Refresh**:

- Automatic refresh before expiration
- Graceful handling of refresh failures
- User re-authentication on refresh failure

### Authorization

**User Isolation**:

- Each user has separate SSH connections
- No cross-user data access
- Per-user rate limiting
- Per-user connection limits

**Role-Based Access Control**:

- User tier system (free, premium, enterprise)
- Different rate limits per tier
- Different feature access per tier

### Encryption

**Transport Security**:

- TLS 1.3 for all WebSocket connections
- Modern cipher suites
- Certificate validation

**SSH Protocol**:

- SSH protocol version 2 only
- Modern key exchange algorithms (curve25519-sha256)
- AES-256-GCM encryption
- HMAC-SHA2 authentication

### Audit Logging

**Events Logged**:

- Authentication attempts (success/failure)
- Connection establishment/closure
- Rate limit violations
- Error conditions
- Configuration changes

**Log Format**:

- Structured JSON format
- Correlation IDs for request tracing
- Timestamps in UTC
- User context included

## Deployment Architecture

### Kubernetes Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Ingress (nginx)                        │  │
│  │  - TLS termination                                        │  │
│  │  - WebSocket support                                      │  │
│  │  - Rate limiting                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Streaming Proxy Service                     │  │
│  │  - ClusterIP service                                     │  │
│  │  - Port 3001                                             │  │
│  └──────────────────────────┬──────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │         Streaming Proxy Deployment (HPA)                │  │
│  │  - Min replicas: 2 (HA)                                  │  │
│  │  - Max replicas: 10 (cost control)                       │  │
│  │  - CPU scaling: 70% target                               │  │
│  │  - Memory scaling: 80% target                            │  │
│  │  - Custom metrics: 100 connections/pod                   │  │
│  └──────────────────────────┬──────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Redis StatefulSet                           │  │
│  │  - Connection state storage                              │  │
│  │  - Persistent volume (10Gi)                              │  │
│  │  - Single replica (can scale for HA)                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Prometheus ServiceMonitor                   │  │
│  │  - Scrapes /api/tunnel/metrics                           │  │
│  │  - 15-second interval                                    │  │
│  │  - 15-day retention                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              AlertManager Configuration                  │  │
│  │  - Alert routing                                         │  │
│  │  - Email/Slack notifications                             │  │
│  │  - Alert grouping                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Scaling Strategy

**Horizontal Scaling**:

- Multiple streaming-proxy replicas behind load balancer
- Stateless design enables easy scaling
- Redis for shared state across instances

**Vertical Scaling**:

- Resource requests/limits per pod
- HPA for automatic scaling based on metrics
- Custom metrics for connection-based scaling

**Resource Limits**:

- CPU request: 100m, limit: 500m
- Memory request: 256Mi, limit: 512Mi
- Per pod: ~100 concurrent connections

## Performance Characteristics

### Latency

- Connection establishment: < 2 seconds (95th percentile)
- Request latency overhead: < 50ms (95th percentile)
- Heartbeat detection: 45 seconds maximum

### Throughput

- 1000+ requests/second per server instance
- 1000+ concurrent connections per instance
- Horizontal scaling for higher throughput

### Resource Usage

- Memory: < 100MB per 100 concurrent connections
- CPU: < 50% under normal load
- Network: Depends on request payload size

## Monitoring and Observability

### Metrics Collection

**Prometheus Metrics**:

- Counter: tunnel_requests_total
- Histogram: tunnel_request_latency_ms
- Gauge: tunnel_active_connections
- Counter: tunnel_errors_total
- Gauge: tunnel_queue_size
- Gauge: tunnel_circuit_breaker_state

**OpenTelemetry Tracing**:

- Distributed tracing for request flows
- Span attributes: userId, requestId, latency, connectionId
- Jaeger exporter for trace visualization

### Structured Logging

**Log Format**: JSON with structured fields

- timestamp: ISO 8601 UTC
- level: ERROR, WARN, INFO, DEBUG, TRACE
- message: Human-readable message
- userId: User identifier
- connectionId: Connection identifier
- correlationId: Request correlation ID
- context: Additional context fields

### Health Checks

**Liveness Probe**:

- Endpoint: GET /api/tunnel/health
- Interval: 10 seconds
- Timeout: 5 seconds
- Failure threshold: 3

**Readiness Probe**:

- Endpoint: GET /api/tunnel/health
- Interval: 5 seconds
- Timeout: 3 seconds
- Failure threshold: 1

## Error Handling and Recovery

### Error Categories

1. **Network Errors**: Connection refused, DNS failure, timeout
2. **Authentication Errors**: Invalid token, expired token
3. **Configuration Errors**: Invalid settings, missing config
4. **Server Errors**: Server unavailable, rate limit exceeded
5. **Protocol Errors**: SSH error, WebSocket error

### Recovery Strategies

**Automatic Recovery**:

- Network errors: Exponential backoff reconnection
- Authentication errors: Token refresh or re-authentication
- Server errors: Circuit breaker with automatic reset
- Protocol errors: Fallback to alternative methods

**Manual Recovery**:

- Run diagnostics to identify issues
- Check logs for detailed error context
- Adjust configuration if needed
- Contact support if issues persist

## Conclusion

The SSH WebSocket Tunnel System provides a production-ready solution for secure, reliable tunneling with comprehensive error handling, performance monitoring, and multi-tenant security. The architecture is designed for scalability, reliability, and developer experience, with clear separation of concerns and well-defined component responsibilities.
