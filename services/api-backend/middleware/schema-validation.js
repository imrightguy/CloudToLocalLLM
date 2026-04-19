/**
 * Schema Validation Middleware using Zod
 *
 * Provides robust input validation using Zod schemas.
 *
 * @fileoverview Zod-based validation middleware
 * @version 1.0.0
 */

import { z } from 'zod';
import logger from '../logger.js';

/**
 * Middleware to validate request data against a Zod schema
 *
 * @param {Object} schemas - Object containing schemas for body, query, and params
 * @param {z.ZodSchema} [schemas.body] - Schema for req.body
 * @param {z.ZodSchema} [schemas.query] - Schema for req.query
 * @param {z.ZodSchema} [schemas.params] - Schema for req.params
 * @returns {Function} Express middleware
 */
export const validateSchema = (schemas) => {
  return async (req, res, next) => {
    try {
      // Validate body
      if (schemas.body && req.body) {
        req.body = await schemas.body.parseAsync(req.body);
      }

      // Validate query
      if (schemas.query && req.query) {
        req.query = await schemas.query.parseAsync(req.query);
      }

      // Validate params
      if (schemas.params && req.params) {
        req.params = await schemas.params.parseAsync(req.params);
      }

      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const issues = error.issues ?? error.errors ?? [];
        const details = issues.map((err) => ({
          path: err.path.join('.'),
          message: err.message,
          code: err.code,
        }));

        const pathToCode = {
          name: 'INVALID_NAME',
          scopes: 'INVALID_SCOPES',
          rateLimit: 'INVALID_RATE_LIMIT',
        };
        const firstPath = issues[0]?.path[0];
        const responseCode =
          pathToCode[firstPath] ?? (issues[0]?.path.length === 0 ? 'INVALID_FIELDS' : 'VALIDATION_ERROR');

        logger.warn('[Validation] Schema validation failed', {
          path: req.path,
          method: req.method,
          errors: details,
          userId: req.user?.sub,
        });

        return res.status(400).json({
          error: 'Validation failed',
          code: responseCode,
          details,
        });
      }

      logger.error('[Validation] Unexpected error during validation', {
        error: error.message,
        stack: error.stack,
      });

      next(error);
    }
  };
};

/**
 * Common validation schemas
 */
export const commonSchemas = {
  uuid: z.string().uuid(),
  email: z.string().email(),
  pagination: z.object({
    page: z
      .string()
      .regex(/^\d+$/)
      .transform(Number)
      .optional()
      .default(1),
    limit: z
      .string()
      .regex(/^\d+$/)
      .transform(Number)
      .optional()
      .default(50),
  }),
};

export default validateSchema;
