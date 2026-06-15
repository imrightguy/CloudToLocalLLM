/**
 * Standardized API response utilities
 */

/**
 * Success response wrapper
 * @param {Object} options - Response options
 * @param {any} options.data - Response data
 * @param {string} options.message - Success message
 * @param {Object} options.metadata - Response metadata (pagination, etc.)
 * @returns {Object} Formatted success response
 */
const successResponse = ({ data, message = 'Operation successful', metadata = null }) => {
  const response = {
    success: true,
    data,
    message,
  };

  if (metadata) {
    response.metadata = metadata;
  }

  return response;
};

/**
 * Error response wrapper
 * @param {Object} options - Error options
 * @param {string} options.message - Error message
 * @param {string} options.code - Error code
 * @param {any} options.details - Additional error details
 * @param {number} options.statusCode - HTTP status code
 * @returns {Object} Formatted error response
 */
const errorResponse = ({
  message, code = 'INTERNAL_ERROR', details = null, statusCode: _statusCode = 500,
}) => {
  const response = {
    success: false,
    error: {
      message,
      code,
      details,
    },
  };

  return response;
};

/**
 * Pagination metadata generator
 * @param {Object} options - Pagination options
 * @param {number} options.total - Total items
 * @param {number} options.page - Current page
 * @param {number} options.limit - Items per page
 * @returns {Object} Pagination metadata
 */
const generatePaginationMetadata = ({ total, page = 1, limit = 20 }) => {
  const totalPages = Math.ceil(total / limit);

  return {
    total,
    page,
    limit,
    totalPages,
    hasNext: page < totalPages,
    hasPrev: page > 1,
    offset: (page - 1) * limit,
  };
};

/**
 * Filter validation helper
 * @param {Object} req - Express request object
 * @param {Array} allowedFilters - Array of allowed filter fields
 * @returns {Object} Validated filters
 */
const validateFilters = (req, allowedFilters) => {
  const { filters = {} } = req.query;
  const validFilters = {};

  Object.keys(filters).forEach((key) => {
    if (allowedFilters.includes(key)) {
      validFilters[key] = filters[key];
    }
  });

  return validFilters;
};

/**
 * Sort helper for query ordering
 * @param {Object} queryBuilder - Knex query builder
 * @param {string} sortBy - Field to sort by
 * @param {string} sortOrder - Sort order (asc/desc)
 * @param {Array} allowedSortFields - Array of allowed sort fields
 * @returns {Object} Updated query builder
 */
const addSort = (queryBuilder, sortBy = 'createdAt', sortOrder = 'asc', allowedSortFields = []) => {
  const validSortField = allowedSortFields.includes(sortBy) ? sortBy : 'createdAt';
  const validSortOrder = ['asc', 'desc'].includes(sortOrder) ? sortOrder : 'asc';

  return queryBuilder.orderBy(validSortField, validSortOrder);
};

/**
 * Pagination helper for query execution
 * @param {Object} options - Pagination options
 * @param {number} options.page - Page number
 * @param {number} options.limit - Items per page
 * @returns {Object} Pagination config
 */
const getPagination = (page = 1, limit = 20) => {
  const validPage = Math.max(1, parseInt(page));
  const validLimit = Math.min(100, Math.max(1, parseInt(limit)));

  return {
    offset: (validPage - 1) * validLimit,
    limit: validLimit,
  };
};

/**
 * Error handling middleware
 * @param {Error} error - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
const errorHandler = (error, req, res, _next) => {
  const logger = require('./logger');
  const isProduction = process.env.NODE_ENV === 'production';

  logger.error(error.message, {
    stack: error.stack,
    method: req.method,
    path: req.path,
    statusCode: error.statusCode,
    code: error.code,
    isOperational: error.isOperational,
  });

  // Handle AppError (operational errors with known status codes)
  if (error.name === 'AppError') {
    const response = {
      success: false,
      error: {
        message: error.message,
        code: error.code,
      },
    };
    if (error.details) {
      response.error.details = error.details;
    }
    return res.status(error.statusCode).json(response);
  }

  // Handle validation errors
  if (error.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: {
        message: error.message,
        code: 'VALIDATION_ERROR',
        details: error.details,
      },
    });
  }

  // Handle database errors
  if (error.code === '23505') {
    return res.status(409).json({
      success: false,
      error: { message: 'Duplicate entry', code: 'DUPLICATE_ENTRY' },
    });
  }

  if (error.code === '23503') {
    return res.status(400).json({
      success: false,
      error: { message: 'Foreign key constraint violation', code: 'FOREIGN_KEY_VIOLATION' },
    });
  }

  // Handle authentication errors
  if (error.name === 'UnauthorizedError') {
    return res.status(401).json({
      success: false,
      error: { message: 'Unauthorized access', code: 'UNAUTHORIZED' },
    });
  }

  // Handle not found errors
  if (error.message?.includes('not found')) {
    return res.status(404).json({
      success: false,
      error: { message: error.message || 'Resource not found', code: 'NOT_FOUND' },
    });
  }

  // Handle file upload errors
  if (error.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      success: false,
      error: { message: 'File size exceeds limit', code: 'FILE_SIZE_EXCEEDED' },
    });
  }

  // Handle rate limiting
  if (error.message?.includes('too many requests')) {
    return res.status(429).json({
      success: false,
      error: { message: 'Too many requests', code: 'RATE_LIMIT_EXCEEDED' },
    });
  }

  // Handle JSON parse errors (malformed request body)
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      error: { message: 'Malformed JSON in request body', code: 'INVALID_JSON' },
    });
  }

  // Handle payload too large
  if (error.type === 'entity.too.large') {
    return res.status(413).json({
      success: false,
      error: { message: 'Request payload too large', code: 'PAYLOAD_TOO_LARGE' },
    });
  }

  // Handle unhandled operational errors with statusCode
  if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
    return res.status(error.statusCode).json({
      success: false,
      error: {
        message: error.message,
        code: error.code || 'CLIENT_ERROR',
      },
    });
  }

  // All other errors: return generic message, hide details in production
  const response = {
    success: false,
    error: {
      message: isProduction ? 'Internal server error' : (error.message || 'Internal server error'),
      code: 'INTERNAL_ERROR',
    },
  };

  if (!isProduction) {
    response.error.stack = error.stack;
  }

  res.status(error.statusCode || 500).json(response);
};

/**
 * Async error wrapper for route handlers
 * @param {Function} fn - Async function to wrap
 * @returns {Function} Express middleware function
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

/**
 * Cache response headers
 * @param {Object} res - Express response object
 * @param {Object} options - Cache options
 */
const setCacheHeaders = (res, options = {}) => {
  const {
    maxAge = 3600, // 1 hour default
    mustRevalidate = false,
    isPrivate = false,
    noStore = false, // dynamic data: opt out of caching entirely
  } = options;

  // no-store and max-age are mutually exclusive: pick one based on context.
  const directives = noStore
    ? ['no-store', 'no-cache', 'must-revalidate']
    : [
      `max-age=${maxAge}`,
      isPrivate ? 'private' : 'public',
      mustRevalidate ? 'must-revalidate' : '',
    ];

  res.set('Cache-Control', directives.filter(Boolean).join(', '));
};

/**
 CORS headers helper
 * @param {Object} res - Express response object
 * @param {Object} options - CORS options
 */
const setCORSHeaders = (res, options = {}) => {
  // Default to the configured allow-list (first origin) rather than '*' to avoid an
  // accidental wildcard. Callers may still pass an explicit origin.
  const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
    : [];
  const {
    origin = allowedOrigins[0] || 'null',
    methods = 'GET, POST, PUT, DELETE, PATCH',
    headers = 'Content-Type, Authorization, X-Requested-With',
    credentials = false,
    maxAge = 86400,
  } = options;

  res.set('Access-Control-Allow-Origin', origin);
  res.set('Access-Control-Allow-Methods', methods);
  res.set('Access-Control-Allow-Headers', headers);

  if (credentials) {
    res.set('Access-Control-Allow-Credentials', 'true');
  }

  res.set('Access-Control-Max-Age', maxAge);
};

module.exports = {
  successResponse,
  errorResponse,
  generatePaginationMetadata,
  validateFilters,
  addSort,
  getPagination,
  errorHandler,
  asyncHandler,
  setCacheHeaders,
  setCORSHeaders,
};
