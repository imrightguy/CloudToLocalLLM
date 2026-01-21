/**
 * CORS Configuration Middleware
 *
 * Provides secure CORS configuration for the API:
 * - Restricts origins to specific domains (no wildcards)
 * - Requires credentials for admin endpoints
 * - Configures allowed methods and headers
 *
 * Requirement 15: Security and Data Protection
 */

import cors from 'cors';

/**
 * Allowed origins for CORS
 * No wildcards allowed for security
 */
const ALLOWED_ORIGINS = [
  'https://app.cloudtolocalllm.online',
  'https://cloudtolocalllm.online',
  'https://docs.cloudtolocalllm.online',
  'https://admin.cloudtolocalllm.online',
  'https://api.cloudtolocalllm.online',
  // Development origins
  ...(process.env.NODE_ENV === 'development'
    ? [
        'http://localhost:3000',
        'http://localhost:8080',
        'http://localhost:5000',
        'http://127.0.0.1:3000',
        'http://127.0.0.1:8080',
        'http://127.0.0.1:5000',
      ]
    : []),
];

/**
 * Additional allowed origins from environment variable
 * Format: comma-separated list of origins
 * Example: ADDITIONAL_CORS_ORIGINS=https://staging.example.com,https://test.example.com
 */
if (process.env.ADDITIONAL_CORS_ORIGINS) {
  const additionalOrigins = process.env.ADDITIONAL_CORS_ORIGINS.split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  ALLOWED_ORIGINS.push(...additionalOrigins);
}

/**
 * CORS origin validation function
 * @param {string} origin - The origin to validate
 * @param {Function} callback - Callback function
 */
function corsOriginValidator(origin, callback) {
  // Allow requests with no origin (like mobile apps or curl requests)
  if (!origin) {
    return callback(null, true);
  }

  // Check if origin is in allowed list
  if (ALLOWED_ORIGINS.includes(origin)) {
    callback(null, true);
  } else {
    // Log unauthorized CORS attempt
    console.warn(`CORS: Blocked request from unauthorized origin: ${origin}`);
    callback(new Error('Not allowed by CORS'));
  }
}

/**
 * Standard CORS configuration for public endpoints
 */
export const standardCorsOptions = {
  origin: corsOriginValidator,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Accept',
    'Origin',
  ],
  exposedHeaders: [
    'Content-Length',
    'Content-Type',
    'X-RateLimit-Limit',
    'X-RateLimit-Remaining',
    'X-RateLimit-Reset',
  ],
  maxAge: 86400, // 24 hours
  optionsSuccessStatus: 204,
};

/**
 * Strict CORS configuration for admin endpoints
 * Requires credentials and restricts to admin domain only
 */
export const adminCorsOptions = {
  origin: (origin, callback) => {
    // Admin endpoints require origin
    if (!origin) {
      return callback(new Error('Origin required for admin endpoints'));
    }

    // Only allow admin domain and development origins
    const adminOrigins = [
      'https://admin.cloudtolocalllm.online',
      'https://app.cloudtolocalllm.online', // Admin center accessed from main app
      ...(process.env.NODE_ENV === 'development'
        ? [
            'http://localhost:3000',
            'http://localhost:8080',
            'http://127.0.0.1:3000',
            'http://127.0.0.1:8080',
          ]
        : []),
    ];

    if (adminOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.warn(
        `CORS: Blocked admin request from unauthorized origin: ${origin}`
      );
      callback(new Error('Not allowed by CORS - admin access only'));
    }
  },
  credentials: true, // Required for admin endpoints
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Accept',
    'Origin',
  ],
  exposedHeaders: [
    'Content-Length',
    'Content-Type',
    'X-RateLimit-Limit',
    'X-RateLimit-Remaining',
    'X-RateLimit-Reset',
  ],
  maxAge: 3600, // 1 hour (shorter for admin endpoints)
  optionsSuccessStatus: 204,
};

/**
 * Webhook CORS configuration
 * More restrictive - only allows POST from specific origins
 */
export const webhookCorsOptions = {
  origin: (origin, callback) => {
    // Webhooks from payment providers may not have origin
    // Allow requests without origin for webhook endpoints
    if (!origin) {
      return callback(null, true);
    }

    // If origin is present, validate it
    const webhookOrigins = [
      'https://api.stripe.com',
      'https://hooks.stripe.com',
      ...(process.env.NODE_ENV === 'development'
        ? ['http://localhost:3000', 'http://localhost:8080']
        : []),
    ];

    if (webhookOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.warn(
        `CORS: Blocked webhook request from unauthorized origin: ${origin}`
      );
      callback(new Error('Not allowed by CORS - webhook access only'));
    }
  },
  credentials: false, // Webhooks don't need credentials
  methods: ['POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Stripe-Signature', 'X-Stripe-Signature'],
  maxAge: 3600,
  optionsSuccessStatus: 204,
};

/**
 * Create CORS middleware with standard options
 */
export const standardCors = cors(standardCorsOptions);

/**
 * Create CORS middleware with admin options
 */
export const adminCors = cors(adminCorsOptions);

/**
 * Create CORS middleware with webhook options
 */
export const webhookCors = cors(webhookCorsOptions);

/**
 * Get list of allowed origins (for logging/debugging)
 */
export function getAllowedOrigins() {
  return [...ALLOWED_ORIGINS];
}

/**
 * Check if an origin is allowed
 * @param {string} origin - The origin to check
 * @returns {boolean} - True if allowed
 */
export function isOriginAllowed(origin) {
  return ALLOWED_ORIGINS.includes(origin);
}

/**
 * Middleware to log CORS requests
 */
export function logCorsRequest(req, res, next) {
  const origin = req.headers.origin;
  if (origin) {
    const allowed = isOriginAllowed(origin);
    console.log(
      `CORS Request: ${req.method} ${req.path} from ${origin} - ${allowed ? 'ALLOWED' : 'BLOCKED'}`
    );
  }
  next();
}

export default {
  standardCors,
  adminCors,
  webhookCors,
  standardCorsOptions,
  adminCorsOptions,
  webhookCorsOptions,
  getAllowedOrigins,
  isOriginAllowed,
  logCorsRequest,
};
