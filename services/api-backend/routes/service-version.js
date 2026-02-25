/**
 * Service Version Endpoint
 *
 * Returns the deployed version of the API backend service
 */

import { readFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Cache the version to avoid reading file on every request
let cachedVersion = null;

async function loadVersion() {
  if (cachedVersion) {
    return cachedVersion;
  }

  try {
    // Try to read from package.json
    const packagePath = join(__dirname, '../package.json');
    const packageData = await readFile(packagePath, 'utf8');
    const packageJson = JSON.parse(packageData);

    cachedVersion = {
      service: 'api-backend',
      version: packageJson.version || process.env.API_VERSION || 'unknown',
      name: packageJson.name || 'cloudtolocalllm-api-backend',
      build_number: process.env.BUILD_NUMBER || 'dev',
      git_commit: process.env.GIT_COMMIT || 'unknown',
      environment: process.env.NODE_ENV || 'production',
      node_version: process.version,
      timestamp: new Date().toISOString(),
    };

    return cachedVersion;
  } catch {
    // Fallback if file reading fails
    cachedVersion = {
      service: 'api-backend',
      version: process.env.API_VERSION || 'unknown',
      build_number: process.env.BUILD_NUMBER || 'dev',
      git_commit: process.env.GIT_COMMIT || 'unknown',
      environment: process.env.NODE_ENV || 'production',
      node_version: process.version,
      timestamp: new Date().toISOString(),
      error: 'Could not read version from package.json',
    };

    return cachedVersion;
  }
}

/**
 * GET /service-version
 * Returns service version information
 */
export async function serviceVersionHandler(req, res) {
  try {
    const version = await loadVersion();
    res.json(version);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve service version',
      message: error.message,
    });
  }
}

export default serviceVersionHandler;
