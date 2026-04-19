/**
 * Webhook Testing and Debugging Routes
 *
 * Provides endpoints for testing and debugging webhook functionality:
 * - POST /api/webhooks/test/payload - Generate test payload
 * - POST /api/webhooks/test/send - Send test webhook
 * - GET /api/webhooks/test/events - Get test event history
 * - GET /api/webhooks/test/events/:testId - Get specific test event
 * - GET /api/webhooks/:webhookId/debug - Get webhook debug info
 * - GET /api/webhooks/deliveries/:deliveryId/details - Get delivery details
 * - POST /api/webhooks/test/validate - Validate webhook payload
 *
 * Validates: Requirements 10.8
 * - Provides webhook testing and debugging tools
 * - Generates test payloads
 * - Tracks test events
 *
 * @fileoverview Webhook testing and debugging routes
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import logger from '../logger.js';
import { webhookTestingService } from '../services/webhook-testing-service.js';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();

const testPayloadSchema = {
  body: z.object({
    eventType: z.string().min(1).max(200),
    customData: z.record(z.unknown()).optional().default({}),
  }),
};

const testSendSchema = {
  body: z.object({
    webhookUrl: z
      .string()
      .url()
      .max(2048)
      .refine((url) => {
        try {
          const parsed = new URL(url);
          if (!['http:', 'https:'].includes(parsed.protocol)) {
            return false;
          }
          const hostname = parsed.hostname.toLowerCase();
          if (
            hostname === 'localhost' ||
            hostname === '127.0.0.1' ||
            hostname === '0.0.0.0' ||
            hostname === '::1' ||
            hostname.endsWith('.local') ||
            hostname.endsWith('.internal') ||
            hostname === 'metadata.google.internal' ||
            /^169\.254\./.test(hostname) ||
            /^10\./.test(hostname) ||
            /^172\.(1[6-9]|2\d|3[01])\./.test(hostname) ||
            /^192\.168\./.test(hostname)
          ) {
            return false;
          }
          return true;
        } catch {
          return false;
        }
      }, 'Invalid or disallowed webhook URL'),
    eventType: z.string().min(1).max(200),
    customData: z.record(z.unknown()).optional().default({}),
    secret: z.string().max(500).optional(),
  }),
};

const testEventsQuerySchema = {
  query: z.object({
    limit: z
      .string()
      .regex(/^\d+$/)
      .transform(Number)
      .optional()
      .default(100),
  }),
};

const testIdParamSchema = {
  params: z.object({
    testId: z.string().min(1).max(200),
  }),
};

const webhookIdParamSchema = {
  params: z.object({
    webhookId: z.string().min(1).max(200),
  }),
};

const deliveryIdParamSchema = {
  params: z.object({
    deliveryId: z.string().min(1).max(200),
  }),
};

const validatePayloadSchema = {
  body: z.object({
    payload: z.record(z.unknown()),
  }),
};

/**
 * Initialize webhook testing service
 */
await webhookTestingService.initialize();

/**
 * POST /api/webhooks/test/payload
 *
 * Generate test payload for a specific event type
 *
 * Request body:
 * {
 *   "eventType": "tunnel.status_changed",
 *   "customData": { ... }
 * }
 *
 * Response:
 * {
 *   "payload": { ... }
 * }
 */
router.post('/test/payload', authenticateJWT, validateSchema(testPayloadSchema), (req, res) => {
  try {
    const { eventType, customData } = req.body;

    const supportedTypes = webhookTestingService.getSupportedEventTypes();
    if (!supportedTypes.includes(eventType)) {
      return res.status(400).json({
        error: `Unsupported event type. Supported types: ${supportedTypes.join(', ')}`,
        supportedTypes,
      });
    }

    const payload = webhookTestingService.generateTestPayload(
      eventType,
      customData || {},
    );

    logger.info('[WebhookTesting] Test payload generated', {
      userId: req.user.sub,
      eventType,
    });

    res.json({ payload });
  } catch (error) {
    logger.error('[WebhookTesting] Failed to generate test payload', {
      userId: req.user.sub,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to generate test payload' });
  }
});

/**
 * POST /api/webhooks/test/send
 *
 * Send test webhook to a URL
 *
 * Request body:
 * {
 *   "webhookUrl": "https://example.com/webhook",
 *   "eventType": "tunnel.status_changed",
 *   "customData": { ... },
 *   "secret": "optional_webhook_secret"
 * }
 *
 * Response:
 * {
 *   "testId": "...",
 *   "success": true,
 *   "statusCode": 200,
 *   "responseTime": 123,
 *   ...
 * }
 */
router.post('/test/send', authenticateJWT, validateSchema(testSendSchema), async (req, res) => {
  try {
    const { webhookUrl, eventType, customData, secret } = req.body;

    const payload = webhookTestingService.generateTestPayload(
      eventType,
      customData,
    );

    // Simulate delivery
    const result = await webhookTestingService.simulateWebhookDelivery(
      webhookUrl,
      payload,
      secret,
    );

    logger.info('[WebhookTesting] Test webhook sent', {
      userId: req.user.sub,
      testId: result.testId,
      webhookUrl,
      eventType,
      success: result.success,
    });

    res.json(result);
  } catch (error) {
    logger.error('[WebhookTesting] Failed to send test webhook', {
      userId: req.user.sub,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to send test webhook' });
  }
});

/**
 * GET /api/webhooks/test/events
 *
 * Get test event history
 *
 * Query parameters:
 * - limit: Maximum number of events to return (default: 100)
 *
 * Response:
 * {
 *   "events": [ ... ]
 * }
 */
router.get('/test/events', authenticateJWT, validateSchema(testEventsQuerySchema), (req, res) => {
  try {
    const limit = Math.min(req.query.limit, 1000);
    const events = webhookTestingService.getAllTestEvents(limit);

    logger.info('[WebhookTesting] Test events retrieved', {
      userId: req.user.sub,
      count: events.length,
    });

    res.json({ events });
  } catch (error) {
    logger.error('[WebhookTesting] Failed to get test events', {
      userId: req.user.sub,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to get test events' });
  }
});

/**
 * GET /api/webhooks/test/events/:testId
 *
 * Get specific test event
 *
 * Response:
 * {
 *   "event": { ... }
 * }
 */
router.get('/test/events/:testId', authenticateJWT, validateSchema(testIdParamSchema), (req, res) => {
  try {
    const { testId } = req.params;
    const event = webhookTestingService.getTestEvent(testId);

    if (!event) {
      return res.status(404).json({
        error: 'Test event not found',
      });
    }

    logger.info('[WebhookTesting] Test event retrieved', {
      userId: req.user.sub,
      testId,
    });

    res.json({ event });
  } catch (error) {
    logger.error('[WebhookTesting] Failed to get test event', {
      userId: req.user.sub,
      testId: req.params.testId,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to get test event' });
  }
});

/**
 * GET /api/webhooks/:webhookId/debug
 *
 * Get webhook debug information
 *
 * Response:
 * {
 *   "webhook": { ... },
 *   "recentDeliveries": [ ... ],
 *   "statistics": { ... }
 * }
 */
router.get('/:webhookId/debug', authenticateJWT, validateSchema(webhookIdParamSchema), async (req, res) => {
  try {
    const { webhookId } = req.params;
    const userId = req.user.sub;

    const debugInfo = await webhookTestingService.getWebhookDebugInfo(
      webhookId,
      userId,
    );

    if (debugInfo.error) {
      return res.status(404).json({ error: debugInfo.error });
    }

    logger.info('[WebhookTesting] Webhook debug info retrieved', {
      userId,
      webhookId,
    });

    res.json(debugInfo);
  } catch (error) {
    logger.error('[WebhookTesting] Failed to get webhook debug info', {
      userId: req.user.sub,
      webhookId: req.params.webhookId,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to get webhook debug info' });
  }
});

/**
 * GET /api/webhooks/deliveries/:deliveryId/details
 *
 * Get webhook delivery details
 *
 * Response:
 * {
 *   "delivery": { ... }
 * }
 */
router.get(
  '/deliveries/:deliveryId/details',
  authenticateJWT,
  validateSchema(deliveryIdParamSchema),
  async (req, res) => {
    try {
      const { deliveryId } = req.params;
      const userId = req.user.sub;

      const details = await webhookTestingService.getDeliveryDetails(
        deliveryId,
        userId,
      );

      if (details.error) {
        return res.status(404).json({ error: details.error });
      }

      logger.info('[WebhookTesting] Delivery details retrieved', {
        userId,
        deliveryId,
      });

      res.json({ delivery: details });
    } catch (error) {
      logger.error('[WebhookTesting] Failed to get delivery details', {
        userId: req.user.sub,
        deliveryId: req.params.deliveryId,
        error: error.message,
      });
      res.status(500).json({ error: 'Failed to get delivery details' });
    }
  },
);

/**
 * POST /api/webhooks/test/validate
 *
 * Validate webhook payload structure
 *
 * Request body:
 * {
 *   "payload": { ... }
 * }
 *
 * Response:
 * {
 *   "isValid": true,
 *   "errors": []
 * }
 */
router.post('/test/validate', authenticateJWT, validateSchema(validatePayloadSchema), (req, res) => {
  try {
    const { payload } = req.body;

    const validation = webhookTestingService.validatePayloadStructure(payload);

    logger.info('[WebhookTesting] Payload validated', {
      userId: req.user.sub,
      isValid: validation.isValid,
      errorCount: validation.errors.length,
    });

    res.json(validation);
  } catch (error) {
    logger.error('[WebhookTesting] Failed to validate payload', {
      userId: req.user.sub,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to validate payload' });
  }
});

/**
 * GET /api/webhooks/test/supported-types
 *
 * Get list of supported event types for testing
 *
 * Response:
 * {
 *   "supportedTypes": [ ... ]
 * }
 */
router.get('/test/supported-types', authenticateJWT, (req, res) => {
  try {
    const supportedTypes = webhookTestingService.getSupportedEventTypes();

    logger.info('[WebhookTesting] Supported types retrieved', {
      userId: req.user.sub,
      count: supportedTypes.length,
    });

    res.json({ supportedTypes });
  } catch (error) {
    logger.error('[WebhookTesting] Failed to get supported types', {
      userId: req.user.sub,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to get supported types' });
  }
});

/**
 * DELETE /api/webhooks/test/events
 *
 * Clear test event cache
 *
 * Response:
 * {
 *   "message": "Test event cache cleared"
 * }
 */
router.delete('/test/events', authenticateJWT, (req, res) => {
  try {
    webhookTestingService.clearTestEventCache();

    logger.info('[WebhookTesting] Test event cache cleared', {
      userId: req.user.sub,
    });

    res.json({ message: 'Test event cache cleared' });
  } catch (error) {
    logger.error('[WebhookTesting] Failed to clear test event cache', {
      userId: req.user.sub,
      error: error.message,
    });
    res.status(500).json({ error: 'Failed to clear test event cache' });
  }
});

export default router;
