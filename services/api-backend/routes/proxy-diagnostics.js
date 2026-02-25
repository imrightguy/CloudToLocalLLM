import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { addTierInfo } from '../middleware/tier-check.js';
import winston from 'winston';

const router = express.Router();

// Logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'proxy-diagnostics-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Global proxy diagnostics service (will be injected)
let proxyDiagnosticsService = null;

/**
 * Initialize proxy diagnostics routes with service
 * @param {ProxyDiagnosticsService} diagnosticsService - Proxy diagnostics service instance
 * @returns {Router} Express router
 */
export function createProxyDiagnosticsRoutes(diagnosticsService) {
  proxyDiagnosticsService = diagnosticsService;
  return router;
}

/**
 * GET /proxy/diagnostics/:proxyId
 * Get comprehensive diagnostics for a proxy
 * Validates: Requirements 5.7
 */
router.get(
  '/diagnostics/:proxyId',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      const diagnostics = proxyDiagnosticsService.getDiagnostics(proxyId);

      logger.info('Proxy diagnostics retrieved', {
        proxyId,
        userId,
        status: diagnostics.diagnosticStatus,
      });

      res.json(diagnostics);
    } catch (error) {
      logger.error('Error retrieving proxy diagnostics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy diagnostics',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

/**
 * GET /proxy/diagnostics/:proxyId/logs
 * Get diagnostic logs for a proxy
 * Validates: Requirements 5.7
 */
router.get(
  '/diagnostics/:proxyId/logs',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const { level, since, limit } = req.query;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      const options = {
        level,
        since,
        limit: limit ? parseInt(limit, 10) : 100,
      };

      const logs = proxyDiagnosticsService.getDiagnosticLogs(proxyId, options);

      logger.info('Proxy diagnostic logs retrieved', {
        proxyId,
        userId,
        logCount: logs.length,
      });

      res.json({
        proxyId,
        logs,
        count: logs.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy diagnostic logs', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy diagnostic logs',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

/**
 * GET /proxy/diagnostics/:proxyId/errors
 * Get error history for a proxy
 * Validates: Requirements 5.7
 */
router.get(
  '/diagnostics/:proxyId/errors',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const { since, limit } = req.query;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      const options = {
        since,
        limit: limit ? parseInt(limit, 10) : 50,
      };

      const errors = proxyDiagnosticsService.getErrorHistory(proxyId, options);

      logger.info('Proxy error history retrieved', {
        proxyId,
        userId,
        errorCount: errors.length,
      });

      res.json({
        proxyId,
        errors,
        count: errors.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy error history', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy error history',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

/**
 * GET /proxy/diagnostics/:proxyId/events
 * Get event history for a proxy
 * Validates: Requirements 5.7
 */
router.get(
  '/diagnostics/:proxyId/events',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const { type, since, limit } = req.query;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      const options = {
        type,
        since,
        limit: limit ? parseInt(limit, 10) : 100,
      };

      const events = proxyDiagnosticsService.getEventHistory(proxyId, options);

      logger.info('Proxy event history retrieved', {
        proxyId,
        userId,
        eventCount: events.length,
      });

      res.json({
        proxyId,
        events,
        count: events.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy event history', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy event history',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

/**
 * GET /proxy/diagnostics/:proxyId/troubleshooting
 * Get troubleshooting information for a proxy
 * Validates: Requirements 5.7
 */
router.get(
  '/diagnostics/:proxyId/troubleshooting',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      const troubleshooting =
        proxyDiagnosticsService.getTroubleshootingInfo(proxyId);

      logger.info('Proxy troubleshooting information retrieved', {
        proxyId,
        userId,
        suggestionCount: troubleshooting.suggestions.length,
      });

      res.json(troubleshooting);
    } catch (error) {
      logger.error('Error retrieving proxy troubleshooting information', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy troubleshooting information',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

/**
 * GET /proxy/diagnostics/:proxyId/export
 * Export complete diagnostics data for a proxy
 * Validates: Requirements 5.7
 */
router.get(
  '/diagnostics/:proxyId/export',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      const exportData = proxyDiagnosticsService.exportDiagnostics(proxyId);

      logger.info('Proxy diagnostics exported', {
        proxyId,
        userId,
      });

      // Set headers for file download
      res.setHeader('Content-Type', 'application/json');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="proxy-diagnostics-${proxyId}-${Date.now()}.json"`,
      );

      res.json(exportData);
    } catch (error) {
      logger.error('Error exporting proxy diagnostics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to export proxy diagnostics',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

/**
 * POST /proxy/diagnostics/:proxyId/clear
 * Clear diagnostics data for a proxy (admin only)
 * Validates: Requirements 5.7
 */
router.post(
  '/diagnostics/:proxyId/clear',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      // Check admin permission
      const userRole =
        req.user?.['https://cloudtolocalllm.online/role'] || 'user';
      if (userRole !== 'admin') {
        return res.status(403).json({
          error: 'FORBIDDEN',
          message: 'Admin access required',
          code: 'PROXY_DIAG_004',
        });
      }

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_DIAG_001',
        });
      }

      if (!proxyDiagnosticsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy diagnostics service not initialized',
          code: 'PROXY_DIAG_002',
        });
      }

      proxyDiagnosticsService.clearDiagnostics(proxyId);

      logger.info('Proxy diagnostics cleared', {
        proxyId,
        userId,
      });

      res.json({
        proxyId,
        message: 'Diagnostics cleared successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error clearing proxy diagnostics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to clear proxy diagnostics',
        code: 'PROXY_DIAG_003',
      });
    }
  },
);

export default router;
