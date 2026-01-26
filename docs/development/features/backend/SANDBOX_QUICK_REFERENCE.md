# Sandbox Environment Quick Reference

## Enable Sandbox Mode

```bash
export SANDBOX_MODE=true
export NODE_ENV=sandbox
```

## Test Credentials

### Free User

- Email: `test@sandbox.local`
- Token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMSIsImVtYWlsIjoidGVzdEBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-1`

### Premium User

- Email: `premium@sandbox.local`
- Token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMiIsImVtYWlsIjoicHJlbWl1bUBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-2`

### Admin User

- Email: `admin@sandbox.local`
- Token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LWFkbWluIiwiZW1haWwiOiJhZG1pbkBzYW5kYm94LmxvY2FsIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-admin`

## Common Endpoints

### Configuration

```bash
GET /sandbox/config
GET /sandbox/credentials
GET /sandbox/stats
```

### Users

```bash
POST /sandbox/users
GET /sandbox/users/:userId
```

### Tunnels

```bash
POST /sandbox/tunnels
GET /sandbox/tunnels/:tunnelId
PATCH /sandbox/tunnels/:tunnelId/status
POST /sandbox/tunnels/:tunnelId/metrics
```

### Webhooks

```bash
POST /sandbox/webhooks
```

### Monitoring

```bash
GET /sandbox/requests
DELETE /sandbox/clear
```

## Quick Examples

### Get Sandbox Config

```bash
curl http://localhost:8080/sandbox/config
```

### Get Test Credentials

```bash
curl http://localhost:8080/sandbox/credentials
```

### Create Mock User

```bash
curl -X POST http://localhost:8080/sandbox/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "tier": "free"
  }'
```

### Create Mock Tunnel

```bash
curl -X POST http://localhost:8080/sandbox/tunnels \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-1",
    "name": "Test Tunnel"
  }'
```

### Update Tunnel Status

```bash
curl -X PATCH http://localhost:8080/sandbox/tunnels/sandbox-tunnel-1670000000000/status \
  -H "Content-Type: application/json" \
  -d '{"status": "disconnected"}'
```

### Record Tunnel Metrics

```bash
curl -X POST http://localhost:8080/sandbox/tunnels/sandbox-tunnel-1670000000000/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "requestCount": 100,
    "successCount": 98,
    "errorCount": 2,
    "latency": 50
  }'
```

### View Request Log

```bash
curl http://localhost:8080/sandbox/requests
```

### Filter Requests

```bash
# By user
curl "http://localhost:8080/sandbox/requests?userId=test-user-1"

# By method
curl "http://localhost:8080/sandbox/requests?method=POST"

# By path
curl "http://localhost:8080/sandbox/requests?path=/api/tunnels"

# Last N requests
curl "http://localhost:8080/sandbox/requests?limit=50"
```

### Get Sandbox Stats

```bash
curl http://localhost:8080/sandbox/stats
```

### Clear Sandbox Data

```bash
curl -X DELETE http://localhost:8080/sandbox/clear
```

## Features

- ✅ Mock data creation (users, tunnels, webhooks)
- ✅ Request logging and monitoring
- ✅ No side effects (isolated from production)
- ✅ Relaxed rate limiting (10,000 req/min)
- ✅ Test credentials included
- ✅ Data isolation
- ✅ Easy cleanup

## Rate Limits

| Limit | Value |
|-------|-------|
| Requests/minute | 10,000 |
| Burst size | 5,000 |
| Max tunnels | 100 |
| Max webhooks | 100 |
| Max users | 1,000 |
| Storage | 10 GB |

## Environment Variables

```env
# Enable sandbox mode
SANDBOX_MODE=true

# Set environment to sandbox
NODE_ENV=sandbox

# Enable debug logging
LOG_LEVEL=debug
```

## Docker Compose

```yaml
services:
  api-backend:
    environment:
      - SANDBOX_MODE=true
      - NODE_ENV=sandbox
      - LOG_LEVEL=debug
```

## Response Format

All sandbox responses include metadata:

```json
{
  "data": { ... },
  "_sandbox": {
    "mode": true,
    "timestamp": "2024-01-01T00:00:00.000Z",
    "requestId": "req-123"
  }
}
```

## Error Handling

Sandbox errors include detailed information:

```json
{
  "error": {
    "code": "SANDBOX_ERROR",
    "message": "Error message",
    "details": { ... },
    "_sandbox": {
      "mode": true,
      "timestamp": "2024-01-01T00:00:00.000Z",
      "requestId": "req-123",
      "stack": "..."
    }
  }
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Sandbox disabled | Set `SANDBOX_MODE=true` |
| Auth fails | Use test tokens from `/sandbox/credentials` |
| No request log | Verify requests are being made |
| Data not clearing | Use `DELETE /sandbox/clear` |

## Related Docs

- [Full Sandbox Guide](./SANDBOX_ENVIRONMENT_GUIDE.md)
- [API Documentation](./API_DOCUMENTATION_GUIDE.md)
- [Authentication Guide](./AUTHENTICATION_GUIDE.md)
