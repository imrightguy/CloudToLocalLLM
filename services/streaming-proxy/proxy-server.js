import http from 'http';
import https from 'https';
import winston from 'winston';
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'development',
  release: process.env.VERSION || process.env.npm_package_version,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  serverName: process.env.HOSTNAME || process.env.PROXY_ID || 'streaming-proxy',
  beforeSend(event) {
    // Add custom tags
    if (event.tags) {
      event.tags.service = 'streaming-proxy';
      event.tags.userId = process.env.USER_ID || 'unknown';
      event.tags.proxyId = process.env.PROXY_ID || 'unknown';
    }
    return event;
  },
});

// Configuration from environment variables
const PORT = process.env.PORT || 3001;
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const USER_ID = process.env.USER_ID; // Injected by container orchestrator
const PROXY_ID = process.env.PROXY_ID; // Unique proxy identifier
const OLLAMA_BASE_URL = process.env.OLLAMA_BASE_URL; // Tunnel proxy endpoint

// Initialize logger for simplified container
const logger = winston.createLogger({
  level: LOG_LEVEL,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: {
    service: 'tunnel-aware-container',
    userId: USER_ID,
    proxyId: PROXY_ID,
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

/**
 * Filter sensitive headers from response headers
 * @param {Object} headers - Response headers
 * @returns {Object} Filtered headers
 */
function filterSensitiveHeaders(headers) {
  if (!headers) {
    return {};
  }

  const sensitiveHeaders = [
    'authorization',
    'cookie',
    'set-cookie',
    'x-auth-token',
    'x-api-key',
    'x-access-token',
    'proxy-authorization',
    'www-authenticate',
  ];

  const filtered = {};
  for (const [key, value] of Object.entries(headers)) {
    if (!sensitiveHeaders.includes(key.toLowerCase())) {
      filtered[key] = value;
    }
  }
  return filtered;
}

/**
 * Simple HTTP client for testing tunnel connectivity
 * Uses standard HTTP libraries - no special tunnel code needed
 */
class TunnelHttpClient {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
    this.requestCount = 0;
    this.successCount = 0;
    this.errorCount = 0;
  }

  /**
   * Make HTTP request through tunnel proxy
   * @param {string} path - API path
   * @param {Object} options - Request options
   * @returns {Promise<Object>} Response data
   */
  async request(path, options = {}) {
    return new Promise((resolve, reject) => {
      const url = new URL(path, this.baseUrl);
      const client = url.protocol === 'https:' ? https : http;

      const requestOptions = {
        method: options.method || 'GET',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CloudToLocalLLM-Container/1.0',
          ...options.headers,
        },
        timeout: 30000,
      };

      this.requestCount++;
      logger.debug(
        `Making ${requestOptions.method} request to ${url.toString()}`,
      );

      const req = client.request(url, requestOptions, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          // Filter sensitive headers before returning
          const safeHeaders = filterSensitiveHeaders(res.headers);

          if (res.statusCode >= 200 && res.statusCode < 300) {
            this.successCount++;
            logger.debug(`Request successful: ${res.statusCode}`);

            try {
              const jsonData = JSON.parse(data);
              resolve({
                statusCode: res.statusCode,
                headers: safeHeaders,
                data: jsonData,
              });
            } catch {
              resolve({
                statusCode: res.statusCode,
                headers: safeHeaders,
                data,
              });
            }
          } else {
            this.errorCount++;
            logger.warn(
              `Request failed: ${res.statusCode} ${res.statusMessage}`,
            );
            reject(new Error(`HTTP ${res.statusCode}: ${res.statusMessage}`));
          }
        });
      });

      req.on('error', (error) => {
        this.errorCount++;
        logger.error('Request error:', error);
        reject(error);
      });

      req.on('timeout', () => {
        this.errorCount++;
        logger.error('Request timeout');
        req.destroy();
        reject(new Error('Request timeout'));
      });

      // Send request body if provided
      if (options.body) {
        req.write(
          typeof options.body === 'string'
            ? options.body
            : JSON.stringify(options.body),
        );
      }

      req.end();
    });
  }

  /**
   * Test tunnel connectivity
   * @returns {Promise<boolean>} True if tunnel is working
   */
  async testConnectivity() {
    try {
      logger.info('Testing tunnel connectivity...');
      const response = await this.request('/api/tags');
      logger.info('Tunnel connectivity test successful', {
        statusCode: response.statusCode,
        modelsCount: response.data?.models?.length || 0,
      });
      return true;
    } catch (error) {
      logger.error('Tunnel connectivity test failed:', error.message);
      return false;
    }
  }

  /**
   * Get client statistics
   * @returns {Object} Client stats
   */
  getStats() {
    return {
      requestCount: this.requestCount,
      successCount: this.successCount,
      errorCount: this.errorCount,
      successRate:
        this.requestCount > 0 ? this.successCount / this.requestCount : 0,
    };
  }
}

// Initialize HTTP client if OLLAMA_BASE_URL is configured
let httpClient = null;
if (OLLAMA_BASE_URL) {
  httpClient = new TunnelHttpClient(OLLAMA_BASE_URL);
  logger.info(
    `Initialized HTTP client for tunnel endpoint: ${OLLAMA_BASE_URL ? '***REDACTED***' : 'unknown'}`,
  );
} else {
  logger.warn('OLLAMA_BASE_URL not configured - tunnel client disabled');
}

// HTTP server for health checks and tunnel testing
const server = http.createServer(async(req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  switch (url.pathname) {
  case '/health':
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'healthy',
        userId: USER_ID,
        proxyId: PROXY_ID,
        ollamaBaseUrl: OLLAMA_BASE_URL ? '***REDACTED***' : 'not configured',
        tunnelConfigured: !!OLLAMA_BASE_URL,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
      }),
    );
    break;

  case '/test-tunnel':
    if (!httpClient) {
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          error: 'Tunnel not configured',
          message: 'OLLAMA_BASE_URL environment variable not set',
        }),
      );
      return;
    }

    try {
      const isConnected = await httpClient.testConnectivity();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          tunnelConnected: isConnected,
          stats: httpClient.getStats(),
          timestamp: new Date().toISOString(),
        }),
      );
    } catch (error) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          error: 'Tunnel test failed',
          message: error.message,
          stats: httpClient.getStats(),
        }),
      );
    }
    break;

  case '/stats':
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        container: {
          userId: USER_ID,
          proxyId: PROXY_ID,
          uptime: process.uptime(),
          memoryUsage: process.memoryUsage(),
        },
        tunnel: httpClient
          ? {
            configured: true,
            baseUrl: OLLAMA_BASE_URL ? '***REDACTED***' : 'not configured',
            stats: httpClient.getStats(),
          }
          : {
            configured: false,
          },
        timestamp: new Date().toISOString(),
      }),
    );
    break;

  default:
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    logger.info('Container server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  process.emit('SIGTERM');
});

// Start the container server
server.listen(PORT, async() => {
  logger.info(`Container server listening on port ${PORT}`, {
    userId: USER_ID,
    proxyId: PROXY_ID,
    port: PORT,
    ollamaBaseUrl: OLLAMA_BASE_URL ? '***REDACTED***' : 'not configured',
    nodeVersion: process.version,
  });

  // Test tunnel connectivity on startup if configured
  if (httpClient) {
    setTimeout(async() => {
      try {
        await httpClient.testConnectivity();
        logger.info('Initial tunnel connectivity test completed');
      } catch (error) {
        logger.warn('Initial tunnel connectivity test failed:', error.message);
      }
    }, 5000); // Wait 5 seconds for services to be ready
  }
});

// Periodic tunnel connectivity check
if (httpClient) {
  setInterval(
    async() => {
      try {
        await httpClient.testConnectivity();
      } catch (error) {
        logger.warn(
          'Periodic tunnel connectivity check failed:',
          error.message,
        );
      }
    },
    5 * 60 * 1000,
  ); // Check every 5 minutes
}
