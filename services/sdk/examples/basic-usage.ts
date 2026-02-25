/**
 * Basic Usage Example
 * 
 * Demonstrates basic SDK usage for authentication and user management
 */

import { CloudToLocalLLMClient } from '../src/index';

async function main() {
  // Initialize the client
  const client = new CloudToLocalLLMClient({
    baseURL: 'https://api.cloudtolocalllm.online',
    apiVersion: 'v2',
  });

  try {
    // In a real application, you would get these tokens from Auth0
    const accessToken = 'your-access-token';
    const refreshToken = 'your-refresh-token';

    // Set authentication tokens
    client.setTokens(accessToken, refreshToken);

    // Get current user
    console.log('Getting current user...');
    const user = await client.getCurrentUser();
    console.log('Current user:', user);

    // Update user profile
    console.log('\nUpdating user profile...');
    const updated = await client.updateUser(user.id, {
      profile: {
        firstName: 'John',
        lastName: 'Doe',
      },
    });
    console.log('Updated user:', updated);

    // Get user tier
    console.log('\nGetting user tier...');
    const tierInfo = await client.getUserTier(user.id);
    console.log('User tier:', tierInfo);

    // Get API health
    console.log('\nGetting API health...');
    const health = await client.getHealth();
    console.log('API health:', health);

    // Logout
    console.log('\nLogging out...');
    await client.logout();
    console.log('Logged out successfully');
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
