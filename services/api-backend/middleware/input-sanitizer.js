/**
 * Input Sanitization Middleware
 *
 * Provides comprehensive input sanitization to prevent:
 * - SQL injection attacks
 * - XSS (Cross-Site Scripting) attacks
 * - NoSQL injection attacks
 * - Command injection attacks
 *
 * Requirement 15: Security and Data Protection
 */

import validator from 'validator';

/**
 * Sanitize string input to prevent XSS attacks
 * @param {string} input - The input string to sanitize
 * @returns {string} - Sanitized string
 */
export function sanitizeString(input) {
  if (typeof input !== 'string') {
    return input;
  }

  // Escape HTML entities to prevent XSS
  let sanitized = validator.escape(input);

  // Remove any potential script tags
  sanitized = sanitized.replace(
    /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
    ''
  );

  // Remove any potential event handlers
  sanitized = sanitized.replace(/on\w+\s*=\s*["'][^"']*["']/gi, '');

  // Remove javascript: protocol
  sanitized = sanitized.replace(/javascript:/gi, '');

  return sanitized;
}

/**
 * Sanitize email input
 * @param {string} email - The email to sanitize
 * @returns {string|null} - Sanitized email or null if invalid
 */
export function sanitizeEmail(email) {
  if (typeof email !== 'string') {
    return null;
  }

  const normalized = validator.normalizeEmail(email);
  return validator.isEmail(normalized) ? normalized : null;
}

/**
 * Sanitize numeric input
 * @param {any} input - The input to sanitize as number
 * @param {object} options - Validation options
 * @returns {number|null} - Sanitized number or null if invalid
 */
export function sanitizeNumber(input, options = {}) {
  const { min, max, allowFloat = false } = options;

  const num = allowFloat ? parseFloat(input) : parseInt(input, 10);

  if (isNaN(num)) {
    return null;
  }

  if (min !== undefined && num < min) {
    return null;
  }

  if (max !== undefined && num > max) {
    return null;
  }

  return num;
}

/**
 * Sanitize UUID input
 * @param {string} uuid - The UUID to sanitize
 * @returns {string|null} - Sanitized UUID or null if invalid
 */
export function sanitizeUUID(uuid) {
  if (typeof uuid !== 'string') {
    return null;
  }

  return validator.isUUID(uuid) ? uuid : null;
}

/**
 * Sanitize date input
 * @param {string} date - The date string to sanitize
 * @returns {Date|null} - Sanitized Date object or null if invalid
 */
export function sanitizeDate(date) {
  if (!date) {
    return null;
  }

  const parsed = new Date(date);
  return isNaN(parsed.getTime()) ? null : parsed;
}

/**
 * Sanitize enum value
 * @param {string} value - The value to check
 * @param {Array} allowedValues - Array of allowed values
 * @returns {string|null} - Value if valid, null otherwise
 */
export function sanitizeEnum(value, allowedValues) {
  if (!allowedValues || !Array.isArray(allowedValues)) {
    return null;
  }

  return allowedValues.includes(value) ? value : null;
}

/**
 * Sanitize object recursively
 * @param {object} obj - The object to sanitize
 * @param {number} depth - Current recursion depth
 * @param {number} maxDepth - Maximum recursion depth
 * @returns {object} - Sanitized object
 */
export function sanitizeObject(obj, depth = 0, maxDepth = 10) {
  if (depth > maxDepth) {
    return {};
  }

  if (obj === null || obj === undefined) {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => {
      if (typeof item === 'object') {
        return sanitizeObject(item, depth + 1, maxDepth);
      }
      if (typeof item === 'string') {
        return sanitizeString(item);
      }
      return item;
    });
  }

  if (typeof obj === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      // Sanitize the key
      const sanitizedKey = sanitizeString(key);

      // Sanitize the value based on type
      if (typeof value === 'string') {
        sanitized[sanitizedKey] = sanitizeString(value);
      } else if (typeof value === 'object') {
        sanitized[sanitizedKey] = sanitizeObject(value, depth + 1, maxDepth);
      } else {
        sanitized[sanitizedKey] = value;
      }
    }
    return sanitized;
  }

  return obj;
}

/**
 * Validate and sanitize pagination parameters
 * @param {object} query - Query parameters
 * @returns {object} - Sanitized pagination parameters
 */
export function sanitizePagination(query) {
  const page = sanitizeNumber(query.page, { min: 1 }) || 1;
  const limit = sanitizeNumber(query.limit, { min: 1, max: 200 }) || 50;
  const offset = (page - 1) * limit;

  return { page, limit, offset };
}

/**
 * Sanitize SQL LIKE pattern to prevent SQL injection
 * @param {string} pattern - The search pattern
 * @returns {string} - Sanitized pattern
 */
export function sanitizeLikePattern(pattern) {
  if (typeof pattern !== 'string') {
    return '';
  }

  // Escape special SQL LIKE characters
  let sanitized = pattern
    .replace(/\\/g, '\\\\') // Escape backslash
    .replace(/%/g, '\\%') // Escape percent
    .replace(/_/g, '\\_') // Escape underscore
    .replace(/'/g, "''"); // Escape single quote

  // Remove any potential SQL injection attempts
  sanitized = sanitized.replace(/;/g, '');
  sanitized = sanitized.replace(/--/g, '');
  sanitized = sanitized.replace(/\/\*/g, '');
  sanitized = sanitized.replace(/\*\//g, '');

  return sanitized;
}

/**
 * Express middleware to sanitize request body
 */
export function sanitizeBody(req, res, next) {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeObject(req.body);
  }
  next();
}

/**
 * Express middleware to sanitize query parameters
 */
export function sanitizeQuery(req, res, next) {
  if (req.query && typeof req.query === 'object') {
    req.query = sanitizeObject(req.query);
  }
  next();
}

/**
 * Express middleware to sanitize URL parameters
 */
export function sanitizeParams(req, res, next) {
  if (req.params && typeof req.params === 'object') {
    req.params = sanitizeObject(req.params);
  }
  next();
}

/**
 * Combined sanitization middleware for all request inputs
 */
export function sanitizeAll(req, res, next) {
  sanitizeBody(req, res, () => {
    sanitizeQuery(req, res, () => {
      sanitizeParams(req, res, next);
    });
  });
}

/**
 * Validate and sanitize admin-specific inputs
 */
export function sanitizeAdminInput(req, res, next) {
  // Sanitize all inputs first
  sanitizeAll(req, res, () => {
    // Additional admin-specific validation
    if (req.body) {
      // Sanitize email if present
      if (req.body.email) {
        const sanitizedEmail = sanitizeEmail(req.body.email);
        if (!sanitizedEmail) {
          return res.status(400).json({
            error: 'Invalid email format',
            code: 'INVALID_EMAIL',
          });
        }
        req.body.email = sanitizedEmail;
      }

      // Sanitize amount if present (for payments/refunds)
      if (req.body.amount !== undefined) {
        const sanitizedAmount = sanitizeNumber(req.body.amount, {
          min: 0,
          allowFloat: true,
        });
        if (sanitizedAmount === null) {
          return res.status(400).json({
            error: 'Invalid amount',
            code: 'INVALID_AMOUNT',
          });
        }
        req.body.amount = sanitizedAmount;
      }

      // Sanitize UUIDs if present
      const uuidFields = [
        'userId',
        'transactionId',
        'subscriptionId',
        'adminUserId',
      ];
      for (const field of uuidFields) {
        if (req.body[field]) {
          const sanitizedUUID = sanitizeUUID(req.body[field]);
          if (!sanitizedUUID) {
            return res.status(400).json({
              error: `Invalid ${field} format`,
              code: 'INVALID_UUID',
            });
          }
          req.body[field] = sanitizedUUID;
        }
      }

      // Sanitize dates if present
      const dateFields = ['startDate', 'endDate', 'start_date', 'end_date'];
      for (const field of dateFields) {
        if (req.body[field]) {
          const sanitizedDate = sanitizeDate(req.body[field]);
          if (!sanitizedDate) {
            return res.status(400).json({
              error: `Invalid ${field} format`,
              code: 'INVALID_DATE',
            });
          }
          req.body[field] = sanitizedDate.toISOString();
        }
      }
    }

    // Sanitize query parameters
    if (req.query) {
      // Sanitize search query
      if (req.query.search) {
        req.query.search = sanitizeLikePattern(req.query.search);
      }

      // Sanitize pagination
      if (req.query.page || req.query.limit) {
        const { page, limit, offset } = sanitizePagination(req.query);
        req.query.page = page;
        req.query.limit = limit;
        req.query.offset = offset;
      }
    }

    next();
  });
}

export default {
  sanitizeString,
  sanitizeEmail,
  sanitizeNumber,
  sanitizeUUID,
  sanitizeDate,
  sanitizeEnum,
  sanitizeObject,
  sanitizePagination,
  sanitizeLikePattern,
  sanitizeBody,
  sanitizeQuery,
  sanitizeParams,
  sanitizeAll,
  sanitizeAdminInput,
};
