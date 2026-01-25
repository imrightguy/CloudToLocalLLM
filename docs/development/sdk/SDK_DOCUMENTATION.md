# CloudToLocalLLM SDK Documentation

## Overview

The CloudToLocalLLM SDK is an official JavaScript/TypeScript client library for the CloudToLocalLLM API. It provides a simple, type-safe interface for interacting with all API endpoints.

**Requirements: 12.6**

## Features

- ✅ Full TypeScript support with comprehensive type definitions
- ✅ Automatic token refresh for seamless authentication
- ✅ Retry logic with exponential backoff
- ✅ Comprehensive error handling
- ✅ Support for both CommonJS and ES modules
- ✅ Pagination support for list endpoints
- ✅ Rate limit awareness
- ✅ Webhook management
- ✅ Admin operations
- ✅ Complete API coverage

## Installation

### npm

```bash
npm install @cloudtolocalllm/sdk
```

### yarn

```bash
yarn add @cloudtolocalllm/sdk
```

### pnpm

```bash
pnpm add @cloudtolocalllm/sdk
```

## Quick Start

### Basic Setup

```typescript
import { CloudToLocalLLMClient } from '@cloudtolocalllm/sdk';

const client = new CloudToLocalLLMClient({
  baseURL: 'https://api.cloudtolocalllm.online',
  apiVersion: 'v2',
});

// Set authentication tokens
client.setTokens(accessToken, refreshToken);

// Use the client
const user = await client.getCurrentUser();
```

### Authentication

The SDK handles authentication through JWT tokens:

```typescript
// Set tokens after OAuth login
client.setTokens(accessToken, refreshToken);

// Tokens are automatically included in all requests
// If access token expires, the SDK automatically refreshes it

// Logout
await client.logout();
```

## API Reference

### User Management

#### Get Current User
```typescript
const user = await client.getCurrentUser();
```

#### Get User by ID
```typescript
const user = await client.getUser(userId);
```

#### Update User
```typescript
const updated = await client.updateUser(userId, {
  profile: {
    firstName: 'John',
    lastName: 'Doe',
  },
  preferences: {
    theme: 'dark',
  },
});
```

#### Delete User
```typescript
await client.deleteUser(userId);
```

#### Get User Tier
```typescript
const tier = await client.getUserTier(userId);
```

#### Upgrade User Tier
```typescript
const updated = await client.upgradeUserTier(userId, 'premium');
```

### Tunnel Management

#### Create Tunnel
```typescript
const tunnel = await client.createTunnel({
  name: 'My Tunnel',
  endpoints: [
    {
      url: 'http://localhost:8000',
      priority: 1,
      weight: 100,
    },
  ],
  config: {
    maxConnections: 100,
    timeout: 30000,
    compression: true,
  },
});
```

#### Get Tunnel
```typescript
const tunnel = await client.getTunnel(tunnelId);
```

#### List Tunnels
```typescript
const response = await client.listTunnels({
  page: 1,
  limit: 10,
  sort: 'createdAt',
  order: 'desc',
});
```

#### Update Tunnel
```typescript
const updated = await client.updateTunnel(tunnelId, {
  name: 'Updated Name',
  config: {
    maxConnections: 200,
  },
});
```

#### Delete Tunnel
```typescript
await client.deleteTunnel(tunnelId);
```

#### Start Tunnel
```typescript
const tunnel = await client.startTunnel(tunnelId);
```

#### Stop Tunnel
```typescript
const tunnel = await client.stopTunnel(tunnelId);
```

#### Get Tunnel Status
```typescript
const status = await client.getTunnelStatus(tunnelId);
```

#### Get Tunnel Metrics
```typescript
const metrics = await client.getTunnelMetrics(tunnelId);
```

### Webhook Management

#### Create Webhook
```typescript
const webhook = await client.createWebhook({
  url: 'https://example.com/webhooks',
  events: ['tunnel.created', 'tunnel.deleted'],
  active: true,
});
```

#### Get Webhook
```typescript
const webhook = await client.getWebhook(webhookId);
```

#### List Webhooks
```typescript
const response = await client.listWebhooks({
  page: 1,
  limit: 10,
});
```

#### Update Webhook
```typescript
const updated = await client.updateWebhook(webhookId, {
  url: 'https://example.com/webhooks/v2',
  events: ['tunnel.created', 'tunnel.updated', 'tunnel.deleted'],
});
```

#### Delete Webhook
```typescript
await client.deleteWebhook(webhookId);
```

#### Test Webhook
```typescript
const delivery = await client.testWebhook(webhookId);
```

#### Get Webhook Deliveries
```typescript
const response = await client.getWebhookDeliveries(webhookId, {
  page: 1,
  limit: 20,
});
```

### Admin Operations

#### List Users
```typescript
const response = await client.listUsers({
  page: 1,
  limit: 50,
  search: 'john@example.com',
});
```

#### Get User (Admin)
```typescript
const user = await client.getAdminUser(userId);
```

#### Update User (Admin)
```typescript
const updated = await client.updateAdminUser(userId, {
  tier: 'premium',
  role: 'admin',
});
```

#### Delete User (Admin)
```typescript
await client.deleteAdminUser(userId);
```

#### Get Audit Logs
```typescript
const response = await client.getAuditLogs({
  page: 1,
  limit: 100,
});
```

#### Get System Health
```typescript
const health = await client.getSystemHealth();
```

### API Key Management

#### Create API Key
```typescript
const apiKey = await client.createAPIKey({
  name: 'My API Key',
  expiresAt: '2025-12-31T23:59:59Z',
});
```

#### List API Keys
```typescript
const keys = await client.listAPIKeys();
```

#### Revoke API Key
```typescript
await client.revokeAPIKey(keyId);
```

### Health & Status

#### Get API Health
```typescript
const health = await client.getHealth();
```

#### Get Version Info
```typescript
const version = await client.getVersionInfo();
```

### Proxy Management

#### Get Proxy Status
```typescript
const proxy = await client.getProxyStatus();
```

#### Start Proxy
```typescript
const proxy = await client.startProxy();
```

#### Stop Proxy
```typescript
await client.stopProxy();
```

#### Get Proxy Metrics
```typescript
const metrics = await client.getProxyMetrics();
```

#### Scale Proxy
```typescript
const proxy = await client.scaleProxy(5);
```

## Configuration

### SDK Options

```typescript
interface SDKConfig {
  baseURL: string;                    // API base URL (required)
  apiVersion?: 'v1' | 'v2';          // API version (default: 'v2')
  timeout?: number;                  // Request timeout in ms (default: 30000)
  retryAttempts?: number;            // Number of retries (default: 3)
  retryDelay?: number;               // Delay between retries in ms (default: 1000)
  headers?: Record<string, string>;  // Custom headers
}
```

### Example Configuration

```typescript
const client = new CloudToLocalLLMClient({
  baseURL: 'https://api.cloudtolocalllm.online',
  apiVersion: 'v2',
  timeout: 60000,
  retryAttempts: 5,
  retryDelay: 2000,
  headers: {
    'X-Custom-Header': 'value',
  },
});
```

## Error Handling

The SDK provides detailed error information:

```typescript
try {
  const tunnel = await client.getTunnel('invalid-id');
} catch (error) {
  if (error.response?.status === 404) {
    console.log('Tunnel not found');
  } else if (error.response?.status === 401) {
    console.log('Unauthorized');
  } else if (error.response?.status === 429) {
    console.log('Rate limited');
  } else {
    console.log('Error:', error.message);
  }
}
```

## Pagination

List endpoints support pagination:

```typescript
const response = await client.listTunnels({
  page: 2,
  limit: 20,
  sort: 'createdAt',
  order: 'desc',
});

console.log(response.data);              // Array of items
console.log(response.pagination.page);   // Current page
console.log(response.pagination.total);  // Total items
console.log(response.pagination.pages);  // Total pages
```

## Rate Limiting

The API enforces rate limits. Check response headers:

```typescript
// Response headers include:
// X-RateLimit-Limit: 100
// X-RateLimit-Remaining: 99
// X-RateLimit-Reset: 1234567890
```

## TypeScript Support

Full TypeScript support with comprehensive types:

```typescript
import {
  CloudToLocalLLMClient,
  Tunnel,
  User,
  Webhook,
} from '@cloudtolocalllm/sdk';

const client = new CloudToLocalLLMClient({
  baseURL: 'https://api.cloudtolocalllm.online',
});

// Types are automatically inferred
const user: User = await client.getCurrentUser();
const tunnel: Tunnel = await client.getTunnel('tunnel-id');
const webhook: Webhook = await client.getWebhook('webhook-id');
```

## Examples

### Complete Authentication Flow

```typescript
import { CloudToLocalLLMClient } from '@cloudtolocalllm/sdk';

const client = new CloudToLocalLLMClient({
  baseURL: 'https://api.cloudtolocalllm.online',
});

// After OAuth login
const { accessToken, refreshToken } = await getTokensFromAuth0();
client.setTokens(accessToken, refreshToken);

// Use the client
const user = await client.getCurrentUser();
console.log(`Welcome, ${user.profile.firstName}!`);

// Tokens are automatically refreshed when needed
const tunnels = await client.listTunnels();

// Logout
await client.logout();
```

### Create and Monitor Tunnels

```typescript
// Create tunnel
const tunnel = await client.createTunnel({
  name: 'Production Tunnel',
  endpoints: [
    {
      url: 'http://prod-1:8000',
      priority: 1,
      weight: 50,
    },
    {
      url: 'http://prod-2:8000',
      priority: 1,
      weight: 50,
    },
  ],
  config: {
    maxConnections: 1000,
    timeout: 60000,
    compression: true,
  },
});

// Start tunnel
await client.startTunnel(tunnel.id);

// Monitor metrics
const metrics = await client.getTunnelMetrics(tunnel.id);
console.log(`Requests: ${metrics.requestCount}`);
console.log(`Success Rate: ${(metrics.successCount / metrics.requestCount * 100).toFixed(2)}%`);
console.log(`Avg Latency: ${metrics.averageLatency}ms`);

// Stop tunnel
await client.stopTunnel(tunnel.id);
```

### Setup Webhooks

```typescript
// Create webhook
const webhook = await client.createWebhook({
  url: 'https://example.com/webhooks/tunnels',
  events: ['tunnel.created', 'tunnel.updated', 'tunnel.deleted'],
  active: true,
});

// Test webhook
const delivery = await client.testWebhook(webhook.id);
console.log(`Test delivery status: ${delivery.status}`);

// Get delivery history
const deliveries = await client.getWebhookDeliveries(webhook.id, {
  page: 1,
  limit: 50,
});

console.log(`Total deliveries: ${deliveries.pagination.total}`);
```

## Support

For issues, questions, or contributions:
- GitHub: https://github.com/CloudToLocalLLM/cloudtolocalllm
- Documentation: https://cloudtolocalllm.online/docs
- API Docs: https://api.cloudtolocalllm.online/api/docs

## License

MIT
