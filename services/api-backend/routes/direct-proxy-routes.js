/**
 * Direct Proxy Routes for Free Tier Users
 *
 * Provides direct tunnel access without container orchestration
 * for users on the free tier. Routes requests directly through
 * the existing tunnel proxy system with comprehensive security
 * and error handling.
 *
 * @fileoverview Direct proxy routes for free tier users
 * @version 1.0.0
 * @author CloudToLocalLLM Team
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import {
  addTierInfo,
  shouldUseDirectTunnel,
  getUserTier,
} from '../middleware/tier-check.js';
import { logger } from '../utils/logger.js';

// Configuration constants
const REQUEST_TIMEOUT = parseInt(process.env.DIRECT_PROXY_TIMEOUT) || 30000; // 30 seconds
const MAX_REQUEST_SIZE = parseInt(process.env.MAX_REQUEST_SIZE) || 10485760; // 10MB

const router = express.Router();

/**
 * Create direct proxy routes for free tier users with comprehensive validation
 * @param {Object} tunnelProxy - TunnelProxy instance with forwardRequest method
 * @returns {express.Router} Configured router with security middleware
 * @throws {Error} If tunnelProxy is invalid or missing required methods
 */
export function createDirectProxyRoutes(tunnelProxy) {
  // Comprehensive input validation
  if (!tunnelProxy) {
    throw new Error('TunnelProxy instance is required for direct proxy routes');
  }

  if (typeof tunnelProxy.forwardRequest !== 'function') {
    throw new Error('TunnelProxy instance must have forwardRequest method');
  }

  if (typeof tunnelProxy.isUserConnected !== 'function') {
    throw new Error('TunnelProxy instance must have isUserConnected method');
  }

  /**
   * Health check endpoint for direct proxy with comprehensive status
   */
  router.get('/health', authenticateJWT, addTierInfo, (req, res) => {
    try {
      const userTier = getUserTier(req.user);
      const useDirectTunnel = shouldUseDirectTunnel(req.user);
      const isConnected = tunnelProxy.isUserConnected(req.user.sub);

      const healthStatus = {
        status: 'ok',
        service: 'direct-proxy',
        userTier,
        directTunnelEnabled: useDirectTunnel,
        tunnelConnected: isConnected,
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '1.0.0',
      };

      logger.debug(' [DirectProxy] Health check requested', {
        userId: req.user.sub,
        userTier,
        isConnected,
      });

      res.json(healthStatus);
    } catch (error) {
      logger.error(' [DirectProxy] Health check failed', {
        userId: req.user?.sub,
        error: error.message,
      });

      res.status(500).json({
        status: 'error',
        service: 'direct-proxy',
        error: 'Health check failed',
        timestamp: new Date().toISOString(),
      });
    }
  });

  /**
   * Direct proxy endpoint for Ollama API calls with comprehensive security
   * Routes: /api/direct-proxy/:userId/ollama/*
   */
  router.all('/ollama/*', authenticateJWT, addTierInfo, async (req, res) => {
    const startTime = Date.now();
    const requestId = `dp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    try {
      // Input validation and security checks
      const userId = req.user.sub;
      const userTier = getUserTier(req.user);

      // Verify this is a free tier user (security check)
      if (!shouldUseDirectTunnel(req.user)) {
        logger.warn(
          '� [DirectProxy] Non-free tier user attempted direct proxy access',
          {
            userId,
            userTier,
            endpoint: req.path,
            method: req.method,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            requestId,
          }
        );

        return res.status(403).json({
          error: 'Direct proxy access is only available for free tier users',
          code: 'DIRECT_PROXY_FORBIDDEN',
          userTier,
          suggestion: 'Use container-based proxy for premium features',
          requestId,
        });
      }

      // Check if tunnel is connected
      if (!tunnelProxy.isUserConnected(userId)) {
        logger.warn('� [DirectProxy] Desktop client not connected', {
          userId,
          userTier,
          endpoint: req.path,
          requestId,
        });

        return res.status(503).json({
          error: 'Desktop client not connected',
          code: 'DESKTOP_CLIENT_DISCONNECTED',
          message:
            'Please ensure your CloudToLocalLLM desktop client is running and connected.',
          requestId,
        });
      }

      // Validate request size
      const contentLength = parseInt(req.get('content-length') || '0');
      if (contentLength > MAX_REQUEST_SIZE) {
        logger.warn('� [DirectProxy] Request too large', {
          userId,
          contentLength,
          maxSize: MAX_REQUEST_SIZE,
          requestId,
        });

        return res.status(413).json({
          error: 'Request entity too large',
          code: 'REQUEST_TOO_LARGE',
          maxSize: MAX_REQUEST_SIZE,
          requestId,
        });
      }

      // Extract and validate the Ollama path
      const ollamaPath = req.path.replace('/ollama', '') || '/';

      // Validate path for security (prevent path traversal)
      if (ollamaPath.includes('..') || ollamaPath.includes('//')) {
        logger.warn('� [DirectProxy] Path traversal attempt detected', {
          userId,
          originalPath: req.path,
          ollamaPath,
          requestId,
        });

        return res.status(400).json({
          error: 'Invalid path',
          code: 'INVALID_PATH',
          message: 'Path contains invalid characters',
          requestId,
        });
      }

      // Sanitize headers (remove hop-by-hop and security-sensitive headers)
      const sanitizedHeaders = { ...req.headers };
      const headersToRemove = [
        'host',
        'connection',
        'proxy-connection',
        'proxy-authorization',
        'te',
        'trailers',
        'upgrade',
        'authorization',
        'cookie',
      ];

      headersToRemove.forEach((header) => {
        delete sanitizedHeaders[header];
      });

      // Create HTTP request object for tunnel proxy
      const httpRequest = {
        id: requestId,
        method: req.method,
        path: ollamaPath,
        headers: sanitizedHeaders,
        body:
          req.method !== 'GET' && req.method !== 'HEAD'
            ? JSON.stringify(req.body)
            : undefined,
        query: req.query,
        timeout: REQUEST_TIMEOUT,
      };

      logger.debug(' [DirectProxy] Forwarding request through tunnel', {
        userId,
        userTier,
        method: req.method,
        path: ollamaPath,
        requestId,
        contentLength,
      });

      // Forward request through tunnel proxy with timeout
      const response = await Promise.race([
        tunnelProxy.forwardRequest(userId, httpRequest),
        new Promise((_, reject) =>
          setTimeout(
            () => reject(new Error('Request timeout')),
            REQUEST_TIMEOUT
          )
        ),
      ]);

      // Validate response object
      if (!response || typeof response !== 'object') {
        throw new Error('Invalid response from tunnel proxy');
      }

      // Sanitize response headers (remove security-sensitive headers)
      const sanitizedResponseHeaders = { ...response.headers };
      const responseHeadersToRemove = ['set-cookie', 'server', 'x-powered-by'];
      responseHeadersToRemove.forEach((header) => {
        delete sanitizedResponseHeaders[header];
      });

      // Set response headers safely
      if (sanitizedResponseHeaders) {
        Object.entries(sanitizedResponseHeaders).forEach(([key, value]) => {
          if (value !== undefined && typeof key === 'string') {
            try {
              res.set(key, value);
            } catch (headerError) {
              logger.warn(' [DirectProxy] Invalid response header', {
                userId,
                header: key,
                value,
                error: headerError.message,
                requestId,
              });
            }
          }
        });
      }

      // Validate and set status code
      const statusCode = parseInt(response.statusCode) || 200;
      if (statusCode < 100 || statusCode > 599) {
        logger.warn(' [DirectProxy] Invalid status code, using 200', {
          userId,
          originalStatusCode: response.statusCode,
          requestId,
        });
        res.status(200);
      } else {
        res.status(statusCode);
      }

      // Send response body safely
      if (response.body !== undefined && response.body !== null) {
        if (typeof response.body === 'string') {
          res.send(response.body);
        } else if (typeof response.body === 'object') {
          res.json(response.body);
        } else {
          res.send(String(response.body));
        }
      } else {
        res.end();
      }

      const duration = Date.now() - startTime;
      logger.debug(' [DirectProxy] Request completed successfully', {
        userId,
        userTier,
        method: req.method,
        path: ollamaPath,
        statusCode,
        duration,
        requestId,
      });
    } catch (error) {
      const duration = Date.now() - startTime;
      const userId = req.user?.sub;
      const userTier = getUserTier(req.user);

      logger.error(' [DirectProxy] Request failed', {
        userId,
        userTier,
        method: req.method,
        path: req.path,
        error: error.message,
        code: error.code,
        stack: error.stack,
        duration,
        requestId,
      });

      // Handle specific tunnel errors with appropriate HTTP status codes
      if (
        error.message === 'Request timeout' ||
        error.code === 'REQUEST_TIMEOUT'
      ) {
        return res.status(504).json({
          error: 'Request timeout',
          code: 'REQUEST_TIMEOUT',
          message: 'The request to your local Ollama instance timed out.',
          timeout: REQUEST_TIMEOUT,
          requestId,
        });
      }

      if (
        error.code === 'DESKTOP_CLIENT_DISCONNECTED' ||
        error.message.includes('not connected')
      ) {
        return res.status(503).json({
          error: 'Desktop client not connected',
          code: 'DESKTOP_CLIENT_DISCONNECTED',
          message:
            'Please ensure your CloudToLocalLLM desktop client is running and connected.',
          requestId,
        });
      }

      if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
        return res.status(502).json({
          error: 'Local service unavailable',
          code: 'LOCAL_SERVICE_UNAVAILABLE',
          message: 'Unable to connect to your local Ollama instance.',
          requestId,
        });
      }

      if (
        error.name === 'ValidationError' ||
        error.code === 'INVALID_REQUEST'
      ) {
        return res.status(400).json({
          error: 'Invalid request',
          code: 'INVALID_REQUEST',
          message: 'The request contains invalid data.',
          requestId,
        });
      }

      // Generic error response (don't expose internal details)
      res.status(500).json({
        error: 'Internal proxy error',
        code: 'PROXY_ERROR',
        message: 'An error occurred while forwarding your request.',
        requestId,
      });
    }
  });

  /**
   * Direct proxy endpoint for general API calls
   * Routes: /api/direct-proxy/:userId/api/*
   */
  router.all('/api/*', authenticateJWT, addTierInfo, async (req, res) => {
    const userId = req.user.sub;
    const userTier = getUserTier(req.user);

    // Verify this is a free tier user
    if (!shouldUseDirectTunnel(req.user)) {
      return res.status(403).json({
        error: 'Direct proxy access is only available for free tier users',
        code: 'DIRECT_PROXY_FORBIDDEN',
        userTier,
      });
    }

    try {
      // Extract the API path (everything after /api)
      const apiPath = req.path.replace('/api', '') || '/';

      // Create HTTP request object for tunnel proxy
      const httpRequest = {
        id: `direct-api-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        method: req.method,
        path: apiPath,
        headers: {
          ...req.headers,
          host: undefined,
          connection: undefined,
        },
        body:
          req.method !== 'GET' && req.method !== 'HEAD'
            ? JSON.stringify(req.body)
            : undefined,
        query: req.query,
      };

      logger.debug(' [DirectProxy] Forwarding API request through tunnel', {
        userId,
        userTier,
        method: req.method,
        path: apiPath,
        requestId: httpRequest.id,
      });

      // Forward request through tunnel proxy
      const response = await tunnelProxy.forwardRequest(userId, httpRequest);

      // Set response headers and send response
      if (response.headers) {
        Object.entries(response.headers).forEach(([key, value]) => {
          if (value !== undefined) {
            res.set(key, value);
          }
        });
      }

      res.status(response.statusCode || 200);

      if (response.body) {
        if (typeof response.body === 'string') {
          res.send(response.body);
        } else {
          res.json(response.body);
        }
      } else {
        res.end();
      }
    } catch (error) {
      logger.error(' [DirectProxy] API request failed', {
        userId,
        userTier,
        method: req.method,
        path: req.path,
        error: error.message,
      });

      res.status(500).json({
        error: 'Internal proxy error',
        code: 'PROXY_ERROR',
        message: 'An error occurred while forwarding your API request.',
      });
    }
  });

  /**
   * Catch-all route for unsupported paths
   */
  router.all('*', authenticateJWT, addTierInfo, (req, res) => {
    const userTier = getUserTier(req.user);

    res.status(404).json({
      error: 'Endpoint not found',
      code: 'ENDPOINT_NOT_FOUND',
      userTier,
      availableEndpoints: ['/health', '/ollama/*', '/api/*'],
    });
  });

  return router;
}

export default createDirectProxyRoutes;
