/**
 * Admin Operations Example
 * 
 * Demonstrates admin-only operations like user management and audit logs
 */

import { CloudToLocalLLMClient } from '../src/index';

async function main() {
  const client = new CloudToLocalLLMClient({
    baseURL: 'https://api.cloudtolocalllm.online',
    apiVersion: 'v2',
  });

  // Set authentication tokens (must be admin user)
  const adminAccessToken = 'your-admin-access-token';
  client.setTokens(adminAccessToken);

  try {
    // List all users
    console.log('Listing all users...');
    const usersResponse = await client.listUsers({
      page: 1,
      limit: 50,
      search: 'example.com',
    });
    console.log(`Found ${usersResponse.pagination.total} users`);
    usersResponse.data.forEach((u) => {
      console.log(`  - ${u.email} (${u.tier})`);
    });

    // Get specific user
    if (usersResponse.data.length > 0) {
      const userId = usersResponse.data[0].id;

      console.log(`\nGetting user details for ${userId}...`);
      const user = await client.getAdminUser(userId);
      console.log('User details:', user);

      // Update user tier
      console.log('\nUpgrading user to premium...');
      const upgraded = await client.updateAdminUser(userId, {
        tier: 'premium',
      });
      console.log('User tier updated:', upgraded.tier);

      // Update user role
      console.log('\nPromoting user to admin...');
      const promoted = await client.updateAdminUser(userId, {
        role: 'admin',
      });
      console.log('User role updated:', promoted.role);
    }

    // Get audit logs
    console.log('\nGetting audit logs...');
    const auditResponse = await client.getAuditLogs({
      page: 1,
      limit: 100,
    });
    console.log(`Found ${auditResponse.pagination.total} audit log entries`);
    auditResponse.data.slice(0, 5).forEach((log) => {
      console.log(`  - ${log.action} on ${log.resource} by ${log.userId}`);
    });

    // Get system health
    console.log('\nGetting system health...');
    const health = await client.getSystemHealth();
    console.log('System health:', {
      overall: health.status,
      database: health.database,
      cache: health.cache,
      timestamp: health.timestamp,
    });
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
