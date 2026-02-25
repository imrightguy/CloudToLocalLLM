/**
 * @fileoverview HTTP Polling Bridge Routes for CloudToLocalLLM
 * Provides HTTP-based communication as fallback when WebSocket connections fail
 */

import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import rateLimit from 'express-rate-limit';
import { authenticateComposite } from '../middleware/composite-auth.js';
import { addTierInfo } from '../middleware/tier-check.js';
import { TunnelLogger } from '../utils/logger.js';

const router = express.Router();
const logger = new TunnelLogger('BridgePolling');

// In-memory stores for HTTP polling (in production, use Redis)
const bridgeRegistrations = new Map(); // bridgeId -> bridge info
const pendingRequests = new Map(); // bridgeId -> array of pending requests
const completedResponses = new Map(); // requestId -> response data
const bridgeHeartbeats = new Map(); // bridgeId -> last heartbeat timestamp

// Configuration
const POLLING_TIMEOUT = 30000; // 30 seconds
const REQUEST_TIMEOUT = 60000; // 60 seconds
const HEARTBEAT_TIMEOUT = 90000; // 90 seconds
const MAX_PENDING_REQUESTS = 100;
const MAX_COMPLETED_RESPONSES = 500;

// Rate limiting for bridge endpoints
const bridgePollingLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // Allow 30 polling requests per minute per IP (increased from 20)
  message: {
    error: 'Too many polling requests',
    code: 'RATE_LIMIT_EXCEEDED',
    retryAfter: 60,
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const bridgeHeartbeatLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // Allow 10 heartbeat requests per minute per IP (increased from 5)
  message: {
    error: 'Too many heartbeat requests',
    code: 'RATE_LIMIT_EXCEEDED',
    retryAfter: 60,
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const bridgeProviderStatusLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // Allow 10 provider status updates per minute per IP
  message: {
    error: 'Too many provider status updates',
    code: 'RATE_LIMIT_EXCEEDED',
    retryAfter: 60,
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const bridgeRegistrationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Allow 5 registrations per 15 minutes per IP
  message: {
    error: 'Too many registration attempts',
    code: 'RATE_LIMIT_EXCEEDED',
    retryAfter: 900, // 15 minutes
  },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * Register a desktop client for HTTP polling
 * POST /api/bridge/register
 */
router.post(
  '/register',
  bridgeRegistrationLimiter,
  ...authenticateComposite,
  addTierInfo,
  (req, res) => {
    const { clientId, platform, version, capabilities } = req.body;
    // Use req.userId which is populated by both JWT and API Key auth
    const userId = req.userId || req.user?.sub;

    if (!userId) {
      return res.status(401).json({ error: 'User ID not found' });
    }
    const bridgeId = uuidv4();

    if (!clientId || !platform || !version) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'clientId, platform, and version are required',
      });
    }

    // Store bridge registration
    const bridgeInfo = {
      bridgeId,
      clientId,
      userId,
      platform,
      version,
      capabilities: capabilities || [],
      registeredAt: new Date(),
      lastSeen: new Date(),
      status: 'registered',
    };

    bridgeRegistrations.set(bridgeId, bridgeInfo);
    bridgeHeartbeats.set(bridgeId, Date.now());
    pendingRequests.set(bridgeId, []);

    logger.info('Bridge registered for HTTP polling', {
      bridgeId,
      clientId,
      userId,
      platform,
      version,
    });

    res.json({
      success: true,
      bridgeId,
      sessionToken: req.headers.authorization, // Reuse existing JWT
      endpoints: {
        polling: `/api/bridge/${bridgeId}/poll`,
        response: `/api/bridge/${bridgeId}/response`,
        status: `/api/bridge/${bridgeId}/status`,
        heartbeat: `/api/bridge/${bridgeId}/heartbeat`,
        providerStatus: `/api/bridge/${bridgeId}/provider-status`,
      },
      config: {
        pollingInterval: 10000, // 10 seconds (increased from 5 to reduce rate limiting)
        requestTimeout: REQUEST_TIMEOUT,
        heartbeatInterval: 60000, // 60 seconds (increased from 30 to reduce rate limiting)
      },
    });
  },
);

/**
 * Get bridge status
 * GET /api/bridge/{bridgeId}/status
 */
router.get('/:bridgeId/status', ...authenticateComposite, (req, res) => {
  const { bridgeId } = req.params;
  const userId = req.userId || req.user?.sub;

  if (!userId) {
    return res.status(401).json({ error: 'User ID not found' });
  }

  const bridge = bridgeRegistrations.get(bridgeId);
  if (!bridge) {
    return res.status(404).json({
      error: 'Bridge not found',
      message: 'Bridge ID not registered',
    });
  }

  // Verify ownership
  if (bridge.userId !== userId) {
    return res.status(403).json({
      error: 'Access denied',
      message: 'You can only access your own bridges',
    });
  }

  // Check if bridge is alive based on heartbeat
  const lastHeartbeat = bridgeHeartbeats.get(bridgeId) || 0;
  const isAlive = Date.now() - lastHeartbeat < HEARTBEAT_TIMEOUT;

  res.json({
    bridgeId,
    status: isAlive ? 'connected' : 'disconnected',
    lastSeen: new Date(lastHeartbeat).toISOString(),
    client: {
      clientId: bridge.clientId,
      platform: bridge.platform,
      version: bridge.version,
      capabilities: bridge.capabilities,
    },
    providers: bridge.providers || [],
    lastProviderUpdate: bridge.lastProviderUpdate || null,
    stats: {
      pendingRequests: pendingRequests.get(bridgeId)?.length || 0,
      completedResponses: Array.from(completedResponses.values()).filter(
        (r) => r.bridgeId === bridgeId,
      ).length,
    },
  });
});

/**
 * Poll for pending requests (Desktop client calls this)
 * GET /api/bridge/{bridgeId}/poll
 */
router.get(
  '/:bridgeId/poll',
  bridgePollingLimiter,
  ...authenticateComposite,
  (req, res) => {
    const { bridgeId } = req.params;
    const userId = req.userId || req.user?.sub;
    const timeout = parseInt(req.query.timeout) || POLLING_TIMEOUT;

    const bridge = bridgeRegistrations.get(bridgeId);
    if (!bridge || bridge.userId !== userId) {
      return res.status(404).json({
        error: 'Bridge not found or access denied',
      });
    }

    // Update heartbeat
    bridgeHeartbeats.set(bridgeId, Date.now());
    bridge.lastSeen = new Date();

    const requests = pendingRequests.get(bridgeId) || [];

    if (requests.length > 0) {
      // Return pending requests immediately
      const requestsToSend = requests.splice(0, 10); // Send up to 10 requests at once

      logger.debug('Sending pending requests to bridge', {
        bridgeId,
        requestCount: requestsToSend.length,
      });

      return res.json({
        success: true,
        requests: requestsToSend,
        hasMore: requests.length > 0,
      });
    }

    // Long polling: wait for requests
    const startTime = Date.now();
    const pollInterval = setInterval(() => {
      const currentRequests = pendingRequests.get(bridgeId) || [];

      if (currentRequests.length > 0 || Date.now() - startTime >= timeout) {
        clearInterval(pollInterval);

        if (currentRequests.length > 0) {
          const requestsToSend = currentRequests.splice(0, 10);
          res.json({
            success: true,
            requests: requestsToSend,
            hasMore: currentRequests.length > 0,
          });
        } else {
          // Timeout - no requests
          res.json({
            success: true,
            requests: [],
            hasMore: false,
          });
        }
      }
    }, 1000); // Check every second

    // Cleanup on client disconnect
    req.on('close', () => {
      clearInterval(pollInterval);
    });
  },
);

/**
 * Update provider status from desktop client
 * POST /api/bridge/{bridgeId}/provider-status
 */
router.post(
  '/:bridgeId/provider-status',
  bridgeProviderStatusLimiter,
  ...authenticateComposite,
  (req, res) => {
    const { bridgeId } = req.params;
    const userId = req.userId || req.user?.sub;
    const { providers, timestamp } = req.body;

    const bridge = bridgeRegistrations.get(bridgeId);
    if (!bridge || bridge.userId !== userId) {
      return res.status(404).json({
        error: 'Bridge not found or access denied',
      });
    }

    // Update bridge with provider information
    bridge.providers = providers || [];
    bridge.lastProviderUpdate = timestamp || new Date().toISOString();
    bridge.lastSeen = new Date();

    // Update heartbeat to indicate bridge is active
    bridgeHeartbeats.set(bridgeId, Date.now());

    logger.debug('Provider status updated', {
      bridgeId,
      userId,
      providerCount: providers?.length || 0,
      timestamp,
    });

    res.json({
      success: true,
      message: 'Provider status updated',
      timestamp: new Date().toISOString(),
    });
  },
);

/**
 * Submit response from desktop client
 * POST /api/bridge/{bridgeId}/response
 */
router.post('/:bridgeId/response', ...authenticateComposite, (req, res) => {
  const { bridgeId } = req.params;
  const userId = req.userId || req.user?.sub;
  const { requestId, status, headers, body, error } = req.body;

  const bridge = bridgeRegistrations.get(bridgeId);
  if (!bridge || bridge.userId !== userId) {
    return res.status(404).json({
      error: 'Bridge not found or access denied',
    });
  }

  if (!requestId) {
    return res.status(400).json({
      error: 'Missing requestId',
    });
  }

  // Update heartbeat
  bridgeHeartbeats.set(bridgeId, Date.now());

  // Store response
  const responseData = {
    requestId,
    bridgeId,
    status: status || (error ? 500 : 200),
    headers: headers || {},
    body: body || '',
    error,
    timestamp: new Date(),
  };

  completedResponses.set(requestId, responseData);

  // Clean up old responses (keep only recent ones)
  if (completedResponses.size > MAX_COMPLETED_RESPONSES) {
    const entries = Array.from(completedResponses.entries());
    entries.sort((a, b) => b[1].timestamp - a[1].timestamp);

    // Keep only the most recent responses
    completedResponses.clear();
    entries.slice(0, MAX_COMPLETED_RESPONSES).forEach(([id, data]) => {
      completedResponses.set(id, data);
    });
  }

  logger.debug('Received response from bridge', {
    bridgeId,
    requestId,
    status: responseData.status,
  });

  res.json({
    success: true,
    message: 'Response received',
  });
});

/**
 * Send heartbeat (Desktop client calls this)
 * POST /api/bridge/{bridgeId}/heartbeat
 */
router.post(
  '/:bridgeId/heartbeat',
  bridgeHeartbeatLimiter,
  ...authenticateComposite,
  (req, res) => {
    const { bridgeId } = req.params;
    const userId = req.userId || req.user?.sub;

    const bridge = bridgeRegistrations.get(bridgeId);
    if (!bridge || bridge.userId !== userId) {
      return res.status(404).json({
        error: 'Bridge not found or access denied',
      });
    }

    bridgeHeartbeats.set(bridgeId, Date.now());
    bridge.lastSeen = new Date();

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
    });
  },
);

/**
 * Queue a request for a bridge (Internal API)
 * This is called by the main proxy when it needs to send a request to a desktop client
 */
export function queueRequestForBridge(bridgeId, request) {
  const requests = pendingRequests.get(bridgeId);
  if (!requests) {
    throw new Error(`Bridge ${bridgeId} not found`);
  }

  if (requests.length >= MAX_PENDING_REQUESTS) {
    throw new Error(`Bridge ${bridgeId} request queue is full`);
  }

  const requestWithId = {
    ...request,
    id: request.id || uuidv4(),
    timestamp: new Date().toISOString(),
    timeout: Date.now() + REQUEST_TIMEOUT,
  };

  requests.push(requestWithId);

  logger.debug('Queued request for bridge', {
    bridgeId,
    requestId: requestWithId.id,
    queueSize: requests.length,
  });

  return requestWithId.id;
}

/**
 * Get response for a request (Internal API)
 */
export function getResponseForRequest(requestId, timeoutMs = REQUEST_TIMEOUT) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    const checkResponse = () => {
      const response = completedResponses.get(requestId);

      if (response) {
        completedResponses.delete(requestId); // Clean up
        resolve(response);
        return;
      }

      if (Date.now() - startTime >= timeoutMs) {
        reject(new Error('Request timeout'));
        return;
      }

      setTimeout(checkResponse, 500); // Check every 500ms
    };

    checkResponse();
  });
}

/**
 * Check if bridge is available for HTTP polling
 */
export function isBridgeAvailable(bridgeId) {
  const bridge = bridgeRegistrations.get(bridgeId);
  if (!bridge) {
    return false;
  }

  const lastHeartbeat = bridgeHeartbeats.get(bridgeId) || 0;
  return Date.now() - lastHeartbeat < HEARTBEAT_TIMEOUT;
}

/**
 * Get bridge by user ID
 */
export function getBridgeByUserId(userId) {
  for (const [bridgeId, bridge] of bridgeRegistrations.entries()) {
    if (bridge.userId === userId && isBridgeAvailable(bridgeId)) {
      return { bridgeId, ...bridge };
    }
  }
  return null;
}

// Cleanup old data periodically
setInterval(() => {
  const now = Date.now();

  // Clean up expired requests
  for (const [bridgeId, requests] of pendingRequests.entries()) {
    const validRequests = requests.filter((req) => req.timeout > now);
    pendingRequests.set(bridgeId, validRequests);
  }

  // Clean up old heartbeats
  for (const [bridgeId, lastHeartbeat] of bridgeHeartbeats.entries()) {
    if (now - lastHeartbeat > HEARTBEAT_TIMEOUT * 2) {
      bridgeHeartbeats.delete(bridgeId);
      bridgeRegistrations.delete(bridgeId);
      pendingRequests.delete(bridgeId);

      logger.info('Cleaned up inactive bridge', { bridgeId });
    }
  }
}, 60000); // Clean up every minute

export default router;
