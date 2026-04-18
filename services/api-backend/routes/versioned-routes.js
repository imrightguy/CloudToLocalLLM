/**
 * Versioned Routes Factory
 *
 * Creates version-specific route handlers with backward compatibility.
 * Demonstrates how to implement versioned endpoints.
 *
 * Requirements: 12.4
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';

/**
 * Create versioned health check endpoint
 * Shows how to implement version-specific handlers
 *
 * @param {string} version - API version (v1, v2, etc.)
 * @returns {Function} Express middleware
 */
export function createVersionedHealthCheck(version) {
  return (req, res) => {
    const baseResponse = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'cloudtolocalllm-api',
    };

    if (version === 'v1') {
      // v1 response format (legacy)
      return res.json({
        ...baseResponse,
        version: 'v1',
        // v1-specific fields
        uptime: process.uptime(),
      });
    }

    // v2 response format (current)
    return res.json({
      ...baseResponse,
      version: 'v2',
      // v2-specific fields
      uptime: process.uptime(),
      dependencies: {
        database: 'healthy',
        cache: 'healthy',
      },
    });
  };
}

/**
 * Create versioned user endpoint
 * Demonstrates version-specific response formats
 *
 * @param {string} version - API version
 * @returns {Function} Express middleware
 */
export function createVersionedUserEndpoint(version) {
  return (req, res) => {
    // Mock user data
    const user = {
      id: '123',
      email: 'user@example.com',
      tier: 'premium',
      createdAt: new Date().toISOString(),
    };

    if (version === 'v1') {
      // v1 response format (legacy)
      return res.json({
        success: true,
        data: {
          ...user,
          // v1-specific field names
          userId: user.id,
          userEmail: user.email,
          userTier: user.tier,
        },
      });
    }

    // v2 response format (current)
    return res.json({
      user: {
        ...user,
        profile: {
          firstName: 'John',
          lastName: 'Doe',
        },
      },
    });
  };
}

/**
 * Create versioned error response
 * Demonstrates version-specific error formats
 *
 * @param {string} version - API version
 * @param {Object} error - Error object
 * @returns {Object} Formatted error response
 */
export function createVersionedErrorResponse(version, error) {
  if (version === 'v1') {
    // v1 error format (legacy)
    return {
      success: false,
      error: error.message,
      errorCode: error.code,
    };
  }

  // v2 error format (current)
  return {
    error: {
      code: error.code,
      message: error.message,
      statusCode: error.statusCode,
      suggestion: error.suggestion,
    },
  };
}

/**
 * Create versioned router factory
 * Returns a function that creates version-specific routers
 *
 * @returns {Function} Router factory function
 */
export function createVersionedRouterFactory() {
  return (version) => {
    const router = express.Router();
    router.use(authenticateJWT);
    router.get('/health', createVersionedHealthCheck(version));

    // User endpoint
    router.get('/user/:id', createVersionedUserEndpoint(version));

    return router;
  };
}

/**
 * Create version-aware middleware
 * Applies version-specific transformations
 *
 * @returns {Function} Express middleware
 */
export function createVersionAwareMiddleware() {
  return (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json to add version info
    res.json = function (data) {
      // Add version metadata to response
      if (typeof data === 'object' && data !== null && !Array.isArray(data)) {
        data._meta = {
          apiVersion: req.apiVersion,
          timestamp: new Date().toISOString(),
        };
      }

      return originalJson.call(this, data);
    };

    next();
  };
}

export default {
  createVersionedHealthCheck,
  createVersionedUserEndpoint,
  createVersionedErrorResponse,
  createVersionedRouterFactory,
  createVersionAwareMiddleware,
};
