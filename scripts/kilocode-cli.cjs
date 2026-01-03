#!/usr/bin/env node

/**
 * Kilocode CLI Wrapper
 * 
 * Simplified configuration loading for Kilocode API.
 * Prioritizes kilocode.config.json if available.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

const CLI_VERSION = '3.10.0';

const VERSION_COMPATIBILITY = {
  '3.x': { minNode: '18.0.0', minNpm: '9.0.0' },
  '4.x': { minNode: '20.0.0', minNpm: '10.0.0' }
};

const responseSchemas = {
  analysis: {
    required: ['choices'],
    properties: {
      choices: 'array'
    }
  }
};

/**
 * Metrics Collector
 * Tracks API request metrics and circuit breaker state
 */
class MetricsCollector {
  constructor() {
    this.metrics = {
      requests: 0,
      successes: 0,
      failures: 0,
      totalLatency: 0,
      circuitBreakerTransitions: 0
    };
  }

  recordRequest(latency, success) {
    this.metrics.requests++;
    if (success) {
      this.metrics.successes++;
    } else {
      this.metrics.failures++;
    }
    this.metrics.totalLatency += latency;
  }

  recordTransition() {
    this.metrics.circuitBreakerTransitions++;
  }

  getSummary() {
    const avgLatency = this.metrics.requests > 0 ? (this.metrics.totalLatency / this.metrics.requests).toFixed(2) : 0;
    const successRate = this.metrics.requests > 0 ? ((this.metrics.successes / this.metrics.requests) * 100).toFixed(2) : 0;
    return {
      ...this.metrics,
      avgLatency: `${avgLatency}ms`,
      successRate: `${successRate}%`
    };
  }
}

const metricsCollector = new MetricsCollector();

/**
 * Basic response schema validation
 */
function validateResponse(data, schemaType) {
  const schema = responseSchemas[schemaType];
  if (!schema) return true; // No schema, skip validation

  for (const field of schema.required) {
    if (!(field in data)) {
      throw new Error(`Response validation error: Missing required field '${field}'`);
    }
  }
  return true;
}

/**
 * Circuit Breaker Implementation
 * Prevents cascade failures by temporarily stopping requests when failure rate is high
 */
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.successThreshold = options.successThreshold || 2;
    this.timeout = options.timeout || 60000;
    this.resetTimeout = options.resetTimeout || 60000;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
  }

  async execute(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = 'HALF_OPEN';
        this.successCount = 0;
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failureCount = 0;
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.state = 'CLOSED';
      }
    }
  }

  onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
      metricsCollector.recordTransition();
    }
  }

  getState() {
    return this.state;
  }
}

/**
 * Multi-Endpoint Fallback Manager
 * Tries multiple API endpoints in case of failures
 */
class EndpointManager {
  constructor() {
    this.endpoints = [
      { hostname: 'api.kilo.ai', path: '/v1/chat/completions' },
      { hostname: 'api.kilo.ai', path: '/api/v1/chat/completions' },
      { hostname: 'app.kilo.ai', path: '/api/v1/chat/completions' },
      { hostname: 'www.kilo.ai', path: '/api/v1/chat/completions' }
    ];
    this.currentIndex = 0;
  }

  getNextEndpoint() {
    const endpoint = this.endpoints[this.currentIndex];
    this.currentIndex = (this.currentIndex + 1) % this.endpoints.length;
    return endpoint;
  }

  reset() {
    this.currentIndex = 0;
  }

  async checkHealth() {
    const results = await Promise.all(this.endpoints.map(async endpoint => {
      const health = await performHealthCheck({ hostname: endpoint.hostname });
      return { endpoint, health };
    }));

    const healthy = results
      .filter(r => r.health.healthy)
      .map(r => r.endpoint);

    if (healthy.length > 0) {
      this.endpoints = healthy.concat(this.endpoints.filter(e => !healthy.includes(e)));
      this.currentIndex = 0;
    }
  }
}

/**
 * Token Manager
 * Handles token storage, validation, and refresh
 */
class TokenManager {
  constructor() {
    this.token = null;
    this.expiresAt = null;
    this.refreshToken = null;
  }

  setToken(token, expiresIn = 3600, refreshToken = null) {
    this.token = token;
    // Set expiration to 60 seconds before actual expiration to be safe
    this.expiresAt = Date.now() + (expiresIn * 1000);
    if (refreshToken) {
      this.refreshToken = refreshToken;
    }
  }

  async getValidToken() {
    if (this.isTokenExpired()) {
      await this.refreshAccessToken();
    }
    return this.token;
  }

  isTokenExpired() {
    // If no token, it's "expired" (or rather, missing)
    if (!this.token) return true;
    // If no expiration set, assume valid (e.g. static API key)
    if (!this.expiresAt) return false;
    
    return Date.now() > this.expiresAt - 60000;
  }

  async refreshAccessToken() {
    if (!this.refreshToken) {
      // If we don't have a refresh token, we can't refresh.
      // For static keys, this is expected.
      return;
    }

    console.log('Refreshing access token...');
    // Placeholder for refresh logic
    // const response = await https.post(...)
    // this.setToken(response.token, response.expiresIn, response.refreshToken);
    
    // For now, since we don't have the endpoint, we'll just log
    console.warn('Token refresh not yet implemented due to missing API endpoint');
  }
}

/**
 * Simple File-based Cache
 * Stores API responses for fallback use
 */
class ResponseCache {
  constructor() {
    this.cacheDir = path.join(os.homedir(), '.kilocode', 'cache');
    try {
      if (!fs.existsSync(this.cacheDir)) {
        fs.mkdirSync(this.cacheDir, { recursive: true });
      }
    } catch (e) {
      console.warn('Warning: Failed to create cache directory:', e.message);
    }
  }

  get(key) {
    const cachePath = path.join(this.cacheDir, `${this.hash(key)}.json`);
    if (fs.existsSync(cachePath)) {
      try {
        const data = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
        // Cache expires after 24 hours
        if (Date.now() - data.timestamp < 24 * 60 * 60 * 1000) {
          return data.response;
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  set(key, response) {
    const cachePath = path.join(this.cacheDir, `${this.hash(key)}.json`);
    try {
      fs.writeFileSync(cachePath, JSON.stringify({
        timestamp: Date.now(),
        response
      }));
    } catch (e) {
      console.warn('Warning: Failed to write to cache:', e.message);
    }
  }

  hash(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash |= 0; // Convert to 32bit integer
    }
    return Math.abs(hash).toString(16);
  }
}

const responseCache = new ResponseCache();

async function performHealthCheck(options = {}) {
  const endpoints = [
    '/health',
    '/api/health',
    '/v1/health',
    '/status'
  ];
  const timeout = options.timeout || 5000;

  for (const ep of endpoints) {
    try {
      const health = await new Promise((resolve, reject) => {
        const reqOptions = {
          hostname: options.hostname,
          path: ep,
          method: 'GET',
          timeout
        };

        const req = https.request(reqOptions, res => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve({ healthy: true, endpoint: ep });
          } else {
            resolve({ healthy: false, status: res.statusCode });
          }
          res.resume();
        });

        req.on('error', reject);
        req.on('timeout', () => {
          req.destroy();
          reject(new Error('Timeout'));
        });

        req.end();
      });

      if (health.healthy) return health;
    } catch (e) {
      console.warn(`Health check failed for ${ep}: ${e.message}`);
      continue;
    }
  }
  return { healthy: false, error: 'All health endpoints failed' };
}

const args = process.argv.slice(2);
const configureCi = args.includes('--configure-ci');
const providerArg = args.find(arg => arg.startsWith('--provider='))?.split('=')[1];
const prompt = args.filter(arg => !arg.startsWith('-')).join(' ');

// --configure-ci: Helper to set up CI environment
if (configureCi) {
  const isCI = process.env.CI || process.env.GITHUB_ACTIONS;
  if (!isCI) {
    console.warn('Warning: --configure-ci is intended for CI environments.');
  }

  const token = process.env.KILOCODE_TOKEN;
  const model = process.env.KILOCODE_MODEL || 'x-ai/grok-code-fast-1';
  const posthog = process.env.KILOCODE_POSTHOG_API_KEY;

  if (!token) {
    console.error('Error: KILOCODE_TOKEN environment variable is required for configuration.');
    process.exit(1);
  }

  const configDir = path.join(os.homedir(), '.kilocode');
  const configPath = path.join(configDir, 'config.json');

  try {
    if (!fs.existsSync(configDir)) {
      fs.mkdirSync(configDir, { recursive: true });
    }

    const config = {
      providers: [
        {
          id: "default",
          provider: "kilocode",
          kilocodeToken: token,
          kilocodeModel: model,
          kilocodePosthogApiKey: posthog
        }
      ]
    };

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log(`Successfully configured CI environment at: ${configPath}`);
    process.exit(0);
  } catch (e) {
    console.error('Failed to write CI configuration:', e.message);
    process.exit(1);
  }
}

if (!prompt) {
  console.error('Usage: kilocode-cli <prompt>');
  console.error('       kilocode-cli --configure-ci');
  process.exit(1);
}

// Default values from environment
let apiKey = process.env.KILOCODE_TOKEN;
let apiModel = process.env.KILOCODE_MODEL || 'x-ai/grok-code-fast-1';
let posthogApiKey = process.env.KILOCODE_POSTHOG_API_KEY;

/**
 * Calculate delay for adaptive retry with jitter
 */
function calculateDelay(attempt, config) {
  const baseDelay = config.baseDelay || 1000;
  const maxDelay = config.maxDelay || 30000;
  const exponentialBase = config.exponentialBase || 2;
  const jitter = config.jitter !== false;

  const exponentialDelay = baseDelay * Math.pow(exponentialBase, attempt);
  const cappedDelay = Math.min(exponentialDelay, maxDelay);
  
  if (jitter) {
    return cappedDelay * (0.5 + Math.random() * 0.5);
  }
  return cappedDelay;
}

/**
 * Safe JSON parsing with fallback
 */
function safeJsonParse(text, fallback = null) {
  try {
    return JSON.parse(text);
  } catch (e) {
    console.warn('JSON parse error:', e.message);
    return fallback;
  }
}

/**
 * Semantic version validation
 */
function validateSemVer(version) {
  const semverRegex = /^(\d+)\.(\d+)\.(\d+)(-[\w.]+)?(\+[\w.]+)?$/;
  return semverRegex.test(version);
}

/**
 * Check version compatibility
 */
function checkCompatibility(version, strict = false) {
  const major = version.split('.')[0];
  const compat = VERSION_COMPATIBILITY[`${major}.x`];
  
  if (compat) {
    const currentNodeVersion = process.version.replace('v', '');
    if (compareVersions(currentNodeVersion, compat.minNode) < 0) {
      const msg = `Current Node.js version ${process.version} is below the recommended minimum ${compat.minNode} for CLI version ${version}`;
      if (strict) {
        console.error(`Error: ${msg}. Please upgrade Node.js.`);
        process.exit(1);
      } else {
        console.warn(`Warning: ${msg}`);
      }
    }
  }
}

/**
 * Simple version comparison
 */
function compareVersions(v1, v2) {
  const parts1 = v1.split('.').map(Number);
  const parts2 = v2.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if (parts1[i] > parts2[i]) return 1;
    if (parts1[i] < parts2[i]) return -1;
  }
  return 0;
}

/**
 * Resolve a config value that may reference an environment variable.
 * Supports ${VAR_NAME} and $VAR_NAME.
 */
function resolveEnvRef(value) {
  if (typeof value !== 'string') return value;

  const trimmed = value.trim();
  const braced = trimmed.match(/^\$\{([A-Z0-9_]+)\}$/);
  if (braced) return process.env[braced[1]];

  const bare = trimmed.match(/^\$([A-Z0-9_]+)$/);
  if (bare) return process.env[bare[1]];

  return value;
}

// Configuration loading logic
const configPaths = [
  path.join(process.cwd(), 'kilocode.config.json'),
  path.join(os.homedir(), '.kilocode', 'config.json')
];

let configLoaded = false;

for (const configPath of configPaths) {
  if (fs.existsSync(configPath)) {
    try {
      const isCI = process.env.CI || process.env.GITHUB_ACTIONS;
      if (isCI) {
        console.log(`Loading configuration from: ${configPath}`);
      } else {
        // Basic security check for local config file
        const stats = fs.statSync(configPath);
        const mode = stats.mode & 0o777;
        if (mode > 0o600 && os.platform() !== 'win32') {
          console.warn(`Warning: Configuration file ${configPath} has insecure permissions (${mode.toString(8)}). Recommended: 600`);
        }
      }
      
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      // Select provider: either by ID if provided, or the first one
      if (config.providers && Array.isArray(config.providers) && config.providers.length > 0) {
        const provider = providerArg
          ? config.providers.find(p => p.id === providerArg) || config.providers[0]
          : config.providers[0];
          
        if (providerArg && provider.id !== providerArg) {
          console.warn(`Warning: Provider '${providerArg}' not found, falling back to default.`);
        }

        const resolvedToken = resolveEnvRef(provider.kilocodeToken);
        const resolvedModel = resolveEnvRef(provider.kilocodeModel);
        const resolvedPosthog = resolveEnvRef(provider.kilocodePosthogApiKey);

        if (resolvedToken) apiKey = resolvedToken;
        if (resolvedModel) apiModel = resolvedModel;
        if (resolvedPosthog) posthogApiKey = resolvedPosthog;
        
        configLoaded = true;
        break; // Stop after finding the first valid config
      }
    } catch (e) {
      console.warn(`Warning: Failed to read config from ${configPath}`, e.message);
    }
  }
}

if (!apiKey) {
  console.error('Error: KILOCODE_TOKEN not found (env or config).');
  process.exit(1);
}

(async () => {
  // Validate CLI version
  if (!validateSemVer(CLI_VERSION)) {
    console.warn(`Warning: Invalid CLI version format: ${CLI_VERSION}`);
  }
  checkCompatibility(CLI_VERSION, process.env.KILOCODE_STRICT_COMPATIBILITY === 'true');

  const maxRetries = parseInt(process.env.KILOCODE_MAX_RETRIES) || 3;
  const retryDelay = parseInt(process.env.KILOCODE_RETRY_DELAY) || 2000; // 2 seconds

  const data = JSON.stringify({
    model: apiModel,
    messages: [
      {
        role: 'system',
        content: 'You are a CI/CD orchestration assistant. You analyze code changes and decide on version bumps and deployment strategies. Respond ONLY with valid JSON.'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    temperature: 0.1,
    max_tokens: 2048
  });

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${apiKey}`,
    'Content-Length': Buffer.byteLength(data)
  };

  if (posthogApiKey) {
    headers['x-posthog-api-key'] = posthogApiKey;
  }

  const circuitBreaker = new CircuitBreaker();
  const endpointManager = new EndpointManager();
  const tokenManager = new TokenManager();

  // Initialize token manager with current API key
  // Assuming static key for now, so no expiration
  tokenManager.setToken(apiKey);

  try {
    await endpointManager.checkHealth();
  } catch (e) {
    console.warn('Initial health check failed:', e.message);
    // Continue with default endpoints
  }

  async function makeRequest(retryCount = 0) {
    const startTime = Date.now();
    const cacheKey = `${apiModel}:${prompt}`;

    if (circuitBreaker.getState() === 'OPEN') {
      const cached = responseCache.get(cacheKey);
      if (cached) {
        console.warn('Circuit breaker is OPEN, using cached response');
        return cached;
      }
    }

    try {
      return await circuitBreaker.execute(async () => {
        const endpoint = endpointManager.getNextEndpoint();
        const timeout = parseInt(process.env.KILOCODE_TIMEOUT) || 60000;

        if (process.env.KILOCODE_VERBOSE === 'true') {
          console.warn(`[DEBUG] Requesting ${endpoint.hostname}${endpoint.path} (Attempt ${retryCount + 1})`);
        }

        const options = {
          hostname: endpoint.hostname,
          port: 443,
          path: endpoint.path,
          method: 'POST',
          headers: headers,
          timeout: timeout
        };

        // Ensure we have a valid token before making the request
        const currentToken = await tokenManager.getValidToken();
        if (currentToken) {
          options.headers['Authorization'] = `Bearer ${currentToken}`;
        }

        return new Promise((resolve, reject) => {
          const req = https.request(options, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
              if (res.statusCode === 404 || res.statusCode === 405) {
                if (retryCount < maxRetries) {
                  console.warn(`API Error (${res.statusCode}) at ${endpoint.hostname}${endpoint.path}, trying next endpoint... (${retryCount + 1}/${maxRetries})`);
                  resolve(makeRequest(retryCount + 1));
                } else {
                  reject(new Error(`API Error (${res.statusCode}): All endpoints failed`));
                }
                return;
              } else if (res.statusCode === 401) {
                if (retryCount < maxRetries) {
                  console.warn(`Authentication Error (401), attempting token refresh... (${retryCount + 1}/${maxRetries})`);
                  tokenManager.refreshAccessToken().then(() => {
                    resolve(makeRequest(retryCount + 1));
                  }).catch(reject);
                } else {
                  reject(new Error('Authentication Error (401): Max retries reached after refresh attempts'));
                }
                return;
              } else if (res.statusCode >= 400) {
                if (retryCount < maxRetries && (res.statusCode >= 500 || res.statusCode === 429)) {
                  const delay = calculateDelay(retryCount, {
                    baseDelay: retryDelay,
                    maxDelay: 30000,
                    exponentialBase: 2,
                    jitter: true
                  });

                  console.warn(`API Error (${res.statusCode}), retrying in ${Math.round(delay)}ms... (${retryCount + 1}/${maxRetries})`);
                  setTimeout(() => resolve(makeRequest(retryCount + 1)), delay);
                  return;
                }
                reject(new Error(`KiloCode API Error (${res.statusCode}): ${body}`));
                return;
              }
              
              const response = safeJsonParse(body);
              if (!response) {
                reject(new Error('Failed to parse response: Invalid JSON'));
                return;
              }

              try {
                validateResponse(response, 'analysis');
              } catch (e) {
                reject(e);
                return;
              }

              if (response.choices?.[0]?.message?.content) {
                let text = response.choices[0].message.content;
                text = text.replace(/```json/g, '').replace(/```/g, '').trim();
                responseCache.set(cacheKey, text);
                resolve(text);
              } else if (response.error) {
                reject(new Error(response.error.message || response.error));
              } else {
                reject(new Error('Unexpected response format: ' + body));
              }
            });
          });

          req.on('error', (e) => {
            reject(e);
          });

          req.on('timeout', () => {
            req.destroy();
            reject(new Error('Request timed out'));
          });

          req.write(data);
          req.end();
        });
      });
    } catch (e) {
      if (e.message === 'Circuit breaker is OPEN') {
        console.error('Circuit breaker is open. Please try again later.');
        process.exit(1);
      }
      throw e;
    }
  }

  makeRequest()
    .then(result => console.log(result))
    .catch(e => {
      console.error(e.message);
      process.exit(1);
    });
})();
