/**
 * API Key Management Routes
 *
 * Provides endpoints for managing API keys for service-to-service authentication.
 * Includes generation, validation, rotation, and revocation.
 *
 * Requirements: 2.8
 * - Create API key generation and validation mechanism
 * - Add API key middleware for service endpoints
 * - Implement API key rotation and revocation
 */

import express from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import logger from '../logger.js';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import {
  generateApiKey,
  listApiKeys,
  getApiKey,
  updateApiKey,
  rotateApiKey,
  revokeApiKey,
  getApiKeyAuditLogs,
} from '../services/api-key-service.js';

const router = express.Router();

const createApiKeySchema = {
  body: z.object({
    name: z.string().trim().min(1, 'API key name is required'),
    description: z.string().default(''),
    scopes: z.array(z.string()).default([]),
    rateLimit: z.number().int().min(1).default(1000),
    expiresIn: z.number().int().min(1000).nullable().default(null),
  }),
};

const updateApiKeySchema = {
  params: z.object({
    keyId: z.string().min(1),
  }),
  body: z
    .object({
      name: z.string().trim().min(1).optional(),
      description: z.string().optional(),
      scopes: z.array(z.string()).optional(),
      rateLimit: z.number().int().min(1).optional(),
    })
    .refine((data) => Object.keys(data).length > 0, {
      message: 'At least one field must be provided for update',
    }),
};

const keyIdParamSchema = {
  params: z.object({
    keyId: z.string().min(1),
  }),
};

// Strict rate limiter for sensitive operations (key generation/rotation)
const apiKeyOpsLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  message: {
    error: 'Too many API key operations',
    message: 'Please try again after an hour',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

router.post(
  '/',
  apiKeyOpsLimiter,
  authenticateJWT,
  validateSchema(createApiKeySchema),
  async (req, res) => {
    try {
      const userId = extractUserId(req);
      const { name, description, scopes, rateLimit, expiresIn } = req.body;

      const apiKey = await generateApiKey(userId, name, {
        description,
        scopes,
        rateLimit,
        expiresIn,
      });

    const { id: newKeyId } = apiKey;
    logger.info('[APIKeyRoutes] API key generated', {
      userId,
      keyId: newKeyId,
      name,
    });

    res.status(201).json(apiKey);
  } catch (error) {
    logger.error('[APIKeyRoutes] Failed to generate API key', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to generate API key',
      code: 'GENERATION_FAILED',
    });
  }
});

router.get('/', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);

    const keys = await listApiKeys(userId);

    logger.debug('[APIKeyRoutes] API keys listed', {
      userId,
      count: keys.length,
    });

    res.json(keys);
  } catch (error) {
    logger.error('[APIKeyRoutes] Failed to list API keys', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to list API keys',
      code: 'LIST_FAILED',
    });
  }
});

router.get(
  '/:keyId',
  authenticateJWT,
  validateSchema(keyIdParamSchema),
  async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { keyId } = req.params;

    const key = await getApiKey(keyId, userId);

    if (!key) {
      return res.status(404).json({
        error: 'API key not found',
        code: 'NOT_FOUND',
      });
    }

    logger.debug('[APIKeyRoutes] API key retrieved', {
      userId,
      keyId,
    });

    res.json(key);
  } catch (error) {
    logger.error('[APIKeyRoutes] Failed to get API key', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to get API key',
      code: 'GET_FAILED',
    });
  }
});

router.patch(
  '/:keyId',
  authenticateJWT,
  validateSchema(updateApiKeySchema),
  async (req, res) => {
    try {
      const userId = extractUserId(req);
      const { keyId } = req.params;
      const updates = req.body;

    const updatedKey = await updateApiKey(keyId, userId, updates);

    logger.info('[APIKeyRoutes] API key updated', {
      userId,
      keyId,
      updates: Object.keys(updates),
    });

    res.json(updatedKey);
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({
        error: 'API key not found',
        code: 'NOT_FOUND',
      });
    }

    logger.error('[APIKeyRoutes] Failed to update API key', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to update API key',
      code: 'UPDATE_FAILED',
    });
  }
});

router.post(
  '/:keyId/rotate',
  apiKeyOpsLimiter,
  authenticateJWT,
  validateSchema(keyIdParamSchema),
  async (req, res) => {
    try {
      const userId = extractUserId(req);
      const { keyId } = req.params;

      const newKey = await rotateApiKey(keyId, userId);

      logger.info('[APIKeyRoutes] API key rotated', {
        userId,
        oldKeyId: keyId,
        newKeyId: newKey.id,
      });

      res.json(newKey);
    } catch (error) {
      if (error.message.includes('not found')) {
        return res.status(404).json({
          error: 'API key not found',
          code: 'NOT_FOUND',
        });
      }

      logger.error('[APIKeyRoutes] Failed to rotate API key', {
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to rotate API key',
        code: 'ROTATION_FAILED',
      });
    }
  },
);

router.post(
  '/:keyId/revoke',
  authenticateJWT,
  validateSchema(keyIdParamSchema),
  async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { keyId } = req.params;

    await revokeApiKey(keyId, userId);

    logger.info('[APIKeyRoutes] API key revoked', {
      userId,
      keyId,
    });

    res.json({
      message: 'API key revoked successfully',
    });
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({
        error: 'API key not found',
        code: 'NOT_FOUND',
      });
    }

    logger.error('[APIKeyRoutes] Failed to revoke API key', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to revoke API key',
      code: 'REVOCATION_FAILED',
    });
  }
});

router.get(
  '/:keyId/audit-logs',
  authenticateJWT,
  validateSchema(keyIdParamSchema),
  async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { keyId } = req.params;

    const logs = await getApiKeyAuditLogs(keyId, userId);

    logger.debug('[APIKeyRoutes] API key audit logs retrieved', {
      userId,
      keyId,
      count: logs.length,
    });

    res.json(logs);
  } catch (error) {
    logger.error('[APIKeyRoutes] Failed to get audit logs', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to get audit logs',
      code: 'AUDIT_LOGS_FAILED',
    });
  }
});

export default router;
