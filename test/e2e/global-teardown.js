/**
 * Global Teardown for CloudToLocalLLM E2E Tests
 * Cleans up ephemeral Auth0 test users.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function globalTeardown(config) {
    console.log('\n CloudToLocalLLM Global Teardown');
    console.log('=================================');

    let auth0Manager = null;
    try {
        const scriptPath = path.resolve(__dirname, '../../services/api-backend/scripts/auth0-test-user-manager.js');
        if (fs.existsSync(scriptPath)) {
            auth0Manager = await import(scriptPath);
        }
    } catch (e) {
        // Ignore
    }

    try {
        const testResultsDir = 'test-results';
        const configPath = path.join(testResultsDir, 'user-config.json');

        // Check if we have credentials to perform cleanup
        const hasCredentials = process.env.AUTH0_DOMAIN && process.env.AUTH0_CLIENT_ID && process.env.AUTH0_CLIENT_SECRET;

        if (auth0Manager && fs.existsSync(configPath)) {
            const userConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

            if (userConfig && userConfig.userId) {
                if (hasCredentials) {
                    console.log(`\n🧹 Cleaning up test user: ${userConfig.email} (${userConfig.userId})...`);
                    await auth0Manager.deleteUser(userConfig.userId);
                    console.log('  User deleted successfully.');
                } else {
                    console.log(`\n [WARN] Cannot clean up user ${userConfig.email} - Missing Auth0 credentials`);
                }
            }
        } else if (auth0Manager && hasCredentials) {
            // Run general cleanup for any stale users > 60 mins old as safety net
            console.log('\n🧹 Running maintenance cleanup for stale users...');
            await auth0Manager.cleanupStaleUsers(60);
        } else {
            console.log('\n Skipping general cleanup (Missing credentials or initialized manager)');
        }

    } catch (error) {
        console.error('  Cleanup failed:', error.message);
    }

    console.log('Teardown complete.\n');
}

export default globalTeardown;
