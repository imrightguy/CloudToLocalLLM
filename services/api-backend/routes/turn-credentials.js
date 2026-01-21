/**
 * TURN Server Credentials API Route
 *
 * Provides secure access to TURN server credentials for authenticated users.
 * Credentials are never exposed in client-side code.
 *
 * GET /api/turn/credentials - Get TURN server credentials (requires authentication)
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * GET /api/turn/credentials
 * Get TURN server credentials for authenticated users
 *
 * Response:
 * - 200: Credentials retrieved successfully
 * - 401: Unauthorized (not authenticated)
 */
router.get('/credentials', authenticateJWT, (req, res) => {
  try {
    // Get TURN credentials from environment variables
    // These should be set securely in production (e.g., Kubernetes secrets)
    const turnUsername = process.env.TURN_USERNAME || 'cloudtolocalllm';
    const turnCredential =
      process.env.TURN_CREDENTIAL || process.env.TURN_PASSWORD || '';
    const turnUrls = process.env.TURN_URLS
      ? process.env.TURN_URLS.split(',')
      : ['turn:174.138.115.184:3478', 'turn:174.138.115.184:5349'];

    if (!turnCredential) {
      logger.warn('[TURN Credentials] TURN credential not configured');
      return res.status(503).json({
        status: 'error',
        error: 'TURN server not configured',
        timestamp: new Date().toISOString(),
      });
    }

    // Return credentials to authenticated user
    res.json({
      status: 'success',
      turnServer: {
        urls: turnUrls,
        username: turnUsername,
        credential: turnCredential,
      },
      timestamp: new Date().toISOString(),
    });

    logger.debug(
      '[TURN Credentials] Credentials provided to authenticated user',
      {
        userId: req.user?.sub || req.user?.id,
      }
    );
  } catch (error) {
    logger.error('🔴 [TURN Credentials] Error retrieving credentials', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

export default router;
