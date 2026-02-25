/**
 * Tunnel Management Example
 * 
 * Demonstrates how to create, manage, and monitor tunnels
 */

import { CloudToLocalLLMClient } from '../src/index';

async function main() {
  const client = new CloudToLocalLLMClient({
    baseURL: 'https://api.cloudtolocalllm.online',
    apiVersion: 'v2',
  });

  // Set authentication tokens
  const accessToken = 'your-access-token';
  client.setTokens(accessToken);

  try {
    // Create a tunnel
    console.log('Creating tunnel...');
    const tunnel = await client.createTunnel({
      name: 'Production Tunnel',
      endpoints: [
        {
          url: 'http://prod-server-1:8000',
          priority: 1,
          weight: 50,
        },
        {
          url: 'http://prod-server-2:8000',
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
    console.log('Tunnel created:', tunnel.id);

    // List tunnels
    console.log('\nListing tunnels...');
    const response = await client.listTunnels({
      page: 1,
      limit: 10,
      sort: 'createdAt',
      order: 'desc',
    });
    console.log(`Found ${response.pagination.total} tunnels`);
    response.data.forEach((t) => {
      console.log(`  - ${t.name} (${t.status})`);
    });

    // Get tunnel details
    console.log('\nGetting tunnel details...');
    const details = await client.getTunnel(tunnel.id);
    console.log('Tunnel details:', details);

    // Start tunnel
    console.log('\nStarting tunnel...');
    const started = await client.startTunnel(tunnel.id);
    console.log('Tunnel status:', started.status);

    // Get tunnel status
    console.log('\nGetting tunnel status...');
    const status = await client.getTunnelStatus(tunnel.id);
    console.log('Status:', status);

    // Get tunnel metrics
    console.log('\nGetting tunnel metrics...');
    const metrics = await client.getTunnelMetrics(tunnel.id);
    console.log('Metrics:', {
      requests: metrics.requestCount,
      successful: metrics.successCount,
      errors: metrics.errorCount,
      avgLatency: `${metrics.averageLatency}ms`,
    });

    // Update tunnel
    console.log('\nUpdating tunnel...');
    const updated = await client.updateTunnel(tunnel.id, {
      name: 'Updated Production Tunnel',
      config: {
        maxConnections: 2000,
      },
    });
    console.log('Tunnel updated:', updated.name);

    // Stop tunnel
    console.log('\nStopping tunnel...');
    const stopped = await client.stopTunnel(tunnel.id);
    console.log('Tunnel status:', stopped.status);

    // Delete tunnel
    console.log('\nDeleting tunnel...');
    await client.deleteTunnel(tunnel.id);
    console.log('Tunnel deleted');
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
