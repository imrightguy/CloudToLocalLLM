/**
 * Composite Authentication Middleware
 *
 * Allows authentication via either JWT (User Session) OR API Key (Service/Bridge).
 * Useful for endpoints accessed by both the Frontend Client and the Backend Bridge/Scripts.
 */

import { optionalAuth } from './auth.js';
import { optionalApiKeyAuth } from './api-key-auth.js';

export const authenticateComposite = [
  // 1. Try to authenticate with JWT (header: Authorization: Bearer <token>)
  optionalAuth,

  // 2. Try to authenticate with API Key (header: X-API-Key or Authorization: Bearer <sk_...>)
  optionalApiKeyAuth,

  // 3. Verify that at least one method succeeded
  (req, res, next) => {
    // optionalAuth sets req.user
    // optionalApiKeyAuth sets req.apiKey (and req.userId)

    if (req.user || req.apiKey) {
      return next();
    }

    // Diagnostic logging for debugging 401s
    const authHeader = req.headers['authorization'];
    const hasToken = authHeader && authHeader.startsWith('Bearer ');
    const tokenPreview = hasToken
      ? authHeader.substring(7, 15) + '...'
      : 'none';

    console.warn(
      `[CompositeAuth] Authentication failed for ${req.method} ${req.path}`,
    );
    console.warn(`[CompositeAuth] - Has User: ${!!req.user}`);
    console.warn(`[CompositeAuth] - Has API Key: ${!!req.apiKey}`);
    console.warn(`[CompositeAuth] - Auth Header provided: ${!!authHeader}`);
    console.warn(`[CompositeAuth] - Token preview: ${tokenPreview}`);

    // If we're here, neither auth method succeeded
    return res.status(401).json({
      error: 'Authentication required',
      code: 'AUTH_REQUIRED',
      message: 'Please provide a valid JWT token or API Key.',
      details: 'Supported headers: Authorization (Bearer), X-API-Key',
    });
  },
];
