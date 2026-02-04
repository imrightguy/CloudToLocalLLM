# Zoidbot SDK - Quick Start Guide

## Installation

```bash
npm install @zoidbot/sdk
```

## Basic Setup

```typescript
import { ZoidbotClient } from '@zoidbot/sdk';

const client = new ZoidbotClient({
  baseURL: 'https://api.zoidbot.online',
  apiVersion: 'v2',
});

// Set tokens after OAuth login
client.setTokens(accessToken, refreshToken);
```

## Common Operations

### Get Current User

```typescript
const user = await client.getCurrentUser();
console.log(user.email);
```

### Create a Tunnel

```typescript
const tunnel = await client.createTunnel({
  name: 'My Tunnel',
  endpoints: [
    { url: 'http://localhost:8000', priority: 1, weight: 100 }
  ],
  config: {
    maxConnections: 100,
    timeout: 30000,
    compression: true,
  },
});
```

### Start a Tunnel

```typescript
await client.startTunnel(tunnel.id);
```

### Get Tunnel Metrics

```typescript
const metrics = await client.getTunnelMetrics(tunnel.id);
console.log(`Requests: ${metrics.requestCount}`);
console.log(`Avg Latency: ${metrics.averageLatency}ms`);
```

### Create a Webhook

```typescript
const webhook = await client.createWebhook({
  url: 'https://example.com/webhooks',
  events: ['tunnel.created', 'tunnel.deleted'],
  active: true,
});
```

### List Tunnels

```typescript
const response = await client.listTunnels({
  page: 1,
  limit: 10,
  sort: 'createdAt',
  order: 'desc',
});

response.data.forEach(tunnel => {
  console.log(`${tunnel.name}: ${tunnel.status}`);
});
```

### Admin: List Users

```typescript
const response = await client.listUsers({
  page: 1,
  limit: 50,
  search: 'example.com',
});
```

### Admin: Get Audit Logs

```typescript
const response = await client.getAuditLogs({
  page: 1,
  limit: 100,
});
```

### Check API Health

```typescript
const health = await client.getHealth();
console.log(health.status); // 'healthy', 'degraded', or 'error'
```

## Error Handling

```typescript
try {
  const tunnel = await client.getTunnel('invalid-id');
} catch (error) {
  if (error.response?.status === 404) {
    console.log('Tunnel not found');
  } else if (error.response?.status === 401) {
    console.log('Unauthorized - check your tokens');
  } else if (error.response?.status === 429) {
    console.log('Rate limited - wait before retrying');
  }
}
```

## Configuration Options

```typescript
const client = new ZoidbotClient({
  baseURL: 'https://api.zoidbot.online',  // Required
  apiVersion: 'v2',                               // Optional: 'v1' or 'v2'
  timeout: 30000,                                 // Optional: milliseconds
  retryAttempts: 3,                               // Optional: number of retries
  retryDelay: 1000,                               // Optional: delay between retries
  headers: {                                      // Optional: custom headers
    'X-Custom-Header': 'value',
  },
});
```

## TypeScript Support

```typescript
import {
  ZoidbotClient,
  Tunnel,
  User,
  Webhook,
} from '@zoidbot/sdk';

const client = new ZoidbotClient({
  baseURL: 'https://api.zoidbot.online',
});

const user: User = await client.getCurrentUser();
const tunnel: Tunnel = await client.getTunnel('tunnel-id');
const webhook: Webhook = await client.getWebhook('webhook-id');
```

## Pagination

```typescript
const response = await client.listTunnels({
  page: 2,
  limit: 20,
  sort: 'createdAt',
  order: 'desc',
});

console.log(response.data);              // Array of tunnels
console.log(response.pagination.page);   // Current page
console.log(response.pagination.total);  // Total items
console.log(response.pagination.pages);  // Total pages
```

## Logout

```typescript
await client.logout();
// Tokens are cleared and user is logged out
```

## More Information

- Full Documentation: See `SDK_DOCUMENTATION.md`
- Examples: See `examples/` directory
- Contributing: See `CONTRIBUTING.md`
- Changelog: See `CHANGELOG.md`

## Support

- GitHub: https://github.com/Zoidbot/zoidbot
- Documentation: https://zoidbot.online/docs
- API Docs: https://api.zoidbot.online/api/docs
