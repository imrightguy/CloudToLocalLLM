/**
 * Webhook Payload Transformation Routes
 *
 * REST API endpoints for managing webhook payload transformations:
 * - POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations - Create/update transformation
 * - GET /api/tunnels/:tunnelId/webhooks/:webhookId/transformations - Get transformation
 * - PUT /api/tunnels/:tunnelId/webhooks/:webhookId/transformations - Update transformation
 * - DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/transformations - Delete transformation
 * - POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/validate - Validate transformation
 * - POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/test - Test transformation
 *
 * Validates: Requirements 10.6
 * - Implements webhook payload transformation
 * - Supports transformation configuration
 * - Validates transformation rules
 *
 * @fileoverview Webhook payload transformation routes
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import logger from '../logger.js';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import WebhookPayloadTransformer from '../services/webhook-payload-transformer.js';

const router = express.Router();
const transformer = new WebhookPayloadTransformer();

const tunnelParamsSchema = {
  params: z.object({
    tunnelId: z.string().min(1).max(100),
    webhookId: z.string().min(1).max(100),
  }),
};

const transformationBodySchema = {
  params: z.object({
    tunnelId: z.string().min(1).max(100),
    webhookId: z.string().min(1).max(100),
  }),
  body: z.object({
    enabled: z.boolean().optional(),
    transformations: z.array(z.any()).optional(),
    fields: z.array(z.any()).optional(),
  }),
};

const validateTransformationSchema = {
  params: z.object({
    tunnelId: z.string().min(1).max(100),
    webhookId: z.string().min(1).max(100),
  }),
  body: z.object({
    enabled: z.boolean().optional(),
    transformations: z.array(z.any()).optional(),
    fields: z.array(z.any()).optional(),
  }),
};

const testTransformationSchema = {
  params: z.object({
    tunnelId: z.string().min(1).max(100),
    webhookId: z.string().min(1).max(100),
  }),
  body: z.object({
    payload: z.record(z.any()).refine((v) => v !== null, { message: 'Payload is required' }),
    transformation: z.object({
      enabled: z.boolean().optional(),
      transformations: z.array(z.any()).optional(),
      fields: z.array(z.any()).optional(),
    }),
  }),
};

/**
 * Initialize transformer service
 */
await transformer.initialize();

/**
 * POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
 * Create or update webhook payload transformation
 */
router.post(
  '/api/tunnels/:tunnelId/webhooks/:webhookId/transformations',
  authenticateJWT,
  validateSchema(transformationBodySchema),
  async (req, res) => {
    try {
      const { tunnelId, webhookId } = req.params;
      const userId = req.user.sub;
      const transformConfig = req.body;

      logger.info('[WebhookTransformationRoutes] Creating transformation', {
        tunnelId,
        webhookId,
        userId,
      });

      // Validate transformation configuration
      const validation = transformer.validateTransformConfig(transformConfig);
      if (!validation.isValid) {
        return res.status(400).json({
          error: 'Invalid transformation configuration',
          details: validation.errors,
        });
      }

      // Create transformation
      const result = await transformer.createTransformation(
        webhookId,
        userId,
        transformConfig,
      );

      res.status(201).json({
        success: true,
        data: result,
      });
    } catch (error) {
      logger.error(
        '[WebhookTransformationRoutes] Failed to create transformation',
        {
          error: error.message,
        },
      );

      res.status(500).json({
        error: 'Failed to create transformation',
        message: error.message,
      });
    }
  },
);

/**
 * GET /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
 * Get webhook payload transformation
 */
router.get(
  '/api/tunnels/:tunnelId/webhooks/:webhookId/transformations',
  authenticateJWT,
  validateSchema(tunnelParamsSchema),
  async (req, res) => {
    try {
      const { webhookId } = req.params;
      const userId = req.user.sub;

      logger.info('[WebhookTransformationRoutes] Getting transformation', {
        webhookId,
        userId,
      });

      const result = await transformer.getTransformation(webhookId, userId);

      if (!result) {
        return res.status(404).json({
          error: 'Transformation not found',
        });
      }

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      logger.error(
        '[WebhookTransformationRoutes] Failed to get transformation',
        {
          error: error.message,
        },
      );

      res.status(500).json({
        error: 'Failed to get transformation',
        message: error.message,
      });
    }
  },
);

/**
 * PUT /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
 * Update webhook payload transformation
 */
router.put(
  '/api/tunnels/:tunnelId/webhooks/:webhookId/transformations',
  authenticateJWT,
  validateSchema(transformationBodySchema),
  async (req, res) => {
    try {
      const { webhookId } = req.params;
      const userId = req.user.sub;
      const transformConfig = req.body;

      logger.info('[WebhookTransformationRoutes] Updating transformation', {
        webhookId,
        userId,
      });

      // Validate transformation configuration
      const validation = transformer.validateTransformConfig(transformConfig);
      if (!validation.isValid) {
        return res.status(400).json({
          error: 'Invalid transformation configuration',
          details: validation.errors,
        });
      }

      // Update transformation
      const result = await transformer.updateTransformation(
        webhookId,
        userId,
        transformConfig,
      );

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      logger.error(
        '[WebhookTransformationRoutes] Failed to update transformation',
        {
          error: error.message,
        },
      );

      res.status(500).json({
        error: 'Failed to update transformation',
        message: error.message,
      });
    }
  },
);

/**
 * DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
 * Delete webhook payload transformation
 */
router.delete(
  '/api/tunnels/:tunnelId/webhooks/:webhookId/transformations',
  authenticateJWT,
  validateSchema(tunnelParamsSchema),
  async (req, res) => {
    try {
      const { webhookId } = req.params;
      const userId = req.user.sub;

      logger.info('[WebhookTransformationRoutes] Deleting transformation', {
        webhookId,
        userId,
      });

      await transformer.deleteTransformation(webhookId, userId);

      res.status(200).json({
        success: true,
        message: 'Transformation deleted',
      });
    } catch (error) {
      logger.error(
        '[WebhookTransformationRoutes] Failed to delete transformation',
        {
          error: error.message,
        },
      );

      res.status(500).json({
        error: 'Failed to delete transformation',
        message: error.message,
      });
    }
  },
);

/**
 * POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/validate
 * Validate webhook payload transformation configuration
 */
router.post(
  '/api/tunnels/:tunnelId/webhooks/:webhookId/transformations/validate',
  authenticateJWT,
  validateSchema(validateTransformationSchema),
  async (req, res) => {
    try {
      const transformConfig = req.body;

      logger.info('[WebhookTransformationRoutes] Validating transformation');

      const validation = transformer.validateTransformConfig(transformConfig);

      res.status(200).json({
        success: true,
        isValid: validation.isValid,
        errors: validation.errors,
      });
    } catch (error) {
      logger.error(
        '[WebhookTransformationRoutes] Failed to validate transformation',
        {
          error: error.message,
        },
      );

      res.status(500).json({
        error: 'Failed to validate transformation',
        message: error.message,
      });
    }
  },
);

/**
 * POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/test
 * Test webhook payload transformation against sample payload
 */
router.post(
  '/api/tunnels/:tunnelId/webhooks/:webhookId/transformations/test',
  authenticateJWT,
  validateSchema(testTransformationSchema),
  async (req, res) => {
    try {
      const { payload, transformation } = req.body;

      logger.info('[WebhookTransformationRoutes] Testing transformation');

      // Apply transformation
      const transformedPayload = transformer.transformPayload(
        payload,
        transformation,
      );

      res.status(200).json({
        success: true,
        originalPayload: payload,
        transformedPayload,
      });
    } catch (error) {
      logger.error(
        '[WebhookTransformationRoutes] Failed to test transformation',
        {
          error: error.message,
        },
      );

      res.status(500).json({
        error: 'Failed to test transformation',
        message: error.message,
      });
    }
  },
);

export default router;
