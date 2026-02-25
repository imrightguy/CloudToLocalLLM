/**
 * API Deprecation Service
 *
 * Manages API endpoint deprecation, migration guides, and deprecation warnings.
 * Provides utilities for marking endpoints as deprecated and tracking deprecation status.
 *
 * Requirements: 12.5
 */

/**
 * Deprecation status enum
 */
export const DeprecationStatus = {
  ACTIVE: 'active',
  DEPRECATED: 'deprecated',
  SUNSET: 'sunset',
};

/**
 * Deprecated endpoints registry
 * Maps endpoint paths to deprecation information
 */
export const DEPRECATED_ENDPOINTS = {
  // v1 endpoints (all deprecated)
  '/v1/users': {
    status: DeprecationStatus.DEPRECATED,
    deprecatedAt: '2024-01-01',
    sunsetAt: '2026-01-01',
    replacedBy: '/v2/users',
    reason: 'API v1 is deprecated. Use v2 for new integrations.',
    migrationGuide: 'MIGRATION_V1_TO_V2',
  },
  '/v1/tunnels': {
    status: DeprecationStatus.DEPRECATED,
    deprecatedAt: '2024-01-01',
    sunsetAt: '2026-01-01',
    replacedBy: '/v2/tunnels',
    reason: 'API v1 is deprecated. Use v2 for new integrations.',
    migrationGuide: 'MIGRATION_V1_TO_V2',
  },
  '/v1/auth': {
    status: DeprecationStatus.DEPRECATED,
    deprecatedAt: '2024-01-01',
    sunsetAt: '2026-01-01',
    replacedBy: '/v2/auth',
    reason: 'API v1 is deprecated. Use v2 for new integrations.',
    migrationGuide: 'MIGRATION_V1_TO_V2',
  },
  '/v1/admin': {
    status: DeprecationStatus.DEPRECATED,
    deprecatedAt: '2024-01-01',
    sunsetAt: '2026-01-01',
    replacedBy: '/v2/admin',
    reason: 'API v1 is deprecated. Use v2 for new integrations.',
    migrationGuide: 'MIGRATION_V1_TO_V2',
  },
};

/**
 * Migration guides for deprecated endpoints
 */
export const MIGRATION_GUIDES = {
  MIGRATION_V1_TO_V2: {
    title: 'Migrating from API v1 to v2',
    description:
      'Complete guide for migrating from CloudToLocalLLM API v1 to v2',
    steps: [
      {
        step: 1,
        title: 'Update Base URL',
        description: 'Change your API base URL from /v1 to /v2',
        before: 'https://api.cloudtolocalllm.online/v1/users',
        after: 'https://api.cloudtolocalllm.online/v2/users',
      },
      {
        step: 2,
        title: 'Update Response Parsing',
        description: 'Update your code to handle the new v2 response format',
        before: `const data = await response.json();
const email = data.data.userEmail;`,
        after: `const data = await response.json();
const email = data.user.email;`,
      },
      {
        step: 3,
        title: 'Update Error Handling',
        description: 'Update error handling to use the new v2 error format',
        before: `if (!response.ok) {
  const error = await response.json();
  console.error(error.error);
}`,
        after: `if (!response.ok) {
  const error = await response.json();
  console.error(error.error.message);
  console.error(error.error.suggestion);
}`,
      },
      {
        step: 4,
        title: 'Test Thoroughly',
        description:
          'Test all API endpoints with v2 before deploying to production',
        resources: [
          'https://docs.cloudtolocalllm.online/api/v2',
          'https://api.cloudtolocalllm.online/api/docs',
        ],
      },
    ],
    resources: {
      documentation: 'https://docs.cloudtolocalllm.online/api/migration',
      apiDocs: 'https://api.cloudtolocalllm.online/api/docs',
      support: 'support@cloudtolocalllm.online',
    },
    timeline: {
      deprecatedAt: '2024-01-01',
      sunsetAt: '2026-01-01',
      daysUntilSunset: calculateDaysUntilSunset('2026-01-01'),
    },
  },
};

/**
 * Calculate days until sunset date
 *
 * @param {string} sunsetDate - Sunset date in ISO format
 * @returns {number} Days until sunset
 */
function calculateDaysUntilSunset(sunsetDate) {
  const sunset = new Date(sunsetDate);
  const today = new Date();
  const diffTime = sunset - today;
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return Math.max(0, diffDays);
}

/**
 * Get deprecation info for an endpoint
 *
 * @param {string} path - Request path
 * @returns {Object|null} Deprecation info or null if not deprecated
 */
export function getDeprecationInfo(path) {
  // Check exact match
  if (DEPRECATED_ENDPOINTS[path]) {
    return DEPRECATED_ENDPOINTS[path];
  }

  // Check prefix match (for versioned endpoints)
  for (const [endpointPath, info] of Object.entries(DEPRECATED_ENDPOINTS)) {
    if (path.startsWith(endpointPath)) {
      return info;
    }
  }

  return null;
}

/**
 * Check if endpoint is deprecated
 *
 * @param {string} path - Request path
 * @returns {boolean} True if endpoint is deprecated
 */
export function isDeprecated(path) {
  const info = getDeprecationInfo(path);
  return !!(info && info.status === DeprecationStatus.DEPRECATED);
}

/**
 * Check if endpoint is sunset (no longer available)
 *
 * @param {string} path - Request path
 * @returns {boolean} True if endpoint is sunset
 */
export function isSunset(path) {
  const info = getDeprecationInfo(path);
  if (!info) {
    return false;
  }

  const sunsetDate = new Date(info.sunsetAt);
  const today = new Date();
  return today >= sunsetDate;
}

/**
 * Get migration guide for deprecated endpoint
 *
 * @param {string} path - Request path
 * @returns {Object|null} Migration guide or null if not found
 */
export function getMigrationGuide(path) {
  const info = getDeprecationInfo(path);
  if (!info || !info.migrationGuide) {
    return null;
  }

  return MIGRATION_GUIDES[info.migrationGuide] || null;
}

/**
 * Format deprecation warning message
 *
 * @param {string} path - Request path
 * @returns {string} Formatted warning message
 */
export function formatDeprecationWarning(path) {
  const info = getDeprecationInfo(path);
  if (!info) {
    return '';
  }

  const daysUntilSunset = calculateDaysUntilSunset(info.sunsetAt);
  const replacedBy = info.replacedBy ? ` Use ${info.replacedBy} instead.` : '';

  return `API endpoint ${path} is deprecated and will be removed on ${info.sunsetAt} (${daysUntilSunset} days).${replacedBy}`;
}

/**
 * Get deprecation headers for response
 *
 * @param {string} path - Request path
 * @returns {Object} Headers object with deprecation info
 */
export function getDeprecationHeaders(path) {
  const info = getDeprecationInfo(path);
  if (!info || info.status !== DeprecationStatus.DEPRECATED) {
    return {};
  }

  const headers = {
    Deprecation: 'true',
    Sunset: new Date(info.sunsetAt).toUTCString(),
    Warning: `299 - "${formatDeprecationWarning(path)}"`,
  };

  if (info.replacedBy) {
    headers['Deprecation-Link'] = info.replacedBy;
  }

  return headers;
}

/**
 * Get all deprecated endpoints
 *
 * @returns {Array} Array of deprecated endpoint info
 */
export function getAllDeprecatedEndpoints() {
  return Object.entries(DEPRECATED_ENDPOINTS)
    .filter(([, info]) => info.status === DeprecationStatus.DEPRECATED)
    .map(([path, info]) => ({
      path,
      ...info,
      daysUntilSunset: calculateDaysUntilSunset(info.sunsetAt),
    }));
}

/**
 * Get all sunset endpoints
 *
 * @returns {Array} Array of sunset endpoint info
 */
export function getAllSunsetEndpoints() {
  return Object.entries(DEPRECATED_ENDPOINTS)
    .filter(([path]) => isSunset(path))
    .map(([path, info]) => ({
      path,
      ...info,
    }));
}

/**
 * Get deprecation status report
 *
 * @returns {Object} Deprecation status report
 */
export function getDeprecationStatusReport() {
  return {
    timestamp: new Date().toISOString(),
    deprecatedEndpoints: getAllDeprecatedEndpoints(),
    sunsetEndpoints: getAllSunsetEndpoints(),
    totalDeprecated: getAllDeprecatedEndpoints().length,
    totalSunset: getAllSunsetEndpoints().length,
  };
}

export default {
  DeprecationStatus,
  DEPRECATED_ENDPOINTS,
  MIGRATION_GUIDES,
  getDeprecationInfo,
  isDeprecated,
  isSunset,
  getMigrationGuide,
  formatDeprecationWarning,
  getDeprecationHeaders,
  getAllDeprecatedEndpoints,
  getAllSunsetEndpoints,
  getDeprecationStatusReport,
};
