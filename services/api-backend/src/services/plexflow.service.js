const { cache, invalidate } = require('../utils/cache');
const logger = require('../utils/logger');

const CACHE_TTL_SECONDS = 3600;
const REQUEST_TIMEOUT_MS = 8000;

function isConfigured() {
  return Boolean(process.env.PLEXFLOW_API_URL);
}

function asArray(raw) {
  if (Array.isArray(raw)) {
    return raw;
  }
  if (raw && Array.isArray(raw.data)) {
    return raw.data;
  }
  return [];
}

async function plexflowGet(path) {
  const baseUrl = process.env.PLEXFLOW_API_URL;
  if (!baseUrl) {
    return null;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const headers = { 'Content-Type': 'application/json' };
    if (process.env.PLEXFLOW_API_KEY) {
      headers.Authorization = `Bearer ${process.env.PLEXFLOW_API_KEY}`;
    }

    const response = await fetch(`${baseUrl}${path}`, {
      method: 'GET',
      headers,
      signal: controller.signal,
    });

    if (!response.ok) {
      logger.warn('[plexflow.service] non-2xx response', { path, status: response.status });
      return null;
    }

    return await response.json();
  } catch (error) {
    logger.warn('[plexflow.service] request failed', { path, error: error.message });
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

async function cachedGet(cacheKey, path) {
  const cached = cache.get(cacheKey);
  if (cached !== undefined) {
    return cached;
  }
  const data = asArray(await plexflowGet(path));
  cache.set(cacheKey, data, CACHE_TTL_SECONDS);
  return data;
}

async function getBuildings() {
  return cachedGet('plexflow:buildings', '/buildings');
}

async function getUnits(buildingId) {
  const encoded = encodeURIComponent(buildingId);
  return cachedGet(`plexflow:units:${buildingId}`, `/buildings/${encoded}/units`);
}

async function getLeases(unitId) {
  const encoded = encodeURIComponent(unitId);
  return cachedGet(`plexflow:leases:${unitId}`, `/units/${encoded}/leases`);
}

async function getTenants(unitId) {
  const encoded = encodeURIComponent(unitId);
  return cachedGet(`plexflow:tenants:${unitId}`, `/units/${encoded}/tenants`);
}

async function syncAll() {
  invalidate('plexflow:*');
  const buildings = await getBuildings();
  return {
    configured: isConfigured(),
    syncedAt: new Date().toISOString(),
    buildingCount: buildings.length,
  };
}

module.exports = {
  isConfigured,
  getBuildings,
  getUnits,
  getLeases,
  getTenants,
  syncAll,
};
