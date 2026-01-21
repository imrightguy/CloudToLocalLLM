/**
 * @fileoverview Connection security middleware
 * Implements certificate validation, connection security measures, and TLS/SSL enforcement
 */

import crypto from 'crypto';
import { TunnelLogger, ErrorResponseBuilder } from '../utils/logger.js';

/**
 * Connection security configuration
 */
const DEFAULT_CONFIG = {
  // TLS/SSL settings
  enforceHttps: process.env.NODE_ENV === 'production',
  minTlsVersion: 'TLSv1.2',
  allowedCiphers: [
    'ECDHE-RSA-AES128-GCM-SHA256',
    'ECDHE-RSA-AES256-GCM-SHA384',
    'ECDHE-RSA-AES128-SHA256',
    'ECDHE-RSA-AES256-SHA384',
    'DHE-RSA-AES128-GCM-SHA256',
    'DHE-RSA-AES256-GCM-SHA384',
  ],

  // Certificate validation
  validateClientCertificates: false, // Set to true for mutual TLS
  allowSelfSignedCerts: process.env.NODE_ENV !== 'production',
  certificateRevocationCheck: true,

  // Connection security
  maxConnectionsPerIP: 100,
  connectionTimeoutMs: 30000,
  keepAliveTimeout: 65000,
  headersTimeout: 60000,

  // Security headers
  securityHeaders: {
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Content-Security-Policy':
      "default-src 'self'; connect-src 'self' wss: https:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
  },

  // WebSocket security
  websocketOriginCheck: true,
  allowedOrigins: [
    'https://app.cloudtolocalllm.online',
    'https://cloudtolocalllm.online',
    'https://docs.cloudtolocalllm.online',
    'https://app.cloudtolocalllm.online',
    'https://cloudtolocalllm.online',
    'https://docs.cloudtolocalllm.online',
  ],

  // Rate limiting for security events
  securityEventRateLimit: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    maxEvents: 10, // max security events per IP per window
  },
};

/**
 * Connection tracking for security monitoring
 */
class ConnectionTracker {
  constructor() {
    this.connections = new Map(); // IP -> connection info
    this.securityEvents = new Map(); // IP -> security events
    this.blockedIPs = new Set();
    this.suspiciousIPs = new Set();
  }

  /**
   * Track new connection
   * @param {string} ip - Client IP
   * @param {Object} connectionInfo - Connection information
   */
  trackConnection(ip, connectionInfo) {
    if (!this.connections.has(ip)) {
      this.connections.set(ip, {
        count: 0,
        firstConnection: new Date(),
        lastConnection: new Date(),
        connections: [],
      });
    }

    const tracker = this.connections.get(ip);
    tracker.count++;
    tracker.lastConnection = new Date();
    tracker.connections.push({
      timestamp: new Date(),
      userAgent: connectionInfo.userAgent,
      protocol: connectionInfo.protocol,
      tlsVersion: connectionInfo.tlsVersion,
      cipher: connectionInfo.cipher,
    });

    // Keep only recent connections (last 100)
    if (tracker.connections.length > 100) {
      tracker.connections = tracker.connections.slice(-100);
    }
  }

  /**
   * Record security event
   * @param {string} ip - Client IP
   * @param {string} eventType - Type of security event
   * @param {Object} details - Event details
   */
  recordSecurityEvent(ip, eventType, details) {
    if (!this.securityEvents.has(ip)) {
      this.securityEvents.set(ip, []);
    }

    const events = this.securityEvents.get(ip);
    events.push({
      type: eventType,
      timestamp: new Date(),
      details,
    });

    // Keep only recent events (last 50)
    if (events.length > 50) {
      this.securityEvents.set(ip, events.slice(-50));
    }

    // Check if IP should be marked as suspicious
    this.evaluateIPSuspicion(ip);
  }

  /**
   * Evaluate if IP should be marked as suspicious
   * @param {string} ip - Client IP
   */
  evaluateIPSuspicion(ip) {
    const events = this.securityEvents.get(ip) || [];
    const recentEvents = events.filter(
      (event) =>
        Date.now() - event.timestamp.getTime() <
        DEFAULT_CONFIG.securityEventRateLimit.windowMs
    );

    if (
      recentEvents.length >= DEFAULT_CONFIG.securityEventRateLimit.maxEvents
    ) {
      this.suspiciousIPs.add(ip);
    }

    // Auto-block IPs with excessive security events
    const criticalEvents = recentEvents.filter((event) =>
      [
        'certificate_validation_failed',
        'tls_handshake_failed',
        'malicious_request',
      ].includes(event.type)
    );

    if (criticalEvents.length >= 5) {
      this.blockedIPs.add(ip);
    }
  }

  /**
   * Check if IP is blocked
   * @param {string} ip - Client IP
   * @returns {boolean} True if blocked
   */
  isBlocked(ip) {
    return this.blockedIPs.has(ip);
  }

  /**
   * Check if IP is suspicious
   * @param {string} ip - Client IP
   * @returns {boolean} True if suspicious
   */
  isSuspicious(ip) {
    return this.suspiciousIPs.has(ip);
  }

  /**
   * Get connection statistics for IP
   * @param {string} ip - Client IP
   * @returns {Object} Connection statistics
   */
  getConnectionStats(ip) {
    const tracker = this.connections.get(ip);
    if (!tracker) {
      return { count: 0, firstConnection: null, lastConnection: null };
    }

    return {
      count: tracker.count,
      firstConnection: tracker.firstConnection,
      lastConnection: tracker.lastConnection,
      recentConnections: tracker.connections.slice(-10),
    };
  }

  /**
   * Clean up old tracking data
   */
  cleanup() {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours

    // Clean up old connections
    for (const [ip, tracker] of this.connections.entries()) {
      if (tracker.lastConnection < cutoff) {
        this.connections.delete(ip);
      }
    }

    // Clean up old security events
    for (const [ip, events] of this.securityEvents.entries()) {
      const recentEvents = events.filter((event) => event.timestamp > cutoff);
      if (recentEvents.length === 0) {
        this.securityEvents.delete(ip);
      } else {
        this.securityEvents.set(ip, recentEvents);
      }
    }

    // Clean up old suspicious IPs (but keep blocked IPs)
    const recentSuspicious = new Set();
    for (const ip of this.suspiciousIPs) {
      const events = this.securityEvents.get(ip) || [];
      const recentEvents = events.filter((event) => event.timestamp > cutoff);
      if (recentEvents.length > 0) {
        recentSuspicious.add(ip);
      }
    }
    this.suspiciousIPs = recentSuspicious;
  }
}

/**
 * Connection security manager
 */
export class ConnectionSecurityManager {
  constructor(config = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.logger = new TunnelLogger('connection-security');
    this.connectionTracker = new ConnectionTracker();

    // Start cleanup interval
    this.cleanupInterval = setInterval(
      () => {
        this.connectionTracker.cleanup();
      },
      60 * 60 * 1000
    ); // Every hour

    this.logger.info('Connection security manager initialized', {
      enforceHttps: this.config.enforceHttps,
      minTlsVersion: this.config.minTlsVersion,
      validateClientCertificates: this.config.validateClientCertificates,
      allowSelfSignedCerts: this.config.allowSelfSignedCerts,
    });
  }

  /**
   * Validate TLS connection
   * @param {Object} socket - TLS socket
   * @param {string} ip - Client IP
   * @returns {Object} Validation result
   */
  validateTLSConnection(socket, ip) {
    const correlationId = this.logger.generateCorrelationId();

    try {
      // Check if connection uses TLS
      if (!socket.encrypted) {
        if (this.config.enforceHttps) {
          this.connectionTracker.recordSecurityEvent(ip, 'non_tls_connection', {
            correlationId,
            enforceHttps: this.config.enforceHttps,
          });

          return {
            valid: false,
            reason: 'TLS connection required',
            errorCode: 'TLS_REQUIRED',
          };
        }

        // Allow non-TLS in development
        return { valid: true, reason: 'Non-TLS allowed in development' };
      }

      // Validate TLS version
      const tlsVersion = socket.getProtocol();
      if (!this.isValidTLSVersion(tlsVersion)) {
        this.connectionTracker.recordSecurityEvent(ip, 'invalid_tls_version', {
          correlationId,
          tlsVersion,
          minRequired: this.config.minTlsVersion,
        });

        return {
          valid: false,
          reason: `TLS version ${tlsVersion} not allowed. Minimum: ${this.config.minTlsVersion}`,
          errorCode: 'INVALID_TLS_VERSION',
        };
      }

      // Validate cipher suite
      const cipher = socket.getCipher();
      if (cipher && !this.isValidCipher(cipher.name)) {
        this.connectionTracker.recordSecurityEvent(ip, 'weak_cipher', {
          correlationId,
          cipher: cipher.name,
          allowedCiphers: this.config.allowedCiphers,
        });

        return {
          valid: false,
          reason: `Cipher ${cipher.name} not allowed`,
          errorCode: 'WEAK_CIPHER',
        };
      }

      // Validate client certificate if required
      if (this.config.validateClientCertificates) {
        const cert = socket.getPeerCertificate();
        const certValidation = this.validateClientCertificate(
          cert,
          ip,
          correlationId
        );
        if (!certValidation.valid) {
          return certValidation;
        }
      }

      this.logger.debug('TLS connection validation successful', {
        correlationId,
        ip,
        tlsVersion,
        cipher: cipher?.name,
        authorized: socket.authorized,
      });

      return {
        valid: true,
        tlsVersion,
        cipher: cipher?.name,
        authorized: socket.authorized,
      };
    } catch (error) {
      this.connectionTracker.recordSecurityEvent(ip, 'tls_validation_error', {
        correlationId,
        error: error.message,
      });

      this.logger.error('TLS connection validation failed', error, {
        correlationId,
        ip,
      });

      return {
        valid: false,
        reason: 'TLS validation failed',
        errorCode: 'TLS_VALIDATION_FAILED',
      };
    }
  }

  /**
   * Validate client certificate
   * @param {Object} cert - Client certificate
   * @param {string} ip - Client IP
   * @param {string} correlationId - Correlation ID
   * @returns {Object} Validation result
   */
  validateClientCertificate(cert, ip, correlationId) {
    if (!cert || Object.keys(cert).length === 0) {
      this.connectionTracker.recordSecurityEvent(
        ip,
        'missing_client_certificate',
        {
          correlationId,
        }
      );

      return {
        valid: false,
        reason: 'Client certificate required',
        errorCode: 'CLIENT_CERT_REQUIRED',
      };
    }

    // Check certificate validity period
    const now = new Date();
    const validFrom = new Date(cert.valid_from);
    const validTo = new Date(cert.valid_to);

    if (now < validFrom || now > validTo) {
      this.connectionTracker.recordSecurityEvent(
        ip,
        'expired_client_certificate',
        {
          correlationId,
          validFrom: cert.valid_from,
          validTo: cert.valid_to,
          currentTime: now.toISOString(),
        }
      );

      return {
        valid: false,
        reason: 'Client certificate expired or not yet valid',
        errorCode: 'CLIENT_CERT_EXPIRED',
      };
    }

    // Check if certificate is self-signed
    if (
      cert.issuer &&
      cert.subject &&
      JSON.stringify(cert.issuer) === JSON.stringify(cert.subject)
    ) {
      if (!this.config.allowSelfSignedCerts) {
        this.connectionTracker.recordSecurityEvent(
          ip,
          'self_signed_certificate',
          {
            correlationId,
            subject: cert.subject,
            issuer: cert.issuer,
          }
        );

        return {
          valid: false,
          reason: 'Self-signed certificates not allowed',
          errorCode: 'SELF_SIGNED_CERT_NOT_ALLOWED',
        };
      }
    }

    // Check certificate revocation (simplified check)
    if (this.config.certificateRevocationCheck) {
      // In a real implementation, you would check against CRL or OCSP
      // This is a placeholder for demonstration
      if (this.isCertificateRevoked(cert)) {
        this.connectionTracker.recordSecurityEvent(ip, 'revoked_certificate', {
          correlationId,
          serialNumber: cert.serialNumber,
          fingerprint: cert.fingerprint,
        });

        return {
          valid: false,
          reason: 'Certificate has been revoked',
          errorCode: 'CLIENT_CERT_REVOKED',
        };
      }
    }

    this.logger.debug('Client certificate validation successful', {
      correlationId,
      ip,
      subject: cert.subject,
      issuer: cert.issuer,
      validFrom: cert.valid_from,
      validTo: cert.valid_to,
    });

    return { valid: true };
  }

  /**
   * Check if TLS version is valid
   * @param {string} tlsVersion - TLS version
   * @returns {boolean} True if valid
   */
  isValidTLSVersion(tlsVersion) {
    const validVersions = ['TLSv1.2', 'TLSv1.3'];

    if (this.config.minTlsVersion === 'TLSv1.3') {
      return tlsVersion === 'TLSv1.3';
    }

    return validVersions.includes(tlsVersion);
  }

  /**
   * Check if cipher is valid
   * @param {string} cipherName - Cipher name
   * @returns {boolean} True if valid
   */
  isValidCipher(cipherName) {
    if (this.config.allowedCiphers.length === 0) {
      return true; // Allow all if no restrictions
    }

    return this.config.allowedCiphers.some(
      (allowed) => cipherName.includes(allowed) || allowed.includes(cipherName)
    );
  }

  /**
   * Check if certificate is revoked (placeholder implementation)
   * @param {Object} cert - Certificate
   * @returns {boolean} True if revoked
   */
  isCertificateRevoked(_cert) {
    // In a real implementation, this would check against:
    // - Certificate Revocation List (CRL)
    // - Online Certificate Status Protocol (OCSP)
    // - Internal revocation database

    // For now, return false (not revoked)
    return false;
  }

  /**
   * Validate WebSocket origin
   * @param {string} origin - Request origin
   * @param {string} ip - Client IP
   * @returns {boolean} True if valid
   */
  validateWebSocketOrigin(origin, ip) {
    if (!this.config.websocketOriginCheck) {
      return true;
    }

    if (!origin) {
      this.connectionTracker.recordSecurityEvent(ip, 'missing_origin_header', {
        expectedOrigins: this.config.allowedOrigins,
      });
      return false;
    }

    const isAllowed = this.config.allowedOrigins.some((allowed) => {
      if (allowed === '*') {
        return true;
      }
      if (allowed.endsWith('*')) {
        return origin.startsWith(allowed.slice(0, -1));
      }
      return origin === allowed;
    });

    if (!isAllowed) {
      this.connectionTracker.recordSecurityEvent(ip, 'invalid_origin', {
        origin,
        allowedOrigins: this.config.allowedOrigins,
      });
    }

    return isAllowed;
  }

  /**
   * Get security statistics
   * @returns {Object} Security statistics
   */
  getSecurityStats() {
    const stats = {
      connections: {
        total: this.connectionTracker.connections.size,
        suspicious: this.connectionTracker.suspiciousIPs.size,
        blocked: this.connectionTracker.blockedIPs.size,
      },
      securityEvents: {
        total: 0,
        byType: {},
      },
      topSuspiciousIPs: [],
    };

    // Count security events
    for (const events of this.connectionTracker.securityEvents.values()) {
      stats.securityEvents.total += events.length;

      for (const event of events) {
        stats.securityEvents.byType[event.type] =
          (stats.securityEvents.byType[event.type] || 0) + 1;
      }
    }

    // Get top suspicious IPs
    const ipEventCounts = [];
    for (const [
      ip,
      events,
    ] of this.connectionTracker.securityEvents.entries()) {
      ipEventCounts.push({
        ip: this.hashIP(ip),
        eventCount: events.length,
        lastEvent: events[events.length - 1]?.timestamp,
        isSuspicious: this.connectionTracker.isSuspicious(ip),
        isBlocked: this.connectionTracker.isBlocked(ip),
      });
    }

    stats.topSuspiciousIPs = ipEventCounts
      .sort((a, b) => b.eventCount - a.eventCount)
      .slice(0, 10);

    return stats;
  }

  /**
   * Hash IP address for logging (privacy protection)
   * @param {string} ip - IP address
   * @returns {string} Hashed IP
   */
  hashIP(ip) {
    return crypto
      .createHash('sha256')
      .update(ip)
      .digest('hex')
      .substring(0, 16);
  }

  /**
   * Destroy the security manager
   */
  destroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }

    this.logger.info('Connection security manager destroyed');
  }
}

/**
 * Create Express middleware for connection security
 * @param {Object} config - Security configuration
 * @returns {Function} Express middleware
 */
export function createConnectionSecurityMiddleware(config = {}) {
  const securityManager = new ConnectionSecurityManager(config);

  return (req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress;
    const correlationId =
      req.correlationId || securityManager.logger.generateCorrelationId();

    // Check if IP is blocked
    if (securityManager.connectionTracker.isBlocked(ip)) {
      securityManager.logger.logSecurity('blocked_ip_access_attempt', null, {
        correlationId,
        ip: securityManager.hashIP(ip),
        path: req.path,
        userAgent: req.get('User-Agent'),
      });

      return res
        .status(403)
        .json(
          ErrorResponseBuilder.createErrorResponse(
            'IP_BLOCKED',
            'Access denied due to security violations',
            403
          )
        );
    }

    // Add security headers
    Object.entries(securityManager.config.securityHeaders).forEach(
      ([header, value]) => {
        res.setHeader(header, value);
      }
    );

    // Track connection
    securityManager.connectionTracker.trackConnection(ip, {
      userAgent: req.get('User-Agent'),
      protocol: req.protocol,
      tlsVersion: req.socket?.getProtocol?.() || 'unknown',
      cipher: req.socket?.getCipher?.()?.name || 'unknown',
    });

    // Validate TLS connection if available
    if (req.socket && req.socket.encrypted) {
      const tlsValidation = securityManager.validateTLSConnection(
        req.socket,
        ip
      );
      if (!tlsValidation.valid) {
        securityManager.logger.logSecurity('tls_validation_failed', null, {
          correlationId,
          ip: securityManager.hashIP(ip),
          reason: tlsValidation.reason,
          errorCode: tlsValidation.errorCode,
        });

        return res
          .status(400)
          .json(
            ErrorResponseBuilder.createErrorResponse(
              tlsValidation.errorCode,
              tlsValidation.reason,
              400
            )
          );
      }
    }

    // Mark suspicious IPs in request for additional monitoring
    if (securityManager.connectionTracker.isSuspicious(ip)) {
      req.suspiciousIP = true;
      securityManager.logger.warn('Request from suspicious IP', {
        correlationId,
        ip: securityManager.hashIP(ip),
        path: req.path,
        method: req.method,
      });
    }

    next();
  };
}

/**
 * Create WebSocket connection security validator
 * @param {Object} config - Security configuration
 * @returns {Function} WebSocket verifyClient function
 */
export function createWebSocketSecurityValidator(config = {}) {
  const securityManager = new ConnectionSecurityManager(config);

  return (info) => {
    const ip = info.req.socket.remoteAddress;
    const origin = info.req.headers.origin;

    // Check if IP is blocked
    if (securityManager.connectionTracker.isBlocked(ip)) {
      securityManager.logger.logSecurity('blocked_ip_websocket_attempt', null, {
        ip: securityManager.hashIP(ip),
        origin,
      });
      return false;
    }

    // Validate origin
    if (process.env.NODE_ENV === 'production') {
      if (!securityManager.validateWebSocketOrigin(origin, ip)) {
        return false;
      }
    }

    // Validate TLS connection
    if (info.req.socket.encrypted) {
      const tlsValidation = securityManager.validateTLSConnection(
        info.req.socket,
        ip
      );
      if (!tlsValidation.valid) {
        return false;
      }
    }

    return true;
  };
}

export default ConnectionSecurityManager;
