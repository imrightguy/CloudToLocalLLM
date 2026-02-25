/**
 * Swagger/OpenAPI Configuration for CloudToLocalLLM API Backend
 *
 * Generates OpenAPI 3.0 specification from JSDoc comments
 * and serves Swagger UI at /api/docs
 *
 * Requirements: 12.1, 12.2, 12.3
 */

// import swaggerJsdoc from 'swagger-jsdoc'; // Temporarily disabled for Node.js v24 compatibility

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'CloudToLocalLLM API Backend',
      version: '2.0.0',
      description:
        'Comprehensive API for CloudToLocalLLM - Bridge cloud AI services with local models',
      contact: {
        name: 'CloudToLocalLLM Team',
        url: 'https://cloudtolocalllm.online',
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT',
      },
    },
    servers: [
      {
        url: 'https://api.cloudtolocalllm.online/v2',
        description: 'Production API Server (v2 - Current)',
      },
      {
        url: 'https://api.cloudtolocalllm.online/v1',
        description: 'Production API Server (v1 - Deprecated)',
      },
      {
        url: 'https://api.cloudtolocalllm.online',
        description: 'Production API Server (defaults to v2)',
      },
      {
        url: 'http://localhost:8080/v2',
        description: 'Development API Server (v2 - Current)',
      },
      {
        url: 'http://localhost:8080/v1',
        description: 'Development API Server (v1 - Deprecated)',
      },
      {
        url: 'http://localhost:8080',
        description: 'Development API Server (defaults to v2)',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'JWT token from JWT',
        },
        apiKeyAuth: {
          type: 'apiKey',
          in: 'header',
          name: 'X-API-Key',
          description: 'API Key for service-to-service communication',
        },
      },
      schemas: {
        RateLimitPolicy: {
          type: 'object',
          properties: {
            tier: {
              type: 'string',
              enum: ['free', 'premium', 'enterprise'],
              description: 'User subscription tier',
            },
            requestsPerMinute: {
              type: 'integer',
              description: 'Maximum requests per minute',
            },
            requestsPerHour: {
              type: 'integer',
              description: 'Maximum requests per hour',
            },
            burstSize: {
              type: 'integer',
              description: 'Maximum burst size (concurrent requests)',
            },
            concurrentConnections: {
              type: 'integer',
              description: 'Maximum concurrent connections',
            },
            exemptEndpoints: {
              type: 'array',
              items: {
                type: 'string',
              },
              description: 'Endpoints exempt from rate limiting',
            },
          },
        },
        RateLimitStatus: {
          type: 'object',
          properties: {
            limit: {
              type: 'integer',
              description: 'Rate limit for the current window',
            },
            remaining: {
              type: 'integer',
              description: 'Remaining requests in current window',
            },
            reset: {
              type: 'integer',
              description: 'Unix timestamp when the rate limit resets',
            },
            retryAfter: {
              type: 'integer',
              description: 'Seconds to wait before retrying (if rate limited)',
            },
          },
        },
        RateLimitViolation: {
          type: 'object',
          properties: {
            violationType: {
              type: 'string',
              enum: ['per_user', 'per_ip', 'burst', 'concurrent'],
              description: 'Type of rate limit violation',
            },
            userId: {
              type: 'string',
              format: 'uuid',
              description: 'User ID (if applicable)',
            },
            ipAddress: {
              type: 'string',
              description: 'IP address that triggered the violation',
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'When the violation occurred',
            },
            endpoint: {
              type: 'string',
              description: 'API endpoint that was rate limited',
            },
          },
        },
        APIVersion: {
          type: 'object',
          properties: {
            version: {
              type: 'string',
              enum: ['v1', 'v2'],
              description: 'API version identifier',
            },
            status: {
              type: 'string',
              enum: ['current', 'deprecated'],
              description: 'Version status',
            },
            description: {
              type: 'string',
              description: 'Version description',
            },
            deprecatedAt: {
              type: 'string',
              format: 'date-time',
              description: 'When this version was deprecated (if applicable)',
            },
            sunsetAt: {
              type: 'string',
              format: 'date-time',
              description: 'When this version will be removed (if deprecated)',
            },
          },
        },
        VersionInfo: {
          type: 'object',
          properties: {
            currentVersion: {
              type: 'string',
              description: 'Current API version being used',
            },
            defaultVersion: {
              type: 'string',
              description: 'Default API version for unversioned requests',
            },
            supportedVersions: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/APIVersion',
              },
              description: 'List of all supported API versions',
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Response timestamp',
            },
          },
        },
        Error: {
          type: 'object',
          properties: {
            error: {
              type: 'object',
              properties: {
                code: {
                  type: 'string',
                  description: 'Error code identifier',
                },
                message: {
                  type: 'string',
                  description: 'Human-readable error message',
                },
                category: {
                  type: 'string',
                  enum: [
                    'validation',
                    'authentication',
                    'authorization',
                    'not_found',
                    'rate_limit',
                    'server',
                    'service_unavailable',
                  ],
                  description: 'Error category',
                },
                statusCode: {
                  type: 'integer',
                  description: 'HTTP status code',
                },
                correlationId: {
                  type: 'string',
                  description: 'Request correlation ID for tracing',
                },
                suggestion: {
                  type: 'string',
                  description: 'Suggested action to resolve the error',
                },
              },
              required: ['code', 'message', 'statusCode'],
            },
          },
        },
        User: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              format: 'uuid',
              description: 'User unique identifier',
            },
            email: {
              type: 'string',
              format: 'email',
              description: 'User email address',
            },
            tier: {
              type: 'string',
              enum: ['free', 'premium', 'enterprise'],
              description: 'User subscription tier',
            },
            profile: {
              type: 'object',
              properties: {
                firstName: {
                  type: 'string',
                },
                lastName: {
                  type: 'string',
                },
                avatar: {
                  type: 'string',
                  format: 'uri',
                },
              },
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
            },
            updatedAt: {
              type: 'string',
              format: 'date-time',
            },
          },
        },
        Tunnel: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              format: 'uuid',
              description: 'Tunnel unique identifier',
            },
            userId: {
              type: 'string',
              format: 'uuid',
              description: 'Owner user ID',
            },
            name: {
              type: 'string',
              description: 'Tunnel name',
            },
            status: {
              type: 'string',
              enum: [
                'created',
                'connecting',
                'connected',
                'disconnected',
                'error',
              ],
              description: 'Current tunnel status',
            },
            endpoints: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  id: {
                    type: 'string',
                  },
                  url: {
                    type: 'string',
                    format: 'uri',
                  },
                  priority: {
                    type: 'integer',
                  },
                  healthStatus: {
                    type: 'string',
                    enum: ['healthy', 'unhealthy', 'unknown'],
                  },
                },
              },
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
            },
            updatedAt: {
              type: 'string',
              format: 'date-time',
            },
          },
        },
        HealthStatus: {
          type: 'object',
          properties: {
            status: {
              type: 'string',
              enum: ['healthy', 'degraded', 'error'],
              description: 'Overall health status',
            },
            database: {
              type: 'string',
              enum: ['healthy', 'degraded', 'error'],
              description: 'Database health status',
            },
            cache: {
              type: 'string',
              enum: ['healthy', 'degraded', 'error'],
              description: 'Cache health status',
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
            },
          },
        },
      },
      responses: {
        UnauthorizedError: {
          description: 'Authentication required',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error',
              },
            },
          },
        },
        ForbiddenError: {
          description: 'Insufficient permissions',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error',
              },
            },
          },
        },
        NotFoundError: {
          description: 'Resource not found',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error',
              },
            },
          },
        },
        RateLimitError: {
          description: 'Rate limit exceeded',
          headers: {
            'X-RateLimit-Limit': {
              schema: {
                type: 'integer',
              },
              description: 'Rate limit for the current window',
            },
            'X-RateLimit-Remaining': {
              schema: {
                type: 'integer',
              },
              description: 'Remaining requests in current window',
            },
            'X-RateLimit-Reset': {
              schema: {
                type: 'integer',
              },
              description: 'Unix timestamp when the rate limit resets',
            },
            'Retry-After': {
              schema: {
                type: 'integer',
              },
              description: 'Seconds to wait before retrying',
            },
          },
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error',
              },
            },
          },
        },
        ServerError: {
          description: 'Internal server error',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error',
              },
            },
          },
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: [
    './routes/auth.js',
    './routes/users.js',
    './routes/user-profile.js',
    './routes/sessions.js',
    './routes/tunnels.js',
    './routes/tunnel-health.js',
    './routes/tunnel-failover.js',
    './routes/tunnel-sharing.js',
    './routes/tunnel-usage.js',
    './routes/tunnel-webhooks.js',
    './routes/proxy-health.js',
    './routes/proxy-config.js',
    './routes/proxy-scaling.js',
    './routes/proxy-metrics.js',
    './routes/proxy-diagnostics.js',
    './routes/proxy-failover.js',
    './routes/proxy-usage.js',
    './routes/proxy-webhooks.js',
    './routes/admin.js',
    './routes/admin/users.js',
    './routes/admin/subscriptions.js',
    './routes/webhooks.js',
    './routes/webhook-event-filters.js',
    './routes/webhook-payload-transformations.js',
    './routes/webhook-rate-limiting.js',
    './routes/webhook-testing.js',
    './routes/api-keys.js',
    './routes/rate-limit-metrics.js',
    './routes/prometheus-metrics.js',
    './routes/db-health.js',
    './routes/database-performance.js',
    './routes/backup-recovery.js',
    './routes/failover.js',
    './routes/cache-metrics.js',
    './routes/error-recovery.js',
    './routes/alert-configuration.js',
  ],
};

let specs;
// Temporarily disable swagger generation to fix Node.js v24 compatibility
// TODO: Re-enable once swagger-jsdoc is compatible with Node.js v24
specs = {
  openapi: '3.0.0',
  info: options.definition.info,
  paths: {},
};

export { specs };
