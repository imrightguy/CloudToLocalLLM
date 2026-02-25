# Sandbox Environment Guide

## Overview

The Sandbox Environment provides a safe, isolated testing environment for developers to test API endpoints without affecting production data. It allows you to:

- Test API endpoints with mock data
- Simulate various scenarios without side effects
- Use pre-configured test credentials
- Monitor request/response behavior
- Validate integration before production deployment

## Enabling Sandbox Mode

### Environment Variables

To enable sandbox mode, set one of these environment variables:

```bash
# Option 1: Set SANDBOX_MODE to true
export SANDBOX_MODE=true

# Option 2: Set NODE_ENV to sandbox
export NODE_ENV=sandbox
```

### Configuration

Add to your `.env` file:

```env
# Sandbox Configuration
SANDBOX_MODE=true
NODE_ENV=sandbox
LOG_LEVEL=debug
```

### Docker Compose

For local development with Docker:

```yaml
services:
  api-backend:
    environment:
      - SANDBOX_MODE=true
      - NODE_ENV=sandbox
      - LOG_LEVEL=debug
```

## Test Credentials

### Pre-configured Test Users

The sandbox environment includes three pre-configured test users:

#### Free Tier User

```json
{
  "id": "test-user-1",
  "email": "test@sandbox.local",
  "auth0Id": "auth0|sandbox-test-1",
  "tier": "free",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMSIsImVtYWlsIjoidGVzdEBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-1"
}
```

#### Premium Tier User

```json
{
  "id": "test-user-2",
  "email": "premium@sandbox.local",
  "auth0Id": "auth0|sandbox-test-2",
  "tier": "premium",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMiIsImVtYWlsIjoicHJlbWl1bUBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-2"
}
```

#### Admin User

```json
{
  "id": "test-admin",
  "email": "admin@sandbox.local",
  "auth0Id": "auth0|sandbox-admin",
  "tier": "enterprise",
  "role": "admin",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LWFkbWluIiwiZW1haWwiOiJhZG1pbkBzYW5kYm94LmxvY2FsIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-admin"
}
```

### API Keys

Pre-configured API keys for service-to-service communication:

```json
{
  "key": "sk_sandbox_test_1234567890abcdef",
  "secret": "sandbox-secret-1",
  "name": "Test API Key 1",
  "tier": "free"
}
```

```json
{
  "key": "sk_sandbox_premium_abcdef1234567890",
  "secret": "sandbox-secret-2",
  "name": "Premium API Key",
  "tier": "premium"
}
```

## Sandbox API Endpoints

### Configuration

#### GET /sandbox/config

Get sandbox environment configuration.

**Response:**

```json
{
  "success": true,
  "config": {
    "enabled": true,
    "mode": "testing",
    "features": {
      "mockData": true,
      "noSideEffects": true,
      "requestLogging": true,
      "dataIsolation": true
    },
    "rateLimits": {
      "requestsPerMinute": 10000,
      "burstSize": 5000
    },
    "quotas": {
      "maxTunnels": 100,
      "maxWebhooks": 100,
      "maxUsers": 1000,
      "storageGB": 10
    }
  }
}
```

### Credentials

#### GET /sandbox/credentials

Get test credentials for sandbox environment.

**Response:**

```json
{
  "success": true,
  "credentials": {
    "users": [
      {
        "id": "test-user-1",
        "email": "test@sandbox.local",
        "tier": "free",
        "token": "..."
      }
    ],
    "apiKeys": [
      {
        "key": "sk_sandbox_test_1234567890abcdef",
        "secret": "sandbox-secret-1",
        "tier": "free"
      }
    ]
  }
}
```

### Mock Users

#### POST /sandbox/users

Create a mock user for testing.

**Request:**

```json
{
  "email": "testuser@example.com",
  "firstName": "Test",
  "lastName": "User",
  "tier": "free"
}
```

**Response:**

```json
{
  "success": true,
  "user": {
    "id": "sandbox-user-1670000000000",
    "email": "testuser@example.com",
    "tier": "free",
    "profile": {
      "firstName": "Test",
      "lastName": "User",
      "preferences": {
        "theme": "light",
        "language": "en",
        "notifications": true
      }
    },
    "createdAt": "2024-01-01T00:00:00.000Z",
    "isActive": true
  }
}
```

#### GET /sandbox/users/:userId

Get a mock user by ID.

**Response:**

```json
{
  "success": true,
  "user": {
    "id": "sandbox-user-1670000000000",
    "email": "testuser@example.com",
    "tier": "free",
    "profile": { ... },
    "createdAt": "2024-01-01T00:00:00.000Z",
    "isActive": true
  }
}
```

### Mock Tunnels

#### POST /sandbox/tunnels

Create a mock tunnel for testing.

**Request:**

```json
{
  "userId": "test-user-1",
  "name": "Test Tunnel"
}
```

**Response:**

```json
{
  "success": true,
  "tunnel": {
    "id": "sandbox-tunnel-1670000000000",
    "userId": "test-user-1",
    "name": "Test Tunnel",
    "status": "connected",
    "endpoints": [
      {
        "id": "endpoint-sandbox-tunnel-1670000000000",
        "url": "http://localhost:3000",
        "priority": 1,
        "weight": 100,
        "healthStatus": "healthy",
        "lastHealthCheck": "2024-01-01T00:00:00.000Z"
      }
    ],
    "config": {
      "maxConnections": 100,
      "timeout": 30000,
      "compression": true
    },
    "metrics": {
      "requestCount": 0,
      "successCount": 0,
      "errorCount": 0,
      "averageLatency": 0
    },
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

#### GET /sandbox/tunnels/:tunnelId

Get a mock tunnel by ID.

**Response:**

```json
{
  "success": true,
  "tunnel": { ... }
}
```

#### PATCH /sandbox/tunnels/:tunnelId/status

Update mock tunnel status.

**Request:**

```json
{
  "status": "disconnected"
}
```

**Response:**

```json
{
  "success": true,
  "tunnel": { ... }
}
```

#### POST /sandbox/tunnels/:tunnelId/metrics

Record mock tunnel metrics.

**Request:**

```json
{
  "requestCount": 10,
  "successCount": 9,
  "errorCount": 1,
  "latency": 45
}
```

**Response:**

```json
{
  "success": true,
  "tunnel": { ... }
}
```

### Mock Webhooks

#### POST /sandbox/webhooks

Create a mock webhook for testing.

**Request:**

```json
{
  "userId": "test-user-1",
  "url": "https://webhook.example.com/events",
  "events": ["tunnel.created", "tunnel.updated"]
}
```

**Response:**

```json
{
  "success": true,
  "webhook": {
    "id": "sandbox-webhook-1670000000000",
    "userId": "test-user-1",
    "url": "https://webhook.example.com/events",
    "events": ["tunnel.created", "tunnel.updated"],
    "active": true,
    "signature": "sandbox-sig-sandbox-webhook-1670000000000",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "deliveryStats": {
      "total": 0,
      "successful": 0,
      "failed": 0,
      "lastDelivery": null
    }
  }
}
```

### Request Logging

#### GET /sandbox/requests

Get request log from sandbox.

**Query Parameters:**

- `userId` (optional): Filter by user ID
- `method` (optional): Filter by HTTP method
- `path` (optional): Filter by request path
- `limit` (optional): Maximum number of entries (default: 100)

**Response:**

```json
{
  "success": true,
  "requests": [
    {
      "timestamp": "2024-01-01T00:00:00.000Z",
      "method": "POST",
      "path": "/api/tunnels",
      "userId": "test-user-1",
      "statusCode": 201,
      "responseTime": 45,
      "body": { ... }
    }
  ],
  "count": 1
}
```

### Statistics

#### GET /sandbox/stats

Get sandbox statistics.

**Response:**

```json
{
  "success": true,
  "stats": {
    "users": 5,
    "tunnels": 3,
    "webhooks": 2,
    "requestsLogged": 42,
    "enabled": true
  }
}
```

### Data Management

#### DELETE /sandbox/clear

Clear all sandbox data.

**Response:**

```json
{
  "success": true,
  "message": "Sandbox data cleared successfully"
}
```

## Usage Examples

### Example 1: Testing User Creation

```bash
# Get test credentials
curl http://localhost:8080/sandbox/credentials

# Create a mock user
curl -X POST http://localhost:8080/sandbox/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "tier": "premium"
  }'

# Retrieve the created user
curl http://localhost:8080/sandbox/users/sandbox-user-1670000000000
```

### Example 2: Testing Tunnel Operations

```bash
# Create a mock tunnel
curl -X POST http://localhost:8080/sandbox/tunnels \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-1",
    "name": "My Test Tunnel"
  }'

# Update tunnel status
curl -X PATCH http://localhost:8080/sandbox/tunnels/sandbox-tunnel-1670000000000/status \
  -H "Content-Type: application/json" \
  -d '{"status": "disconnected"}'

# Record metrics
curl -X POST http://localhost:8080/sandbox/tunnels/sandbox-tunnel-1670000000000/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "requestCount": 100,
    "successCount": 98,
    "errorCount": 2,
    "latency": 50
  }'
```

### Example 3: Monitoring Requests

```bash
# Get all requests
curl http://localhost:8080/sandbox/requests

# Get requests for specific user
curl "http://localhost:8080/sandbox/requests?userId=test-user-1"

# Get POST requests only
curl "http://localhost:8080/sandbox/requests?method=POST"

# Get requests to specific path
curl "http://localhost:8080/sandbox/requests?path=/api/tunnels"

# Get last 50 requests
curl "http://localhost:8080/sandbox/requests?limit=50"
```

### Example 4: Clearing Sandbox Data

```bash
# Get current statistics
curl http://localhost:8080/sandbox/stats

# Clear all sandbox data
curl -X DELETE http://localhost:8080/sandbox/clear

# Verify data is cleared
curl http://localhost:8080/sandbox/stats
```

## Features

### No Side Effects

- Mock data is isolated from production
- No actual tunnels are created
- No real webhooks are triggered
- Database writes are prevented

### Request Logging

- All requests are logged for debugging
- Includes method, path, user, status code, and response time
- Queryable by user, method, or path
- Useful for integration testing

### Data Isolation

- Sandbox data is completely separate from production
- Can be cleared at any time
- No impact on production systems

### Relaxed Rate Limiting

- 10,000 requests/minute (vs. 100 for production)
- Burst size of 5,000 requests
- Allows thorough testing without throttling

### Mock Data Management

- Create mock users, tunnels, and webhooks
- Update mock tunnel status and metrics
- Retrieve mock data by ID
- Clear all sandbox data

## Best Practices

### 1. Use Test Credentials

Always use the provided test credentials when testing in sandbox mode:

```bash
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMSIsImVtYWlsIjoidGVzdEBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-1
```

### 2. Monitor Request Logs

Regularly check request logs to verify your integration:

```bash
curl http://localhost:8080/sandbox/requests?limit=20
```

### 3. Clear Data Between Tests

Clear sandbox data between test runs to ensure clean state:

```bash
curl -X DELETE http://localhost:8080/sandbox/clear
```

### 4. Test Different Scenarios

Create mock data for different scenarios:

- Free tier users
- Premium tier users
- Admin users
- Multiple tunnels
- Various tunnel statuses

### 5. Verify Response Format

Check that responses match expected format:

```bash
curl http://localhost:8080/sandbox/config | jq .
```

## Troubleshooting

### Sandbox Mode Not Enabled

**Problem:** Getting "Sandbox mode is not enabled" error

**Solution:** Verify environment variables:

```bash
echo $SANDBOX_MODE
echo $NODE_ENV
```

Set them if not already set:

```bash
export SANDBOX_MODE=true
export NODE_ENV=sandbox
```

### Test Credentials Not Working

**Problem:** Authentication fails with test credentials

**Solution:** Ensure you're using the correct token format:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8080/sandbox/config
```

### Request Log Not Showing

**Problem:** Request log is empty

**Solution:** Verify requests are being made to sandbox endpoints:

```bash
curl http://localhost:8080/sandbox/stats
```

Check that the endpoint is returning data.

## Security Considerations

### Sandbox Mode Only for Development

- Never enable sandbox mode in production
- Sandbox mode disables authentication checks
- Sandbox mode allows unrestricted access to test data

### Test Credentials

- Test credentials are public and should never be used in production
- Test tokens are not validated against Auth0
- Use real credentials for production testing

### Data Isolation

- Sandbox data is completely isolated from production
- Clearing sandbox data does not affect production
- Sandbox requests do not trigger webhooks or side effects

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: API Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      api:
        image: ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/api:latest
        env:
          SANDBOX_MODE: true
          NODE_ENV: sandbox
        ports:
          - 8080:8080
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Wait for API
        run: sleep 10
      
      - name: Get sandbox config
        run: curl http://localhost:8080/sandbox/config
      
      - name: Create test user
        run: |
          curl -X POST http://localhost:8080/sandbox/users \
            -H "Content-Type: application/json" \
            -d '{"email": "test@example.com", "tier": "free"}'
      
      - name: Run integration tests
        run: npm run test:integration
```

## Related Documentation

- [API Documentation Guide](./API_DOCUMENTATION_GUIDE.md)
- [Authentication Guide](./AUTHENTICATION_GUIDE.md)
- [API Versioning Guide](./API_VERSIONING_GUIDE.md)
- [Rate Limit Documentation](./RATE_LIMIT_DOCUMENTATION.md)
