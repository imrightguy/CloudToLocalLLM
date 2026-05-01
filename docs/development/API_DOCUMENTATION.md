# CloudToLocalLLM API Documentation

## 📋 Overview

CloudToLocalLLM v3.6.2+ provides comprehensive APIs for bridge communication, streaming proxy management, and service integration. This document covers all available APIs for developers and integrators.

**API Base URLs:**

- **Production**: `https://app.cloudtolocalllm.online/api`
- **Local Development**: `http://localhost:3000/api`

---

## 🔐 **Authentication**

### **Auth0 JWT Authentication**

All API endpoints require valid JWT tokens obtained through Auth0 authentication.

#### **Token Format**

```http
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### **Token Validation**

- **Algorithm**: RS256
- **Issuer**: `https://CloudToLocalLLM.auth0.com/`
- **Audience**: `cloudtolocalllm-api`
- **Expiry**: 24 hours

#### **Error Responses**

```json
{
  "error": "unauthorized",
  "message": "Invalid or expired token",
  "code": 401
}
```

---

## 🌉 **Bridge API**

### **Desktop Bridge Communication**

#### **POST /api/bridge/register**

Register a desktop client with the bridge service.

**Request:**

```json
{
  "clientId": "desktop-client-uuid",
  "platform": "linux",
  "version": "3.6.2",
  "capabilities": ["ollama", "streaming", "tray"]
}
```

**Response:**

```json
{
  "success": true,
  "bridgeId": "bridge-uuid",
  "sessionToken": "session-jwt-token",
  "endpoints": {
    "websocket": "wss://app.cloudtolocalllm.online/ws/bridge/bridge-uuid",
    "status": "/api/bridge/bridge-uuid/status"
  }
}
```

#### **GET /api/bridge/{bridgeId}/status**

Get current bridge connection status.

**Response:**

```json
{
  "bridgeId": "bridge-uuid",
  "status": "connected",
  "lastSeen": "2025-06-20T16:52:20.850Z",
  "client": {
    "platform": "linux",
    "version": "3.6.2",
    "ollamaStatus": "connected",
    "models": ["llama3.2:1b", "codellama:7b"]
  }
}
```

#### **POST /api/bridge/{bridgeId}/message**

Send message to desktop client through bridge.

**Request:**

```json
{
  "type": "chat",
  "payload": {
    "model": "llama3.2:1b",
    "messages": [
      {
        "role": "user",
        "content": "Hello, how are you?"
      }
    ],
    "stream": true
  }
}
```

**Response:**

```json
{
  "success": true,
  "messageId": "msg-uuid",
  "status": "queued"
}
```

---

## 🔄 **Streaming Proxy API**

### **Proxy Lifecycle Management**

#### **POST /api/streaming/proxy/create**

Create ephemeral streaming proxy for user session.

**Request:**

```json
{
  "userId": "user-uuid",
  "bridgeId": "bridge-uuid",
  "config": {
    "timeout": 300,
    "maxMemory": "512MB",
    "maxCpu": "0.5"
  }
}
```

**Response:**

```json
{
  "success": true,
  "proxyId": "proxy-uuid",
  "endpoint": "https://proxy-uuid.cloudtolocalllm.online",
  "credentials": {
    "token": "proxy-access-token",
    "expires": "2025-06-20T17:52:20.850Z"
  }
}
```

#### **GET /api/streaming/proxy/{proxyId}/status**

Get streaming proxy status and metrics.

**Response:**

```json
{
  "proxyId": "proxy-uuid",
  "status": "running",
  "uptime": 1800,
  "metrics": {
    "requests": 45,
    "bytesTransferred": 1048576,
    "avgResponseTime": 120,
    "errorRate": 0.02
  },
  "resources": {
    "memoryUsage": "256MB",
    "cpuUsage": "15%"
  }
}
```

#### **DELETE /api/streaming/proxy/{proxyId}**

Terminate streaming proxy and cleanup resources.

**Response:**

```json
{
  "success": true,
  "message": "Proxy terminated and resources cleaned up"
}
```

---

## 💬 **Chat API**

### **Conversation Management**

#### **GET /api/chat/conversations**

List user's chat conversations.

**Query Parameters:**

- `limit`: Number of conversations (default: 50)
- `offset`: Pagination offset (default: 0)
- `sort`: Sort order (`created_desc`, `updated_desc`)

**Response:**

```json
{
  "conversations": [
    {
      "id": "conv-uuid",
      "title": "Chat about AI",
      "created": "2025-06-20T16:00:00.000Z",
      "updated": "2025-06-20T16:30:00.000Z",
      "messageCount": 12,
      "model": "llama3.2:1b"
    }
  ],
  "total": 25,
  "hasMore": true
}
```

#### **POST /api/chat/conversations**

Create new chat conversation.

**Request:**

```json
{
  "title": "New Chat",
  "model": "llama3.2:1b",
  "systemPrompt": "You are a helpful assistant."
}
```

**Response:**

```json
{
  "success": true,
  "conversation": {
    "id": "conv-uuid",
    "title": "New Chat",
    "created": "2025-06-20T17:00:00.000Z",
    "model": "llama3.2:1b"
  }
}
```

#### **POST /api/chat/conversations/{conversationId}/messages**

Send message in conversation.

**Request:**

```json
{
  "content": "What is machine learning?",
  "stream": true
}
```

**Response (Streaming):**

```json
{"type": "start", "messageId": "msg-uuid"}
{"type": "chunk", "content": "Machine learning is"}
{"type": "chunk", "content": " a subset of artificial"}
{"type": "chunk", "content": " intelligence..."}
{"type": "complete", "messageId": "msg-uuid", "totalTokens": 150}
```

---

## 📊 **Health and Monitoring**

### **System Health**

#### **GET /api/health**

Get overall system health status.

**Response:**

```json
{
  "status": "healthy",
  "timestamp": "2025-06-20T17:00:00.000Z",
  "services": {
    "api": "healthy",
    "database": "healthy",
    "auth": "healthy",
    "streaming": "healthy"
  },
  "metrics": {
    "uptime": 86400,
    "activeConnections": 42,
    "requestsPerMinute": 150
  }
}
```

#### **GET /api/health/detailed**

Get detailed health information for debugging.

**Response:**

```json
{
  "status": "healthy",
  "services": {
    "api": {
      "status": "healthy",
      "responseTime": 15,
      "memoryUsage": "256MB",
      "cpuUsage": "5%"
    },
    "database": {
      "status": "healthy",
      "connections": 10,
      "queryTime": 8
    }
  },
  "infrastructure": {
    "containerCount": 4,
    "networkLatency": 2,
    "diskUsage": "45%"
  }
}
```

---

## 🚇 **Simplified Tunnel System API**

> **Status**: Legacy/fallback API surface. Current connectivity design should prefer the Tailscale secure device mesh and agent-runtime-first setup wizard. Keep this section for existing tunnel maintenance and migration reference. Ollama examples in this section describe the older direct-provider path, not the primary app runtime contract.

### **Overview**

The Simplified Tunnel System replaced an older multi-layered bridge architecture with a single WebSocket connection and standard HTTP proxy patterns. This system provided secure communication between cloud interfaces and local Ollama instances in the older stack.

**Architecture:**

```
[Web User] → [Cloud Proxy] → [WebSocket] → [Desktop Client] → [Local Ollama]
     ↑              ↑             ↑              ↑              ↑
   Browser      Express.js    Single WS    SimpleTunnelClient  localhost:11434
```

### **Key Features**

- **Single WebSocket Connection**: One persistent connection per desktop client
- **Standard HTTP Proxy**: Containers use standard HTTP requests
- **JWT Authentication**: Simple token-based authentication
- **Request Correlation**: Unique IDs match requests with responses
- **30-Second Timeout**: Automatic timeout handling
- **User Isolation**: Strict user ID validation for security
- **Rate Limiting**: Per-user request limits (1000/15min, 100/1min burst)

### **Tunnel Endpoints**

#### **WebSocket Connection**

```
wss://api.cloudtolocalllm.online/ws/tunnel?token=<jwt_token>
```

**Authentication**: JWT token required as query parameter
**Connection Flow**:

1. Desktop client connects with JWT token
2. Server validates token and extracts user ID
3. Connection established with health monitoring
4. Client receives HTTP requests to forward to local Ollama

#### **HTTP Proxy Endpoints**

##### **GET /api/tunnel/health**

Check overall tunnel system health (no auth required)

**Response:**

```json
{
  "status": "healthy",
  "checks": {
    "hasConnections": true,
    "successRateOk": true,
    "timeoutRateOk": true,
    "averageResponseTimeOk": true
  },
  "connections": {
    "total": 5,
    "connectedUsers": 3
  },
  "requests": {
    "total": 1250,
    "successful": 1200,
    "successRate": 96.0,
    "timeoutRate": 1.6
  }
}
```

##### **GET /api/tunnel/health/:userId**

Check specific user's tunnel status (requires auth)

**Response:**

```json
{
  "userId": "auth0|user123",
  "connected": true,
  "lastPing": "2025-01-15T10:29:30Z",
  "pendingRequests": 2
}
```

##### **GET /api/tunnel/status**

Get user's tunnel status and system metrics (requires auth)

##### **GET /api/tunnel/metrics**

Get detailed performance metrics (requires auth)

##### **ALL /api/tunnel/:userId/***

Proxy HTTP requests to user's desktop client (requires auth)

**Example:**

```bash
# Proxy request to local Ollama
curl -X POST https://api.cloudtolocalllm.online/api/tunnel/auth0|user123/api/chat \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama2","prompt":"Hello"}'
```

**Error Responses:**

- `401 Unauthorized` - Missing/invalid JWT token
- `403 Forbidden` - Cross-user access attempt
- `503 Service Unavailable` - Desktop client not connected
- `504 Gateway Timeout` - Request timeout (30s)
- `429 Too Many Requests` - Rate limit exceeded

### **Message Protocol**

The tunnel uses a standardized JSON message protocol implemented in `api-backend/tunnel/message-protocol.js`.

#### **Message Types**

```javascript
const MESSAGE_TYPES = {
  HTTP_REQUEST: 'http_request',
  HTTP_RESPONSE: 'http_response',
  PING: 'ping',
  PONG: 'pong',
  ERROR: 'error'
};
```

#### **HTTP Request Message (Cloud → Desktop)**

```json
{
  "type": "http_request",
  "id": "req_abc123",
  "method": "POST",
  "path": "/api/chat",
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"model\":\"llama2\",\"prompt\":\"Hello\"}"
}
```

#### **HTTP Response Message (Desktop → Cloud)**

```json
{
  "type": "http_response",
  "id": "req_abc123",
  "status": 200,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"response\":\"Hello! How can I help?\"}"
}
```

#### **Health Monitoring Messages**

```json
// Ping (Cloud → Desktop)
{
  "type": "ping",
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}

// Pong (Desktop → Cloud)
{
  "type": "pong",
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### **Error Messages**

```json
{
  "type": "error",
  "id": "req_abc123",
  "error": "Request timeout",
  "code": "REQUEST_TIMEOUT"
}
```

### **Integration Examples**

#### **Container Integration**

```bash
# Set environment variable
export OLLAMA_BASE_URL="https://api.cloudtolocalllm.online/api/tunnel/${USER_ID}"

# Use standard HTTP client
curl -H "Authorization: Bearer ${JWT_TOKEN}" \
     "${OLLAMA_BASE_URL}/api/tags"
```

#### **Desktop Client Integration**

```dart
// Connect to tunnel WebSocket
final client = SimpleTunnelClient(authService: authService);
await client.connect();

// Handle incoming requests automatically
// Client forwards requests to localhost:11434
```

### **Migration from Legacy Bridge System**

**Key Changes:**

- **Single Connection**: Replaces multiple encrypted WebSocket connections
- **Standard HTTP**: Containers use standard HTTP instead of custom protocols
- **Simplified Auth**: JWT tokens replace complex authentication layers
- **Direct Proxy**: Eliminates intermediate bridge registration steps

**Backward Compatibility:**

- Container APIs remain unchanged (only environment variable update needed)
- Web interface APIs unchanged
- Desktop client requires update to SimpleTunnelClient

**Performance Improvements:**

- ~70% reduction in codebase complexity
- Faster connection establishment
- Lower memory usage
- Better error handling and debugging

---

## 🔌 **WebSocket API**

### **Real-time Communication**

#### **Connection Endpoint**

```
wss://app.cloudtolocalllm.online/ws/{type}/{id}
```

**Types:**

- `bridge/{bridgeId}`: Desktop bridge communication
- `chat/{conversationId}`: Real-time chat updates
- `status/{userId}`: System status updates

#### **Message Format**

```json
{
  "type": "message_type",
  "id": "message-uuid",
  "timestamp": "2025-06-20T17:00:00.000Z",
  "payload": {
    // Type-specific data
  }
}
```

#### **Bridge Messages**

```json
// Desktop → Cloud
{
  "type": "status_update",
  "payload": {
    "ollamaStatus": "connected",
    "models": ["llama3.2:1b"],
    "systemLoad": 0.15
  }
}

// Cloud → Desktop
{
  "type": "chat_request",
  "payload": {
    "model": "llama3.2:1b",
    "messages": [...],
    "stream": true
  }
}
```

---

## 🛠️ **Development Tools**

### **API Testing**

#### **Postman Collection**

Download the complete API collection:

```bash
curl -o cloudtolocalllm-api.json \
  https://raw.githubusercontent.com/CloudToLocalLLM-online/CloudToLocalLLM/main/docs/api/postman-collection.json
```

#### **OpenAPI Specification**

```bash
curl https://app.cloudtolocalllm.online/api/docs/openapi.json
```

### **Rate Limiting**

All APIs are rate-limited:

- **Authenticated Users**: 1000 requests/hour
- **Bridge Connections**: 10000 requests/hour
- **Streaming**: 100 concurrent connections

**Rate Limit Headers:**

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

---

## 🔧 **Error Handling**

### **Standard Error Format**

```json
{
  "error": "error_code",
  "message": "Human-readable error message",
  "code": 400,
  "details": {
    "field": "validation_error_details"
  },
  "requestId": "req-uuid"
}
```

### **Common Error Codes**

- `400`: Bad Request - Invalid input
- `401`: Unauthorized - Invalid/missing token
- `403`: Forbidden - Insufficient permissions
- `404`: Not Found - Resource doesn't exist
- `429`: Too Many Requests - Rate limit exceeded
- `500`: Internal Server Error - Server issue

---

**For additional API details, examples, and SDKs, visit the [GitHub repository](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM) or check the interactive API documentation at `/api/docs`.**
