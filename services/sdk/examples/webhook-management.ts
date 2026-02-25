/**
 * Webhook Management Example
 * 
 * Demonstrates how to create, manage, and test webhooks
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
    // Create a webhook
    console.log('Creating webhook...');
    const webhook = await client.createWebhook({
      url: 'https://example.com/webhooks/tunnels',
      events: ['tunnel.created', 'tunnel.updated', 'tunnel.deleted'],
      active: true,
    });
    console.log('Webhook created:', webhook.id);

    // List webhooks
    console.log('\nListing webhooks...');
    const response = await client.listWebhooks({
      page: 1,
      limit: 10,
    });
    console.log(`Found ${response.pagination.total} webhooks`);
    response.data.forEach((w) => {
      console.log(`  - ${w.url} (${w.active ? 'active' : 'inactive'})`);
    });

    // Get webhook details
    console.log('\nGetting webhook details...');
    const details = await client.getWebhook(webhook.id);
    console.log('Webhook details:', details);

    // Test webhook
    console.log('\nTesting webhook...');
    const delivery = await client.testWebhook(webhook.id);
    console.log('Test delivery status:', delivery.status);
    console.log('Delivery ID:', delivery.id);

    // Get webhook deliveries
    console.log('\nGetting webhook deliveries...');
    const deliveries = await client.getWebhookDeliveries(webhook.id, {
      page: 1,
      limit: 20,
    });
    console.log(`Found ${deliveries.pagination.total} deliveries`);
    deliveries.data.forEach((d) => {
      console.log(`  - Event: ${d.event}, Status: ${d.status}, Attempts: ${d.attempts}`);
    });

    // Update webhook
    console.log('\nUpdating webhook...');
    const updated = await client.updateWebhook(webhook.id, {
      url: 'https://example.com/webhooks/tunnels/v2',
      events: ['tunnel.created', 'tunnel.updated', 'tunnel.deleted', 'tunnel.status_changed'],
    });
    console.log('Webhook updated:', updated.url);

    // Disable webhook
    console.log('\nDisabling webhook...');
    const disabled = await client.updateWebhook(webhook.id, {
      active: false,
    });
    console.log('Webhook active:', disabled.active);

    // Delete webhook
    console.log('\nDeleting webhook...');
    await client.deleteWebhook(webhook.id);
    console.log('Webhook deleted');
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
