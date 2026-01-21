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
import logger from '../logger.js';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
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

// Strict rate limiter for sensitive operations (key generation/rotation)
const apiKeyOpsLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // Limit each IP to 10 key generations/rotations per hour
  message: {
    error: 'Too many API key operations',
    message: 'Please try again after an hour',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * POST /api-keys
 * Generate a new API key
 *
 * Request body:
 * {
 *   "name": "string (required)",
 *   "description": "string (optional)",
 *   "scopes": ["string"] (optional),
 *   "rateLimit": "number (optional, default: 1000)",
 *   "expiresIn": "number (optional, milliseconds)"
 * }
 *
 * Response:
 * {
 *   "id": "uuid",
 *   "apiKey": "ctll_...",
 *   "keyPrefix": "ctll_...",
 *   "name": "string",
 *   "description": "string",
 *   "scopes": ["string"],
 *   "rateLimit": "number",
 *   "isActive": "boolean",
 *   "createdAt": "ISO8601",
 *   "expiresAt": "ISO8601 or null"
 * }
 */
router.post('/', apiKeyOpsLimiter, authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { name, description, scopes, rateLimit, expiresIn } = req.body;

    // Validate required fields
    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_NAME',
        message: 'API key name is required and must be a non-empty string',
      });
    }

    // Validate optional fields
    if (
      scopes &&
      (!Array.isArray(scopes) || !scopes.every((s) => typeof s === 'string'))
    ) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_SCOPES',
        message: 'Scopes must be an array of strings',
      });
    }

    if (rateLimit && (typeof rateLimit !== 'number' || rateLimit < 1)) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_RATE_LIMIT',
        message: 'Rate limit must be a positive number',
      });
    }

    if (expiresIn && (typeof expiresIn !== 'number' || expiresIn < 1000)) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_EXPIRES_IN',
        message: 'Expires in must be a number in milliseconds (minimum 1000)',
      });
    }

    const apiKey = await generateApiKey(userId, name.trim(), {
      description: description || '',
      scopes: scopes || [],
      rateLimit: rateLimit || 1000,
      expiresIn: expiresIn || null,
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

/**
 * GET /api-keys
 * List all API keys for the authenticated user
 *
 * Response:
 * [
 *   {
 *     "id": "uuid",
 *     "name": "string",
 *     "keyPrefix": "ctll_...",
 *     "description": "string",
 *     "scopes": ["string"],
 *     "rateLimit": "number",
 *     "isActive": "boolean",
 *     "createdAt": "ISO8601",
 *     "updatedAt": "ISO8601",
 *     "expiresAt": "ISO8601 or null",
 *     "lastUsedAt": "ISO8601 or null"
 *   }
 * ]
 */
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

/**
 * GET /api-keys/:keyId
 * Get details for a specific API key
 *
 * Response:
 * {
 *   "id": "uuid",
 *   "name": "string",
 *   "keyPrefix": "ctll_...",
 *   "description": "string",
 *   "scopes": ["string"],
 *   "rateLimit": "number",
 *   "isActive": "boolean",
 *   "createdAt": "ISO8601",
 *   "updatedAt": "ISO8601",
 *   "expiresAt": "ISO8601 or null",
 *   "lastUsedAt": "ISO8601 or null"
 * }
 */
router.get('/:keyId', authenticateJWT, async (req, res) => {
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

/**
 * PATCH /api-keys/:keyId
 * Update API key metadata
 *
 * Request body:
 * {
 *   "name": "string (optional)",
 *   "description": "string (optional)",
 *   "scopes": ["string"] (optional),
 *   "rateLimit": "number (optional)"
 * }
 *
 * Response: Updated API key object
 */
router.patch('/:keyId', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { keyId } = req.params;
    const updates = req.body;

    // Validate updates
    const allowedFields = ['name', 'description', 'scopes', 'rateLimit'];
    const invalidFields = Object.keys(updates).filter(
      (field) => !allowedFields.includes(field),
    );

    if (invalidFields.length > 0) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_FIELDS',
        message: `Cannot update fields: ${invalidFields.join(', ')}`,
      });
    }

    if (
      updates.name &&
      (typeof updates.name !== 'string' || updates.name.trim().length === 0)
    ) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_NAME',
        message: 'Name must be a non-empty string',
      });
    }

    if (
      updates.scopes &&
      (!Array.isArray(updates.scopes) ||
        !updates.scopes.every((s) => typeof s === 'string'))
    ) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_SCOPES',
        message: 'Scopes must be an array of strings',
      });
    }

    if (
      updates.rateLimit &&
      (typeof updates.rateLimit !== 'number' || updates.rateLimit < 1)
    ) {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_RATE_LIMIT',
        message: 'Rate limit must be a positive number',
      });
    }

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

/**
 * POST /api-keys/:keyId/rotate
 * Rotate an API key (revoke old, generate new)
 *
 * Response:
 * {
 *   "id": "uuid",
 *   "apiKey": "ctll_...",
 *   "keyPrefix": "ctll_...",
 *   "name": "string",
 *   "description": "string",
 *   "scopes": ["string"],
 *   "rateLimit": "number",
 *   "isActive": "boolean",
 *   "createdAt": "ISO8601",
 *   "expiresAt": "ISO8601 or null"
 * }
 */
router.post(
  '/:keyId/rotate',
  apiKeyOpsLimiter,
  authenticateJWT,
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

/**
 * POST /api-keys/:keyId/revoke
 * Revoke an API key
 *
 * Response:
 * {
 *   "message": "API key revoked successfully"
 * }
 */
router.post('/:keyId/revoke', authenticateJWT, async (req, res) => {
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

/**
 * GET /api-keys/:keyId/audit-logs
 * Get audit logs for an API key
 *
 * Response:
 * [
 *   {
 *     "id": "uuid",
 *     "action": "created|used|rotated|revoked|expired",
 *     "details": "object",
 *     "createdAt": "ISO8601"
 *   }
 * ]
 */
router.get('/:keyId/audit-logs', authenticateJWT, async (req, res) => {
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
