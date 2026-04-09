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
const errorResponse = ({ message, code = 'INTERNAL_ERROR', details = null, statusCode: _statusCode = 500 }) => {
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

  Object.keys(filters).forEach(key => {
    if (allowedFilters.includes(key)) {
      validFilters[key] = filters[key];
    }
  });

  return validFilters;
};

/**
 * Search helper for text searches
 * @param {Object} queryBuilder - Knex query builder
 * @param {string} search - Search term
 * @param {Array} searchFields - Array of fields to search in
 * @returns {Object} Updated query builder
 */
const addSearch = (queryBuilder, search, searchFields) => {
  if (!search) return queryBuilder;

  const searchTerm = `%${search.toLowerCase()}%`;
  const searchConditions = searchFields.map(field =>
    `LOWER(${field}) LIKE LOWER(${queryBuilder.client ? '?' : '?'})`);

  return queryBuilder.whereRaw(
    searchConditions.join(' OR '),
    Array(searchConditions.length).fill(searchTerm),
  );
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
  logger.error(error.message, {
    stack: error.stack,
    method: req.method,
    path: req.path,
    statusCode: error.statusCode,
  });

  // Default error response
  let response = {
    success: false,
    error: {
      message: 'Internal server error',
      code: 'INTERNAL_ERROR',
    },
  };

  // Handle validation errors
  if (error.name === 'ValidationError') {
    response = {
      success: false,
      error: {
        message: error.message,
        code: 'VALIDATION_ERROR',
        details: error.details,
      },
    };
    return res.status(400).json(response);
  }

  // Handle database errors
  if (error.code === '23505') {
    response = {
      success: false,
      error: {
        message: 'Duplicate entry',
        code: 'DUPLICATE_ENTRY',
      },
    };
    return res.status(409).json(response);
  }

  if (error.code === '23503') {
    response = {
      success: false,
      error: {
        message: 'Foreign key constraint violation',
        code: 'FOREIGN_KEY_VIOLATION',
      },
    };
    return res.status(400).json(response);
  }

  // Handle authentication errors
  if (error.name === 'UnauthorizedError') {
    response = {
      success: false,
      error: {
        message: 'Unauthorized access',
        code: 'UNAUTHORIZED',
      },
    };
    return res.status(401).json(response);
  }

  // Handle not found errors
  if (error.message?.includes('not found')) {
    response = {
      success: false,
      error: {
        message: error.message || 'Resource not found',
        code: 'NOT_FOUND',
      },
    };
    return res.status(404).json(response);
  }

  // Handle file upload errors
  if (error.code === 'LIMIT_FILE_SIZE') {
    response = {
      success: false,
      error: {
        message: 'File size exceeds limit',
        code: 'FILE_SIZE_EXCEEDED',
      },
    };
    return res.status(413).json(response);
  }

  // Handle rate limiting
  if (error.message?.includes('too many requests')) {
    response = {
      success: false,
      error: {
        message: 'Too many requests',
        code: 'RATE_LIMIT_EXCEEDED',
      },
    };
    return res.status(429).json(response);
  }

  // Handle other errors
  res.status(error.statusCode || 500).json(response);
};

/**
 * Async error wrapper for route handlers
 * @param {Function} fn - Async function to wrap
 * @returns {Function} Express middleware function
 */
const asyncHandler = fn => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
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
  } = options;

  res.set('Cache-Control', [
    `max-age=${maxAge}`,
    isPrivate ? 'private' : 'public',
    mustRevalidate ? 'must-revalidate' : '',
    'no-cache',
    'no-store',
  ].filter(Boolean).join(', '));
};

/**
 CORS headers helper
 * @param {Object} res - Express response object
 * @param {Object} options - CORS options
 */
const setCORSHeaders = (res, options = {}) => {
  const {
    origin = '*',
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
  addSearch,
  addSort,
  getPagination,
  errorHandler,
  asyncHandler,
  setCacheHeaders,
  setCORSHeaders,
};
