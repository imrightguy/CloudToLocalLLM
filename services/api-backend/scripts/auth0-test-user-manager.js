/**
 * Auth0 Test User Manager
 *
 * Utility to create and manage ephemeral test users for E2E testing.
 * Uses Auth0 Management API.
 */

import { ManagementClient } from 'auth0';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load environment variables
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

let managementClient = null;

function getCredentials() {
  const domain = process.env.AUTH0_DOMAIN;
  const clientId = process.env.AUTH0_CLIENT_ID;
  const clientSecret = process.env.AUTH0_CLIENT_SECRET;
  const connection =
    process.env.AUTH0_CONNECTION || 'Username-Password-Authentication';

  if (!domain || !clientId || !clientSecret) {
    throw new Error(
      'Missing Auth0 credentials (AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET)',
    );
  }

  return { domain, clientId, clientSecret, connection };
}

function getManagementClient() {
  if (!managementClient) {
    const { domain, clientId, clientSecret } = getCredentials();
    managementClient = new ManagementClient({
      domain,
      clientId,
      clientSecret,
    });
  }
  return managementClient;
}

/**
 * Generate a random string
 */
function randomString(length = 8) {
  return Math.random()
    .toString(36)
    .substring(2, 2 + length);
}

/**
 * Create a new test user
 */
export async function createTestUser(role = 'user') {
  const username = `e2e-test-${role}-${randomString()}`;
  const email = `${username}@example.com`;
  const password = `Test@${randomString(10)}!`; // Compliance with likely password policies

  try {
    console.log(`Creating test user: ${email} (${role})...`);
    const { connection } = getCredentials();
    const management = getManagementClient();

    // Create the user
    const user = await management.users.create({
      connection: connection,
      email: email,
      password: password,
      email_verified: true,
      app_metadata: {
        role: role,
        created_by: 'e2e-test-runner',
        created_at: new Date().toISOString(),
      },
      user_metadata: {
        type: 'e2e-test',
      },
    });

    console.log(`User created: ${user.data.user_id}`);

    return {
      userId: user.data.user_id,
      email,
      password,
      role,
    };
  } catch (error) {
    console.error(`Failed to create user: ${error.message}`);
    throw error;
  }
}

/**
 * Delete a user by ID
 */
export async function deleteUser(userId) {
  try {
    console.log(`Deleting user: ${userId}...`);
    const management = getManagementClient();
    await management.users.delete({ id: userId });
    console.log('User deleted.');
  } catch (error) {
    console.error(`Failed to delete user ${userId}: ${error.message}`);
    // Don't throw, just log. Cleanup shouldn't fail the build if it misses one.
  }
}

/**
 * Cleanup ALL partial test users created by this runner
 * (Useful for global teardown or manual cleanup)
 */
export async function cleanupStaleUsers(maxAgeMinutes = 60) {
  try {
    console.log('Searching for stale test users...');
    const management = getManagementClient();

    const q = 'user_metadata.type:"e2e-test"';
    const users = await management.users.getAll({ q });

    if (!users.data || users.data.length === 0) {
      console.log('No stale users found.');
      return;
    }

    console.log(`Found ${users.data.length} potential stale users.`);

    let deletedCount = 0;
    const now = new Date();

    for (const user of users.data) {
      const createdAt = new Date(user.created_at);
      const ageMinutes = (now - createdAt) / (1000 * 60);

      if (ageMinutes > maxAgeMinutes) {
        await deleteUser(user.user_id);
        deletedCount++;
      }
    }

    console.log(`Cleaned up ${deletedCount} stale users.`);
  } catch (error) {
    console.error(`Cleanup failed: ${error.message}`);
  }
}

// CLI Interface
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const command = args[0];
  const arg1 = args[1];

  (async () => {
    try {
      if (command === 'create') {
        const result = await createTestUser(arg1 || 'user');
        console.log(JSON.stringify(result, null, 2));
      } else if (command === 'delete') {
        if (!arg1) {
          throw new Error('User ID required for delete');
        }
        await deleteUser(arg1);
      } else if (command === 'cleanup') {
        await cleanupStaleUsers(parseInt(arg1) || 0); // 0 means clean all
      } else {
        console.log(`
Usage:
  node auth0-test-user-manager.js create [role]
  node auth0-test-user-manager.js delete <user_id>
  node auth0-test-user-manager.js cleanup [max_age_minutes]
        `);
      }
    } catch (err) {
      console.error(err);
      process.exit(1);
    }
  })();
}
