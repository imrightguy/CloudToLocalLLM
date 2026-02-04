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
  defaultMeta: { service: 'proxy-config-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Global proxy config service (will be injected)
let proxyConfigService = null;

/**
 * Initialize proxy config routes with service
 * @param {ProxyConfigService} configService - Proxy config service instance
 * @returns {Router} Express router
 */
export function createProxyConfigRoutes(configService) {
  proxyConfigService = configService;
  return router;
}

/**
 * POST /proxy/config/:proxyId
 * Create or initialize proxy configuration
 * Validates: Requirements 5.4
 */
router.post(
  '/config/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const { config, templateId } = req.body;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      let configToUse = config || {};

      // If templateId provided, use template as base
      if (templateId) {
        try {
          const template =
            await proxyConfigService.getConfigTemplate(templateId);
          if (!template) {
            return res.status(404).json({
              error: 'NOT_FOUND',
              message: 'Configuration template not found',
              code: 'PROXY_CONFIG_003',
            });
          }
          configToUse = { ...JSON.parse(template.template_config), ...config };
        } catch {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'Failed to parse template configuration',
            code: 'PROXY_CONFIG_004',
          });
        }
      }

      const createdConfig = await proxyConfigService.createProxyConfig(
        proxyId,
        userId,
        configToUse,
      );

      logger.info('Proxy configuration created', {
        proxyId,
        userId,
        configId: createdConfig.id,
      });

      res.status(201).json({
        proxyId,
        config: createdConfig,
        message: 'Configuration created successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      if (error.validationErrors) {
        return res.status(400).json({
          error: 'VALIDATION_ERROR',
          message: 'Configuration validation failed',
          code: 'PROXY_CONFIG_005',
          validationErrors: error.validationErrors,
        });
      }

      logger.error('Error creating proxy configuration', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to create proxy configuration',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * GET /proxy/config/:proxyId
 * Get proxy configuration
 * Validates: Requirements 5.4
 */
router.get(
  '/config/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const config = await proxyConfigService.getProxyConfig(proxyId);

      if (!config) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Proxy configuration not found',
          code: 'PROXY_CONFIG_003',
        });
      }

      logger.info('Proxy configuration retrieved', {
        proxyId,
        userId,
      });

      res.json({
        proxyId,
        config,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy configuration', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy configuration',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * PUT /proxy/config/:proxyId
 * Update proxy configuration
 * Validates: Requirements 5.4
 */
router.put(
  '/config/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const { updates, changeReason } = req.body;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!updates || typeof updates !== 'object') {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'updates object is required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const updatedConfig = await proxyConfigService.updateProxyConfig(
        proxyId,
        userId,
        updates,
        changeReason || 'Manual update',
      );

      logger.info('Proxy configuration updated', {
        proxyId,
        userId,
        changeReason,
      });

      res.json({
        proxyId,
        config: updatedConfig,
        message: 'Configuration updated successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      if (error.validationErrors) {
        return res.status(400).json({
          error: 'VALIDATION_ERROR',
          message: 'Configuration validation failed',
          code: 'PROXY_CONFIG_005',
          validationErrors: error.validationErrors,
        });
      }

      if (error.message.includes('not found')) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: error.message,
          code: 'PROXY_CONFIG_003',
        });
      }

      logger.error('Error updating proxy configuration', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to update proxy configuration',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * DELETE /proxy/config/:proxyId
 * Delete proxy configuration
 * Validates: Requirements 5.4
 */
router.delete(
  '/config/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      // Check admin permission
      const userRole =
        req.user?.['https://zoidbot.online/role'] || 'user';
      if (userRole !== 'admin') {
        return res.status(403).json({
          error: 'FORBIDDEN',
          message: 'Admin access required',
          code: 'PROXY_CONFIG_006',
        });
      }

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      await proxyConfigService.deleteProxyConfig(proxyId);

      logger.info('Proxy configuration deleted', {
        proxyId,
        userId,
      });

      res.json({
        proxyId,
        message: 'Configuration deleted successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error deleting proxy configuration', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to delete proxy configuration',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * GET /proxy/config/:proxyId/history
 * Get configuration change history
 * Validates: Requirements 5.4
 */
router.get(
  '/config/:proxyId/history',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const limit = parseInt(req.query.limit || '50', 10);

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const history = await proxyConfigService.getConfigHistory(proxyId, limit);

      logger.info('Proxy configuration history retrieved', {
        proxyId,
        userId,
        recordCount: history.length,
      });

      res.json({
        proxyId,
        history,
        recordCount: history.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy configuration history', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve configuration history',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * POST /proxy/config/templates
 * Create configuration template
 * Validates: Requirements 5.4
 */
router.post(
  '/config/templates',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const userId = req.user?.sub;
      const { name, config, description, isDefault } = req.body;

      // Check admin permission
      const userRole =
        req.user?.['https://zoidbot.online/role'] || 'user';
      if (userRole !== 'admin') {
        return res.status(403).json({
          error: 'FORBIDDEN',
          message: 'Admin access required',
          code: 'PROXY_CONFIG_006',
        });
      }

      if (!name || !config) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'name and config are required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const template = await proxyConfigService.createConfigTemplate(
        name,
        userId,
        config,
        description || '',
        isDefault || false,
      );

      logger.info('Configuration template created', {
        templateId: template.id,
        name,
        userId,
      });

      res.status(201).json({
        template,
        message: 'Template created successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      if (error.validationErrors) {
        return res.status(400).json({
          error: 'VALIDATION_ERROR',
          message: 'Configuration validation failed',
          code: 'PROXY_CONFIG_005',
          validationErrors: error.validationErrors,
        });
      }

      logger.error('Error creating configuration template', {
        error: error.message,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to create configuration template',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * GET /proxy/config/templates
 * Get all configuration templates
 * Validates: Requirements 5.4
 */
router.get(
  '/config/templates',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const userId = req.user?.sub;

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const templates = await proxyConfigService.getAllConfigTemplates();

      logger.info('Configuration templates retrieved', {
        userId,
        templateCount: templates.length,
      });

      res.json({
        templates,
        templateCount: templates.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving configuration templates', {
        error: error.message,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve configuration templates',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * GET /proxy/config/templates/default
 * Get default configuration template
 * Validates: Requirements 5.4
 */
router.get(
  '/config/templates/default',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const userId = req.user?.sub;

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const template = await proxyConfigService.getDefaultConfigTemplate();

      if (!template) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Default configuration template not found',
          code: 'PROXY_CONFIG_003',
        });
      }

      logger.info('Default configuration template retrieved', {
        userId,
        templateId: template.id,
      });

      res.json({
        template,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving default configuration template', {
        error: error.message,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve default configuration template',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * POST /proxy/config/:proxyId/apply-template/:templateId
 * Apply configuration template to proxy
 * Validates: Requirements 5.4
 */
router.post(
  '/config/:proxyId/apply-template/:templateId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId, templateId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId || !templateId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId and templateId are required',
          code: 'PROXY_CONFIG_001',
        });
      }

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const updatedConfig = await proxyConfigService.applyConfigTemplate(
        proxyId,
        userId,
        templateId,
      );

      logger.info('Configuration template applied', {
        proxyId,
        templateId,
        userId,
      });

      res.json({
        proxyId,
        config: updatedConfig,
        message: 'Template applied successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      if (error.message.includes('not found')) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: error.message,
          code: 'PROXY_CONFIG_003',
        });
      }

      logger.error('Error applying configuration template', {
        error: error.message,
        proxyId: req.params.proxyId,
        templateId: req.params.templateId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to apply configuration template',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

/**
 * GET /proxy/config/validation-rules
 * Get configuration validation rules
 * Validates: Requirements 5.4
 */
router.get(
  '/config/validation-rules',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const userId = req.user?.sub;

      if (!proxyConfigService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy config service not initialized',
          code: 'PROXY_CONFIG_002',
        });
      }

      const rules = proxyConfigService.getValidationRules();
      const defaultConfig = proxyConfigService.getDefaultConfig();

      logger.info('Configuration validation rules retrieved', {
        userId,
      });

      res.json({
        validationRules: rules,
        defaultConfig,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving validation rules', {
        error: error.message,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve validation rules',
        code: 'PROXY_CONFIG_002',
      });
    }
  },
);

export default router;
