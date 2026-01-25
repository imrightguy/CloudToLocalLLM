# Tunnel Server API Documentation

## Overview

The Tunnel Server API provides REST endpoints and WebSocket protocol for managing secure SSH-over-WebSocket tunnels. This document describes all endpoints, message formats, and error codes.

## Base URL

```
https://proxy.cloudtolocalllm.online
```

## Authentication

All requests require a valid JWT token in the `Authorization` header:

```
Authorization: Bearer <JWT_TOKEN>
```

The JWT token is validated on every request. Expired tokens will result in a 401 response.

## REST Endpoints

### Health Check

#### GET /api/tunnel/health

Returns the health status of the tunnel service.

**Request:**
```http
GET /api/tunnel/health HTTP/1.1
Host: proxy.cloudtolocalllm.online
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "uptime": 86400,
  "activeConnections": 42,
  "healthyConnections": 42,
  "unhealthyConnections": 0,
  "averageLatency": 45.2,
  "version": "3.0.0"
}
```

**Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "reason": "High error rate detected",
  "activeConnections": 42,
  "healthyConnections": 35,
  "unhealthyConnections": 7
}
```

**Use Case:** Load balancer health checks, monitoring

---

### Diagnostics

#### GET /api/tunnel/diagnostics

Returns detailed diagnostic information about the tunnel service.

**Request:**
```http
GET /api/tunnel/diagnostics HTTP/1.1
Host: proxy.cloudtolocalllm.online
Authorization: Bearer <JWT_TOKEN>
```

**Response (200 OK):**
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "service": {
    "version": "3.0.0",
    "uptime": 86400,
    "startTime": "2024-01-14T10:30:00Z"
  },
  "connections": {
    "active": 42,
    "total": 1250,
    "byUser": {
      "user-123": 2,
      "user-456": 1
    }
  },
  "requests": {
    "total": 50000,
    "successful": 49750,
    "failed": 250,
    "successRate": 0.995,
    "averageLatency": 45.2,
    "p95Latency": 120.5,
    "p99Latency": 250.3
  },
  "errors": {
    "network": 50,
    "authentication": 10,
    "rateLimit": 100,
    "server": 50,
    "protocol": 40
  },
  "circuitBreaker": {
    "state": "closed",
    "failureCount": 0,
    "successCount": 0
  },
  "resources": {
    "memoryUsage": 256,
    "cpuUsage": 25.5,
    "connections": 42
  }
}
```

**Use Case:** Troubleshooting, monitoring, performance analysis

---

### Metrics

#### GET /api/tunnel/metrics

Returns Prometheus-format metrics for scraping.

**Request:**
```http
GET /api/tunnel/metrics HTTP/1.1
Host: proxy.cloudtolocalllm.online
```

**Response (200 OK):**
```
# HELP tunnel_requests_total Total number of tunnel requests
# TYPE tunnel_requests_total counter
tunnel_requests_total{status="success"} 49750
tunnel_requests_total{status="error"} 250

# HELP tunnel_request_latency_ms Request latency in milliseconds
# TYPE tunnel_request_latency_ms histogram
tunnel_request_latency_ms_bucket{le="10"} 5000
tunnel_request_latency_ms_bucket{le="50"} 40000
tunnel_request_latency_ms_bucket{le="100"} 48000
tunnel_request_latency_ms_bucket{le="200"} 49500
tunnel_request_latency_ms_bucket{le="500"} 49700
tunnel_request_latency_ms_bucket{le="1000"} 49750
tunnel_request_latency_ms_bucket{le="+Inf"} 49750
tunnel_request_latency_ms_sum 2237500
tunnel_request_latency_ms_count 49750

# HELP tunnel_active_connections Number of active tunnel connections
# TYPE tunnel_active_connections gauge
tunnel_active_connections{user_tier="free"} 20
tunnel_active_connections{user_tier="premium"} 15
tunnel_active_connections{user_tier="enterprise"} 7

# HELP tunnel_errors_total Total number of tunnel errors
# TYPE tunnel_errors_total counter
tunnel_errors_total{category="network"} 50
tunnel_errors_total{category="authentication"} 10
tunnel_errors_total{category="rateLimit"} 100
tunnel_errors_total{category="server"} 50
tunnel_errors_total{category="protocol"} 40

# HELP tunnel_queue_size Number of queued requests
# TYPE tunnel_queue_size gauge
tunnel_queue_size{user_id="user-123"} 5
tunnel_queue_size{user_id="user-456"} 0

# HELP tunnel_circuit_breaker_state Circuit breaker state (0=closed, 1=open, 2=half-open)
# TYPE tunnel_circuit_breaker_state gauge
tunnel_circuit_breaker_state{service="ssh"} 0
```

**Use Case:** Prometheus scraping, Grafana dashboards, monitoring

---

### Configuration

#### GET /api/tunnel/config

Returns current tunnel configuration (admin only).

**Request:**
```http
GET /api/tunnel/config HTTP/1.1
Host: proxy.cloudtolocalllm.online
Authorization: Bearer <ADMIN_JWT_TOKEN>
```

**Response (200 OK):**
```json
{
  "websocket": {
    "port": 3001,
    "path": "/ws",
    "pingInterval": 30000,
    "pongTimeout": 5000,
    "maxFrameSize": 1048576,
    "compression": true
  },
  "ssh": {
    "keepAliveInterval": 60000,
    "maxChannelsPerConnection": 10,
    "compression": true,
    "algorithms": {
      "kex": ["curve25519-sha256"],
      "cipher": ["aes256-gcm@openssh.com"],
      "mac": ["hmac-sha2-256"]
    }
  },
  "rateLimit": {
    "global": {
      "requestsPerMinute": 10000,
      "maxConcurrentConnections": 1000
    },
    "perUser": {
      "free": {
        "requestsPerMinute": 100,
        "maxConcurrentConnections": 1
      },
      "premium": {
        "requestsPerMinute": 1000,
        "maxConcurrentConnections": 3
      },
      "enterprise": {
        "requestsPerMinute": 10000,
        "maxConcurrentConnections": 10
      }
    }
  },
  "connection": {
    "maxConnectionsPerUser": 3,
    "idleTimeout": 300000,
    "staleConnectionCheckInterval": 60000
  },
  "circuitBreaker": {
    "failureThreshold": 5,
    "successThreshold": 2,
    "timeout": 60000,
    "resetTimeout": 60000
  },
  "monitoring": {
    "metricsEnabled": true,
    "metricsPort": 3001,
    "tracingEnabled": true,
    "logLevel": "info"
  }
}
```

**Response (403 Forbidden):**
```json
{
  "error": "Insufficient permissions",
  "code": "TUNNEL_002"
}
```

**Use Case:** Configuration review, monitoring

---

#### PUT /api/tunnel/config

Updates tunnel configuration (admin only).

**Request:**
```http
PUT /api/tunnel/config HTTP/1.1
Host: proxy.cloudtolocalllm.online
Authorization: Bearer <ADMIN_JWT_TOKEN>
Content-Type: application/json

{
  "rateLimit": {
    "perUser": {
      "free": {
        "requestsPerMinute": 150,
        "maxConcurrentConnections": 2
      }
    }
  },
  "monitoring": {
    "logLevel": "debug"
  }
}
```

**Response (200 OK):**
```json
{
  "message": "Configuration updated successfully",
  "changes": {
    "rateLimit.perUser.free.requestsPerMinute": "100 -> 150",
    "rateLimit.perUser.free.maxConcurrentConnections": "1 -> 2",
    "monitoring.logLevel": "info -> debug"
  }
}
```

**Response (400 Bad Request):**
```json
{
  "error": "Invalid configuration",
  "details": [
    "rateLimit.perUser.free.requestsPerMinute must be between 10 and 100000"
  ],
  "code": "TUNNEL_010"
}
```

**Use Case:** Configuration updates, tuning

---

## WebSocket Protocol

### Connection Establishment

**Client initiates WebSocket upgrade:**
```http
GET /ws HTTP/1.1
Host: proxy.cloudtolocalllm.online
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Authorization: Bearer <JWT_TOKEN>
```

**Server responds:**
```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

### Message Format

All WebSocket messages are JSON-encoded:

```json
{
  "type": "request|response|ping|pong|error",
  "id": "msg-123",
  "requestId": "req-456",
  "timestamp": "2024-01-15T10:30:00Z",
  "payload": {},
  "error": null
}
```

### Message Types

#### Request Message

Client sends request through tunnel:

```json
{
  "type": "request",
  "id": "msg-123",
  "requestId": "req-456",
  "timestamp": "2024-01-15T10:30:00Z",
  "payload": {
    "method": "GET",
    "path": "/api/users",
    "headers": {
      "Content-Type": "application/json"
    },
    "body": null,
    "timeout": 30000
  }
}
```

#### Response Message

Server sends response back to client:

```json
{
  "type": "response",
  "id": "msg-124",
  "requestId": "req-456",
  "timestamp": "2024-01-15T10:30:01Z",
  "payload": {
    "statusCode": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]",
    "latency": 1000
  }
}
```

#### Ping Message

Server sends ping to detect connection loss:

```json
{
  "type": "ping",
  "id": "msg-125",
  "timestamp": "2024-01-15T10:30:30Z"
}
```

#### Pong Message

Client responds to ping:

```json
{
  "type": "pong",
  "id": "msg-126",
  "timestamp": "2024-01-15T10:30:30Z"
}
```

#### Error Message

Server sends error to client:

```json
{
  "type": "error",
  "id": "msg-127",
  "requestId": "req-456",
  "timestamp": "2024-01-15T10:30:02Z",
  "error": {
    "code": "TUNNEL_005",
    "category": "rateLimit",
    "message": "Rate limit exceeded",
    "userMessage": "Too many requests. Please try again later.",
    "suggestion": "Reduce request rate or upgrade to premium tier"
  }
}
```

### Connection Lifecycle

**Heartbeat:**
- Server sends ping every 30 seconds
- Client must respond with pong within 5 seconds
- If no pong received, server closes connection

**Idle Timeout:**
- Connection closed after 5 minutes of inactivity
- Activity includes any message (request, response, ping, pong)

**Graceful Close:**
- Client sends close frame with code 1000 (normal closure)
- Server responds with close frame
- Connection terminated cleanly

**Abnormal Close:**
- Connection lost without close frame
- Client automatically reconnects with exponential backoff
- Server cleans up connection after 60 seconds

### Close Codes

| Code | Meaning | Recovery |
|------|---------|----------|
| 1000 | Normal closure | No action needed |
| 1001 | Going away | Reconnect |
| 1002 | Protocol error | Reconnect with backoff |
| 1003 | Unsupported data | Check message format |
| 1006 | Abnormal closure | Reconnect with backoff |
| 1008 | Policy violation | Check authentication |
| 1009 | Message too big | Reduce message size |
| 1011 | Server error | Reconnect with backoff |

## Error Codes

### Error Code Reference

| Code | Category | HTTP Status | Description | Recovery |
|------|----------|-------------|-------------|----------|
| TUNNEL_001 | network | 503 | Connection refused | Check network, firewall, server availability |
| TUNNEL_002 | authentication | 401 | Authentication failed | Verify JWT token, check Auth0 configuration |
| TUNNEL_003 | authentication | 401 | Token expired | Refresh token or re-authenticate |
| TUNNEL_004 | server | 503 | Server unavailable | Wait and retry, check server status |
| TUNNEL_005 | server | 429 | Rate limit exceeded | Reduce request rate, wait for reset |
| TUNNEL_006 | server | 507 | Queue full | Reduce request rate, increase queue size |
| TUNNEL_007 | protocol | 408 | Request timeout | Increase timeout, check server load |
| TUNNEL_008 | protocol | 502 | SSH error | Check SSH server, verify credentials |
| TUNNEL_009 | protocol | 502 | WebSocket error | Check WebSocket support, try alternative method |
| TUNNEL_010 | configuration | 400 | Configuration error | Validate settings, reset to defaults |

### Error Response Format

```json
{
  "error": {
    "code": "TUNNEL_005",
    "category": "rateLimit",
    "message": "Rate limit exceeded: 100 requests per minute",
    "userMessage": "Too many requests. Please try again later.",
    "suggestion": "Reduce request rate or upgrade to premium tier",
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "req-456",
    "retryAfter": 60
  }
}
```

## Rate Limiting

### Rate Limit Headers

All responses include rate limit information:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705318200
```

### Rate Limit Behavior

- **Per-user limits**: 100 requests/minute (free tier)
- **Per-IP limits**: 1000 requests/minute (global)
- **Burst handling**: Token bucket algorithm with 10-second window
- **Exceeded response**: 429 Too Many Requests

### Rate Limit Reset

Rate limits reset every minute. The `X-RateLimit-Reset` header indicates the Unix timestamp when the limit resets.

## Common Use Cases

### Establishing a Tunnel Connection

```bash
# 1. Get JWT token from Auth0
TOKEN=$(curl -X POST https://auth.cloudtolocalllm.online/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://api.cloudtolocalllm.online",
    "grant_type": "client_credentials"
  }' | jq -r '.access_token')

# 2. Connect to WebSocket
wscat -c wss://proxy.cloudtolocalllm.online/ws \
  -H "Authorization: Bearer $TOKEN"

# 3. Send request through tunnel
{
  "type": "request",
  "id": "msg-1",
  "requestId": "req-1",
  "payload": {
    "method": "GET",
    "path": "/api/users",
    "headers": {},
    "timeout": 30000
  }
}
```

### Monitoring Tunnel Health

```bash
# Check health status
curl https://proxy.cloudtolocalllm.online/api/tunnel/health

# Get detailed diagnostics
curl -H "Authorization: Bearer $TOKEN" \
  https://proxy.cloudtolocalllm.online/api/tunnel/diagnostics

# Scrape Prometheus metrics
curl https://proxy.cloudtolocalllm.online/api/tunnel/metrics
```

### Handling Errors

```bash
# Rate limit error
curl -H "Authorization: Bearer $TOKEN" \
  https://proxy.cloudtolocalllm.online/api/tunnel/health

# Response:
# HTTP/1.1 429 Too Many Requests
# X-RateLimit-Remaining: 0
# X-RateLimit-Reset: 1705318200
# {
#   "error": {
#     "code": "TUNNEL_005",
#     "message": "Rate limit exceeded",
#     "retryAfter": 60
#   }
# }
```

## Best Practices

1. **Always include Authorization header**: All requests require valid JWT token
2. **Handle rate limiting**: Implement exponential backoff for 429 responses
3. **Monitor connection health**: Check `/api/tunnel/health` regularly
4. **Implement heartbeat handling**: Respond to ping messages within 5 seconds
5. **Use correlation IDs**: Include requestId for request tracing
6. **Handle close codes**: Implement appropriate recovery for each close code
7. **Validate message format**: Ensure all WebSocket messages are valid JSON
8. **Implement timeouts**: Set appropriate timeouts for requests
9. **Log errors**: Log all errors with full context for debugging
10. **Test error scenarios**: Test network failures, timeouts, and rate limiting

## Deployment Considerations

### Load Balancing

- Use round-robin load balancing for multiple instances
- Sticky sessions not required (stateless design)
- Health check endpoint: `/api/tunnel/health`

### Scaling

- Horizontal scaling: Add more instances behind load balancer
- Vertical scaling: Increase CPU/memory per instance
- Connection limits: ~100 concurrent connections per instance

### Monitoring

- Scrape metrics from `/api/tunnel/metrics` every 15 seconds
- Alert on error rate > 5% over 5 minutes
- Alert on circuit breaker open state
- Monitor latency p95 > 200ms

### Security

- Enable TLS 1.3 for all connections
- Validate JWT tokens on every request
- Implement rate limiting per user and IP
- Log all authentication attempts
- Audit all configuration changes
