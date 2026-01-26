# Tunnel Lifecycle Management - Quick Reference

## Overview

Implements comprehensive tunnel lifecycle management endpoints for creating, retrieving, updating, deleting, and managing tunnel status and metrics.

**Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.6**

## Files Created

### 1. Database Migration

- **File**: `database/migrations/004_tunnel_lifecycle_management.sql`
- **Tables**:
  - `tunnels` - Main tunnel records
  - `tunnel_endpoints` - Multiple endpoints per tunnel for failover
  - `tunnel_activity_logs` - Activity tracking

### 2. Service Layer

- **File**: `services/tunnel-service.js`
- **Class**: `TunnelService`
- **Methods**:
  - `createTunnel()` - Create new tunnel
  - `getTunnelById()` - Retrieve tunnel by ID
  - `listTunnels()` - List user's tunnels with pagination
  - `updateTunnel()` - Update tunnel configuration
  - `updateTunnelStatus()` - Change tunnel status
  - `deleteTunnel()` - Delete tunnel
  - `getTunnelMetrics()` - Retrieve tunnel metrics
  - `updateTunnelMetrics()` - Update tunnel metrics
  - `getTunnelActivityLogs()` - Retrieve activity logs

### 3. API Routes

- **File**: `routes/tunnels.js`
- **Endpoints**:
  - `POST /api/tunnels` - Create tunnel
  - `GET /api/tunnels` - List tunnels
  - `GET /api/tunnels/:id` - Get tunnel details
  - `PUT /api/tunnels/:id` - Update tunnel
  - `DELETE /api/tunnels/:id` - Delete tunnel
  - `POST /api/tunnels/:id/start` - Start tunnel
  - `POST /api/tunnels/:id/stop` - Stop tunnel
  - `GET /api/tunnels/:id/metrics` - Get metrics
  - `GET /api/tunnels/:id/activity` - Get activity logs

### 4. Tests

- **File**: `test/api-backend/tunnel-lifecycle.test.js`
- **Test Suites**:
  - Tunnel Creation
  - Tunnel Retrieval
  - Tunnel Listing
  - Tunnel Updates
  - Tunnel Status Management
  - Tunnel Deletion
  - Tunnel Metrics
  - Tunnel Activity Logs

## API Endpoints

### Create Tunnel

```
POST /api/tunnels
Content-Type: application/json

{
  "name": "My Tunnel",
  "config": {
    "maxConnections": 100,
    "timeout": 30000,
    "compression": true
  },
  "endpoints": [
    {
      "url": "http://localhost:8000",
      "priority": 1,
      "weight": 1
    }
  ]
}

Response: 201 Created
{
  "success": true,
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "name": "My Tunnel",
    "status": "created",
    "config": {...},
    "endpoints": [...],
    "metrics": {...},
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### List Tunnels

```
GET /api/tunnels?limit=50&offset=0

Response: 200 OK
{
  "success": true,
  "data": [...],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "total": 5
  }
}
```

### Get Tunnel

```
GET /api/tunnels/:id

Response: 200 OK
{
  "success": true,
  "data": {...}
}
```

### Update Tunnel

```
PUT /api/tunnels/:id
Content-Type: application/json

{
  "name": "Updated Name",
  "config": {...},
  "endpoints": [...]
}

Response: 200 OK
{
  "success": true,
  "data": {...}
}
```

### Delete Tunnel

```
DELETE /api/tunnels/:id

Response: 200 OK
{
  "success": true,
  "message": "Tunnel deleted successfully"
}
```

### Start Tunnel

```
POST /api/tunnels/:id/start

Response: 200 OK
{
  "success": true,
  "data": {...},
  "message": "Tunnel start initiated"
}
```

### Stop Tunnel

```
POST /api/tunnels/:id/stop

Response: 200 OK
{
  "success": true,
  "data": {...},
  "message": "Tunnel stopped successfully"
}
```

### Get Metrics

```
GET /api/tunnels/:id/metrics

Response: 200 OK
{
  "success": true,
  "data": {
    "requestCount": 100,
    "successCount": 95,
    "errorCount": 5,
    "averageLatency": 150
  }
}
```

### Get Activity Logs

```
GET /api/tunnels/:id/activity?limit=50&offset=0

Response: 200 OK
{
  "success": true,
  "data": [...],
  "pagination": {
    "limit": 50,
    "offset": 0
  }
}
```

## Data Models

### Tunnel

```typescript
interface Tunnel {
  id: UUID;
  user_id: UUID;
  name: string;
  status: 'created' | 'connecting' | 'connected' | 'disconnected' | 'error';
  config: {
    maxConnections: number;
    timeout: number;
    compression: boolean;
  };
  metrics: {
    requestCount: number;
    successCount: number;
    errorCount: number;
    averageLatency: number;
  };
  endpoints: TunnelEndpoint[];
  created_at: Date;
  updated_at: Date;
}
```

### TunnelEndpoint

```typescript
interface TunnelEndpoint {
  id: UUID;
  tunnel_id: UUID;
  url: string;
  priority: number;
  weight: number;
  health_status: 'healthy' | 'unhealthy' | 'unknown';
  last_health_check: Date;
}
```

### TunnelActivityLog

```typescript
interface TunnelActivityLog {
  id: UUID;
  tunnel_id: UUID;
  user_id: UUID;
  action: string;
  status: string;
  details: Record<string, any>;
  ip_address: string;
  user_agent: string;
  created_at: Date;
}
```

## Error Handling

### 400 Bad Request

- Missing required fields
- Invalid tunnel name (empty or > 255 chars)
- Invalid pagination parameters

### 401 Unauthorized

- Missing or invalid JWT token

### 403 Forbidden

- User attempting to access tunnel owned by another user

### 404 Not Found

- Tunnel not found

### 409 Conflict

- Tunnel name already exists for user

### 500 Internal Server Error

- Database errors
- Service initialization errors

## Features

### Tunnel Lifecycle Management

- Create tunnels with configuration
- Support multiple endpoints per tunnel for failover
- Track tunnel status (created, connecting, connected, disconnected, error)
- Start/stop tunnel operations
- Delete tunnels with cascading cleanup

### Configuration Management

- Store tunnel configuration (max connections, timeout, compression)
- Update configuration without recreating tunnel
- Validate configuration parameters

### Endpoint Management

- Support multiple endpoints per tunnel
- Priority-based endpoint selection
- Weight-based load distribution
- Health status tracking

### Metrics Collection

- Track request counts
- Monitor success/error rates
- Calculate average latency
- Update metrics in real-time

### Activity Logging

- Log all tunnel operations
- Track user actions and IP addresses
- Maintain audit trail
- Support activity log retrieval

### Authorization

- User-based tunnel ownership
- Prevent cross-user access
- Audit logging for security

## Integration

### Server Registration

Routes are registered in `server.js`:

```javascript
import tunnelRoutes, { initializeTunnelService } from './routes/tunnels.js';

// Register routes
app.use('/api/tunnels', tunnelRoutes);
app.use('/tunnels', tunnelRoutes);

// Initialize service during startup
await initializeTunnelService();
```

### Database Setup

Migration is applied during server startup:

```bash
npm run migrate
```

## Testing

Run tests:

```bash
npm test -- tunnel-lifecycle
```

Test coverage includes:

- Tunnel creation with valid/invalid data
- Tunnel retrieval and listing
- Tunnel updates (name, config, endpoints)
- Tunnel status management
- Tunnel deletion
- Metrics operations
- Activity log retrieval

## Performance Considerations

- Pagination support for large tunnel lists (limit: 1-1000)
- Indexed queries on user_id, status, created_at
- Efficient endpoint management with cascading deletes
- Activity log pagination for large histories

## Security

- JWT authentication required for all endpoints
- User-based authorization (can only access own tunnels)
- Input validation and sanitization
- SQL injection prevention via parameterized queries
- Audit logging for all operations
- IP address and user agent tracking

## Future Enhancements

- Tunnel sharing and access control
- Webhook notifications for status changes
- Advanced metrics aggregation
- Tunnel diagnostics endpoints
- Automatic failover logic
- Health check automation
