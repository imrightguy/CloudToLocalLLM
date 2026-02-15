/**
 * Infrastructure Tunnel Management API Routes
 *
 * Provides endpoints for managing the Cloudflare infrastructure tunnel.
 * All endpoints require X-Infrastructure-Key authentication.
 *
 * Endpoints:
 * - GET  /status          - Tunnel health and status
 * - GET  /connectors      - Active cloudflared connectors
 * - GET  /routes          - Current ingress configuration
 * - PUT  /routes          - Update ingress configuration
 * - POST /routes/reset    - Reset to default Docker Swarm config
 * - GET  /dns             - DNS records pointing to tunnel
 * - POST /dns/sync        - Sync/repair DNS records
 * - POST /restart         - Restart cloudflared service
 * - POST /cache/purge     - Purge Cloudflare cache
 * - GET  /diagnostics     - Full diagnostic report
 *
 * @fileoverview Infrastructure tunnel management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { authenticateInfrastructure } from '../middleware/infrastructure-auth.js';
import { getInfrastructureTunnelService } from '../services/cloudflare-infrastructure-tunnel-service.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * GET /api/infrastructure/tunnel/status
 *
 * Get tunnel status and health information
 *
 * Authentication: X-Infrastructure-Key
 */
router.get('/status', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const status = await service.getTunnelStatus();

    res.json({
      success: true,
      data: status,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error getting status', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'STATUS_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/infrastructure/tunnel/connectors
 *
 * Get active cloudflared connectors
 *
 * Authentication: X-Infrastructure-Key
 */
router.get('/connectors', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const connectors = await service.getConnectors();

    res.json({
      success: true,
      data: connectors,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error getting connectors', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'CONNECTORS_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/infrastructure/tunnel/routes
 *
 * Get current ingress configuration
 *
 * Authentication: X-Infrastructure-Key
 */
router.get('/routes', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const config = await service.getIngressConfig();

    res.json({
      success: true,
      data: config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error getting routes', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'ROUTES_ERROR',
      message: error.message,
    });
  }
});

/**
 * PUT /api/infrastructure/tunnel/routes
 *
 * Update ingress configuration
 *
 * Request body:
 * {
 *   "ingress": [
 *     { "hostname": "example.com", "service": "http://backend:8080" },
 *     { "service": "http_status:404" }
 *   ]
 * }
 *
 * Authentication: X-Infrastructure-Key
 */
router.put('/routes', authenticateInfrastructure, async (req, res) => {
  try {
    const { ingress, warpRouting } = req.body;

    if (!ingress || !Array.isArray(ingress)) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_INGRESS',
        message: 'Request body must contain "ingress" array',
      });
    }

    const service = getInfrastructureTunnelService();
    const result = await service.updateIngressConfig(ingress, { warpRouting });

    logger.info('[InfraTunnelRoutes] Routes updated', {
      version: result.version,
      ruleCount: result.ingress.length,
    });

    res.json({
      success: true,
      data: result,
      message: 'Ingress configuration updated',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error updating routes', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'ROUTES_UPDATE_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/infrastructure/tunnel/routes/reset
 *
 * Reset ingress configuration to default Docker Swarm config
 *
 * Authentication: X-Infrastructure-Key
 */
router.post('/routes/reset', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const result = await service.applySwarmConfig();

    logger.info('[InfraTunnelRoutes] Routes reset to defaults', {
      version: result.version,
    });

    res.json({
      success: true,
      data: result,
      message: 'Ingress configuration reset to Docker Swarm defaults',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error resetting routes', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'ROUTES_RESET_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/infrastructure/tunnel/dns
 *
 * Get DNS records pointing to the tunnel
 *
 * Authentication: X-Infrastructure-Key
 */
router.get('/dns', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const records = await service.getTunnelDnsRecords();

    res.json({
      success: true,
      data: records,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error getting DNS records', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'DNS_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/infrastructure/tunnel/dns/sync
 *
 * Sync/repair DNS records for the tunnel
 *
 * Request body (optional):
 * {
 *   "subdomains": ["api", "app", "streaming"]  // Specific subdomains to sync
 * }
 *
 * If no body provided, syncs all default subdomains.
 *
 * Authentication: X-Infrastructure-Key
 */
router.post('/dns/sync', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const { subdomains } = req.body;

    let result;

    if (subdomains && Array.isArray(subdomains)) {
      // Sync specific subdomains
      result = { synced: [], failed: [] };

      for (const subdomain of subdomains) {
        try {
          const record = await service.syncTunnelDnsRecord(subdomain);
          result.synced.push({
            subdomain: subdomain || '(root)',
            id: record.id,
            name: record.name,
          });
        } catch (error) {
          result.failed.push({
            subdomain: subdomain || '(root)',
            error: error.message,
          });
        }
      }
    } else {
      // Sync all default subdomains
      result = await service.syncAllDnsRecords();
    }

    logger.info('[InfraTunnelRoutes] DNS sync completed', {
      synced: result.synced.length,
      failed: result.failed.length,
    });

    res.json({
      success: true,
      data: result,
      message: `Synced ${result.synced.length} records, ${result.failed.length} failed`,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error syncing DNS', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'DNS_SYNC_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/infrastructure/tunnel/restart
 *
 * Restart the cloudflared service
 *
 * Requires Docker socket mount in the container.
 *
 * Authentication: X-Infrastructure-Key
 */
router.post('/restart', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const result = await service.restartCloudflaredService();

    if (result.success) {
      logger.info('[InfraTunnelRoutes] Cloudflared restarted', {
        method: result.method,
      });

      res.json({
        success: true,
        data: result,
        message: 'Cloudflared service restart initiated',
        timestamp: new Date().toISOString(),
      });
    } else {
      res.status(500).json({
        error: 'Restart failed',
        code: 'RESTART_FAILED',
        message: result.message,
        details: result.error,
      });
    }
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error restarting cloudflared', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'RESTART_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/infrastructure/tunnel/cache/purge
 *
 * Purge Cloudflare cache
 *
 * Request body (optional):
 * {
 *   "urls": ["https://app.zoidbot.online/"]  // Specific URLs to purge
 * }
 *
 * If no body provided, purges entire zone cache.
 *
 * Authentication: X-Infrastructure-Key
 */
router.post('/cache/purge', authenticateInfrastructure, async (req, res) => {
  try {
    const { urls } = req.body;
    const service = getInfrastructureTunnelService();
    const result = await service.purgeCache({ urls });

    logger.info('[InfraTunnelRoutes] Cache purged', {
      purgeAll: !urls,
      urlCount: urls?.length || 0,
    });

    res.json({
      success: true,
      data: result,
      message: urls
        ? `Purged ${urls.length} URLs from cache`
        : 'Purged entire zone cache',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error purging cache', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'CACHE_PURGE_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/infrastructure/tunnel/diagnostics
 *
 * Get full diagnostics report
 *
 * Returns:
 * - Tunnel status
 * - Active connectors
 * - Ingress configuration
 * - DNS records
 * - Health assessment
 *
 * Authentication: X-Infrastructure-Key
 */
router.get('/diagnostics', authenticateInfrastructure, async (req, res) => {
  try {
    const service = getInfrastructureTunnelService();
    const diagnostics = await service.getDiagnostics();

    res.json({
      success: true,
      data: diagnostics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[InfraTunnelRoutes] Error getting diagnostics', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'DIAGNOSTICS_ERROR',
      message: error.message,
    });
  }
});

export default router;
