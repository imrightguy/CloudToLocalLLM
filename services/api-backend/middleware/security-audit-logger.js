/**
 * @fileoverview Security audit logging middleware
 * Comprehensive logging for authentication, authorization, and security events
 */

import winston from 'winston';
import crypto from 'crypto';
import { TunnelLogger } from '../utils/logger.js';

/**
 * Security audit event types
 */
export const AUDIT_EVENT_TYPES = {
  // Authentication events
  AUTH_SUCCESS: 'auth_success',
  AUTH_FAILURE: 'auth_failure',
  AUTH_TOKEN_EXPIRED: 'auth_token_expired',
  AUTH_TOKEN_INVALID: 'auth_token_invalid',
  AUTH_TOKEN_MISSING: 'auth_token_missing',
  AUTH_RATE_LIMITED: 'auth_rate_limited',

  // Authorization events
  AUTHZ_SUCCESS: 'authz_success',
  AUTHZ_FAILURE: 'authz_failure',
  AUTHZ_INSUFFICIENT_PERMISSIONS: 'authz_insufficient_permissions',
  AUTHZ_CROSS_USER_ACCESS_ATTEMPT: 'authz_cross_user_access_attempt',

  // Connection events
  CONNECTION_ESTABLISHED: 'connection_established',
  CONNECTION_TERMINATED: 'connection_terminated',
  CONNECTION_REJECTED: 'connection_rejected',
  WEBSOCKET_CONNECTION_ESTABLISHED: 'websocket_connection_established',
  WEBSOCKET_CONNECTION_TERMINATED: 'websocket_connection_terminated',

  // Security events
  SECURITY_VIOLATION: 'security_violation',
  SUSPICIOUS_ACTIVITY: 'suspicious_activity',
  RATE_LIMIT_EXCEEDED: 'rate_limit_exceeded',
  IP_BLOCKED: 'ip_blocked',
  MALICIOUS_REQUEST: 'malicious_request',

  // TLS/SSL events
  TLS_HANDSHAKE_SUCCESS: 'tls_handshake_success',
  TLS_HANDSHAKE_FAILURE: 'tls_handshake_failure',
  CERTIFICATE_VALIDATION_SUCCESS: 'certificate_validation_success',
  CERTIFICATE_VALIDATION_FAILURE: 'certificate_validation_failure',

  // Data access events
  DATA_ACCESS: 'data_access',
  DATA_MODIFICATION: 'data_modification',
  SENSITIVE_DATA_ACCESS: 'sensitive_data_access',

  // Administrative events
  ADMIN_ACCESS: 'admin_access',
  ADMIN_ACTION: 'admin_action',
  CONFIG_CHANGE: 'config_change',

  // Error events
  SYSTEM_ERROR: 'system_error',
  SECURITY_ERROR: 'security_error',
};

/**
 * Security audit severity levels
 */
export const AUDIT_SEVERITY = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  CRITICAL: 'critical',
};

/**
 * Security audit logger class
 */
export class SecurityAuditLogger {
  constructor(config = {}) {
    this.config = {
      // Logging configuration
      logLevel: config.logLevel || 'info',
      enableConsoleOutput: config.enableConsoleOutput !== false,
      enableFileOutput: config.enableFileOutput || false,
      auditLogFile: config.auditLogFile || 'security-audit.log',

      // Data retention
      maxLogAge: config.maxLogAge || 90, // days
      maxLogSize: config.maxLogSize || '100MB',

      // Privacy settings
      hashUserIds: config.hashUserIds !== false,
      hashIpAddresses: config.hashIpAddresses !== false,
      includeUserAgent: config.includeUserAgent !== false,
      includeRequestHeaders: config.includeRequestHeaders || false,

      // Alert settings
      enableRealTimeAlerts: config.enableRealTimeAlerts || false,
      alertThresholds: {
        failedAuthAttempts: config.alertThresholds?.failedAuthAttempts || 10,
        suspiciousActivity: config.alertThresholds?.suspiciousActivity || 5,
        rateLimitViolations: config.alertThresholds?.rateLimitViolations || 20,
      },

      // Compliance settings
      includeComplianceFields: config.includeComplianceFields || false,
      complianceStandards: config.complianceStandards || ['SOC2', 'GDPR'],
    };

    // Initialize Winston logger for audit events
    this.auditLogger = winston.createLogger({
      level: this.config.logLevel,
      format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
        winston.format.errors({ stack: true }),
        winston.format.json(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          const auditEntry = {
            timestamp,
            level,
            message,
            eventType: 'security_audit',
            ...meta,
          };
          return JSON.stringify(auditEntry);
        })
      ),
      transports: [],
    });

    // Add console transport if enabled
    if (this.config.enableConsoleOutput) {
      this.auditLogger.add(
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
            winston.format.colorize(),
            winston.format.printf(
              ({ timestamp, level, message, severity, userId, ip }) => {
                const userStr = userId ? ` [user:${userId}]` : '';
                const ipStr = ip ? ` [ip:${ip}]` : '';
                const severityStr = severity
                  ? ` [${severity.toUpperCase()}]`
                  : '';
                return `${timestamp} ${level}: [AUDIT]${severityStr}${userStr}${ipStr} ${message}`;
              }
            )
          ),
        })
      );
    }

    // Add file transport if enabled
    if (this.config.enableFileOutput) {
      this.auditLogger.add(
        new winston.transports.File({
          filename: this.config.auditLogFile,
          maxsize: this.parseSize(this.config.maxLogSize),
          maxFiles: 10,
          tailable: true,
        })
      );
    }

    // Initialize base logger for non-audit logging
    this.logger = new TunnelLogger('security-audit');

    // Event counters for alerting
    this.eventCounters = new Map();
    this.alertHistory = [];

    // Start cleanup interval
    this.cleanupInterval = setInterval(
      () => {
        this.cleanupEventCounters();
      },
      60 * 60 * 1000
    ); // Every hour

    this.logger.info('Security audit logger initialized', {
      logLevel: this.config.logLevel,
      enableConsoleOutput: this.config.enableConsoleOutput,
      enableFileOutput: this.config.enableFileOutput,
      hashUserIds: this.config.hashUserIds,
      hashIpAddresses: this.config.hashIpAddresses,
    });
  }

  /**
   * Log security audit event
   * @param {string} eventType - Event type from AUDIT_EVENT_TYPES
   * @param {string} severity - Severity level from AUDIT_SEVERITY
   * @param {string} message - Human-readable message
   * @param {Object} context - Event context
   */
  logAuditEvent(eventType, severity, message, context = {}) {
    const correlationId = context.correlationId || this.generateCorrelationId();
    const timestamp = new Date();

    // Prepare audit entry
    const auditEntry = {
      correlationId,
      eventType,
      severity,
      message,
      timestamp: timestamp.toISOString(),

      // User context (with privacy protection)
      userId: context.userId ? this.hashUserId(context.userId) : null,
      userEmail: context.userEmail ? this.hashEmail(context.userEmail) : null,
      userRole: context.userRole || null,

      // Network context (with privacy protection)
      ip: context.ip ? this.hashIP(context.ip) : null,
      userAgent: this.config.includeUserAgent ? context.userAgent : null,
      origin: context.origin || null,

      // Request context
      method: context.method || null,
      path: context.path || null,
      statusCode: context.statusCode || null,
      responseTime: context.responseTime || null,

      // Security context
      authMethod: context.authMethod || null,
      tokenType: context.tokenType || null,
      tlsVersion: context.tlsVersion || null,
      cipher: context.cipher || null,

      // Error context
      errorCode: context.errorCode || null,
      errorMessage: context.errorMessage || null,

      // Additional metadata
      sessionId: context.sessionId || null,
      requestId: context.requestId || null,
      resource: context.resource || null,
      action: context.action || null,

      // Compliance fields
      ...(this.config.includeComplianceFields && {
        complianceStandards: this.config.complianceStandards,
        dataClassification: context.dataClassification || 'internal',
        retentionPeriod: context.retentionPeriod || '90d',
      }),

      // Request headers (if enabled and sanitized)
      ...(this.config.includeRequestHeaders &&
        context.headers && {
          headers: this.sanitizeHeaders(context.headers),
        }),
    };

    // Log the audit event
    this.auditLogger.info(message, auditEntry);

    // Update event counters for alerting
    this.updateEventCounters(eventType, severity, context.ip, context.userId);

    // Check for alert conditions
    if (this.config.enableRealTimeAlerts) {
      this.checkAlertConditions(eventType, severity, context);
    }

    // Log to base logger for debugging
    this.logger.debug('Security audit event logged', {
      correlationId,
      eventType,
      severity,
      userId: context.userId ? this.hashUserId(context.userId) : null,
    });
  }

  /**
   * Log authentication success
   * @param {Object} context - Authentication context
   */
  logAuthSuccess(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.AUTH_SUCCESS,
      AUDIT_SEVERITY.LOW,
      'User authentication successful',
      {
        ...context,
        authMethod: context.authMethod || 'jwt',
        tokenType: context.tokenType || 'bearer',
      }
    );
  }

  /**
   * Log authentication failure
   * @param {Object} context - Authentication context
   */
  logAuthFailure(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.AUTH_FAILURE,
      AUDIT_SEVERITY.MEDIUM,
      'User authentication failed',
      {
        ...context,
        authMethod: context.authMethod || 'jwt',
        tokenType: context.tokenType || 'bearer',
      }
    );
  }

  /**
   * Log authorization success
   * @param {Object} context - Authorization context
   */
  logAuthzSuccess(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.AUTHZ_SUCCESS,
      AUDIT_SEVERITY.LOW,
      'User authorization successful',
      {
        ...context,
        resource: context.resource || context.path,
        action: context.action || context.method,
      }
    );
  }

  /**
   * Log authorization failure
   * @param {Object} context - Authorization context
   */
  logAuthzFailure(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.AUTHZ_FAILURE,
      AUDIT_SEVERITY.HIGH,
      'User authorization failed',
      {
        ...context,
        resource: context.resource || context.path,
        action: context.action || context.method,
      }
    );
  }

  /**
   * Log cross-user access attempt
   * @param {Object} context - Access attempt context
   */
  logCrossUserAccessAttempt(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.AUTHZ_CROSS_USER_ACCESS_ATTEMPT,
      AUDIT_SEVERITY.HIGH,
      'Cross-user access attempt detected',
      {
        ...context,
        requestedUserId: context.requestedUserId
          ? this.hashUserId(context.requestedUserId)
          : null,
        actualUserId: context.actualUserId
          ? this.hashUserId(context.actualUserId)
          : null,
      }
    );
  }

  /**
   * Log security violation
   * @param {Object} context - Security violation context
   */
  logSecurityViolation(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.SECURITY_VIOLATION,
      AUDIT_SEVERITY.CRITICAL,
      'Security violation detected',
      context
    );
  }

  /**
   * Log suspicious activity
   * @param {Object} context - Suspicious activity context
   */
  logSuspiciousActivity(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.SUSPICIOUS_ACTIVITY,
      AUDIT_SEVERITY.HIGH,
      'Suspicious activity detected',
      context
    );
  }

  /**
   * Log rate limit exceeded
   * @param {Object} context - Rate limit context
   */
  logRateLimitExceeded(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.RATE_LIMIT_EXCEEDED,
      AUDIT_SEVERITY.MEDIUM,
      'Rate limit exceeded',
      {
        ...context,
        limitType: context.limitType || 'request',
        limitValue: context.limitValue || null,
        currentValue: context.currentValue || null,
      }
    );
  }

  /**
   * Log data access
   * @param {Object} context - Data access context
   */
  logDataAccess(context) {
    const severity = context.sensitive
      ? AUDIT_SEVERITY.MEDIUM
      : AUDIT_SEVERITY.LOW;
    const eventType = context.sensitive
      ? AUDIT_EVENT_TYPES.SENSITIVE_DATA_ACCESS
      : AUDIT_EVENT_TYPES.DATA_ACCESS;

    this.logAuditEvent(eventType, severity, 'Data access event', {
      ...context,
      dataType: context.dataType || 'unknown',
      dataClassification: context.dataClassification || 'internal',
    });
  }

  /**
   * Log admin access
   * @param {Object} context - Admin access context
   */
  logAdminAccess(context) {
    this.logAuditEvent(
      AUDIT_EVENT_TYPES.ADMIN_ACCESS,
      AUDIT_SEVERITY.HIGH,
      'Administrative access granted',
      {
        ...context,
        adminAction: context.adminAction || 'access',
        targetResource: context.targetResource || null,
      }
    );
  }

  /**
   * Hash user ID for privacy protection
   * @param {string} userId - User ID
   * @returns {string} Hashed user ID
   */
  hashUserId(userId) {
    if (!this.config.hashUserIds || !userId) {
      return userId;
    }

    // Keep first 8 characters + hash for debugging while protecting privacy
    const hash = crypto.createHash('sha256').update(userId).digest('hex');
    return `${userId.substring(0, 8)}...${hash.substring(0, 8)}`;
  }

  /**
   * Hash email for privacy protection
   * @param {string} email - Email address
   * @returns {string} Hashed email
   */
  hashEmail(email) {
    if (!this.config.hashUserIds || !email) {
      return email;
    }

    const [local, domain] = email.split('@');
    const hash = crypto.createHash('sha256').update(email).digest('hex');
    return `${local.substring(0, 2)}...@${domain}[${hash.substring(0, 8)}]`;
  }

  /**
   * Hash IP address for privacy protection
   * @param {string} ip - IP address
   * @returns {string} Hashed IP
   */
  hashIP(ip) {
    if (!this.config.hashIpAddresses || !ip) {
      return ip;
    }

    const hash = crypto.createHash('sha256').update(ip).digest('hex');
    return `${ip.split('.')[0]}.xxx.xxx.xxx[${hash.substring(0, 8)}]`;
  }

  /**
   * Sanitize request headers for logging
   * @param {Object} headers - Request headers
   * @returns {Object} Sanitized headers
   */
  sanitizeHeaders(headers) {
    const sensitiveHeaders = [
      'authorization',
      'cookie',
      'x-api-key',
      'x-auth-token',
      'x-access-token',
    ];

    const sanitized = {};

    for (const [key, value] of Object.entries(headers)) {
      const lowerKey = key.toLowerCase();

      if (sensitiveHeaders.includes(lowerKey)) {
        sanitized[key] = '[REDACTED]';
      } else if (lowerKey === 'user-agent') {
        // Truncate user agent to prevent log injection
        sanitized[key] = value ? value.substring(0, 200) : value;
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  /**
   * Update event counters for alerting
   * @param {string} eventType - Event type
   * @param {string} severity - Event severity
   * @param {string} ip - Client IP
   * @param {string} userId - User ID
   */
  updateEventCounters(eventType, severity, ip, userId) {
    const now = new Date();
    const windowStart = new Date(now.getTime() - 60 * 60 * 1000); // 1 hour window

    // Initialize counters if needed
    if (!this.eventCounters.has('global')) {
      this.eventCounters.set('global', []);
    }

    if (ip && !this.eventCounters.has(`ip:${ip}`)) {
      this.eventCounters.set(`ip:${ip}`, []);
    }

    if (userId && !this.eventCounters.has(`user:${userId}`)) {
      this.eventCounters.set(`user:${userId}`, []);
    }

    // Add event to counters
    const eventData = { eventType, severity, timestamp: now };

    this.eventCounters.get('global').push(eventData);

    if (ip) {
      this.eventCounters.get(`ip:${ip}`).push(eventData);
    }

    if (userId) {
      this.eventCounters.get(`user:${userId}`).push(eventData);
    }

    // Clean up old events
    for (const [key, events] of this.eventCounters.entries()) {
      this.eventCounters.set(
        key,
        events.filter((event) => event.timestamp > windowStart)
      );
    }
  }

  /**
   * Check alert conditions
   * @param {string} eventType - Event type
   * @param {string} severity - Event severity
   * @param {Object} context - Event context
   */
  checkAlertConditions(eventType, severity, context) {
    const ip = context.ip;

    // Check failed authentication attempts
    if (eventType === AUDIT_EVENT_TYPES.AUTH_FAILURE) {
      const ipEvents = this.eventCounters.get(`ip:${ip}`) || [];
      const failedAuths = ipEvents.filter(
        (event) => event.eventType === AUDIT_EVENT_TYPES.AUTH_FAILURE
      ).length;

      if (failedAuths >= this.config.alertThresholds.failedAuthAttempts) {
        this.generateAlert('EXCESSIVE_AUTH_FAILURES', {
          ip: this.hashIP(ip),
          failedAttempts: failedAuths,
          threshold: this.config.alertThresholds.failedAuthAttempts,
        });
      }
    }

    // Check suspicious activity
    if (
      severity === AUDIT_SEVERITY.HIGH ||
      severity === AUDIT_SEVERITY.CRITICAL
    ) {
      const ipEvents = this.eventCounters.get(`ip:${ip}`) || [];
      const suspiciousEvents = ipEvents.filter(
        (event) =>
          event.severity === AUDIT_SEVERITY.HIGH ||
          event.severity === AUDIT_SEVERITY.CRITICAL
      ).length;

      if (suspiciousEvents >= this.config.alertThresholds.suspiciousActivity) {
        this.generateAlert('SUSPICIOUS_ACTIVITY_PATTERN', {
          ip: this.hashIP(ip),
          suspiciousEvents,
          threshold: this.config.alertThresholds.suspiciousActivity,
        });
      }
    }

    // Check rate limit violations
    if (eventType === AUDIT_EVENT_TYPES.RATE_LIMIT_EXCEEDED) {
      const ipEvents = this.eventCounters.get(`ip:${ip}`) || [];
      const rateLimitEvents = ipEvents.filter(
        (event) => event.eventType === AUDIT_EVENT_TYPES.RATE_LIMIT_EXCEEDED
      ).length;

      if (rateLimitEvents >= this.config.alertThresholds.rateLimitViolations) {
        this.generateAlert('EXCESSIVE_RATE_LIMIT_VIOLATIONS', {
          ip: this.hashIP(ip),
          violations: rateLimitEvents,
          threshold: this.config.alertThresholds.rateLimitViolations,
        });
      }
    }
  }

  /**
   * Generate security alert
   * @param {string} alertType - Alert type
   * @param {Object} alertData - Alert data
   */
  generateAlert(alertType, alertData) {
    const alert = {
      alertType,
      timestamp: new Date().toISOString(),
      severity: AUDIT_SEVERITY.CRITICAL,
      data: alertData,
    };

    this.alertHistory.push(alert);

    // Keep only recent alerts (last 100)
    if (this.alertHistory.length > 100) {
      this.alertHistory = this.alertHistory.slice(-100);
    }

    // Log the alert
    this.auditLogger.error('Security alert generated', {
      eventType: 'security_alert',
      alertType,
      severity: AUDIT_SEVERITY.CRITICAL,
      ...alertData,
    });

    // In a real implementation, you would send alerts to:
    // - Security team via email/Slack
    // - SIEM system
    // - Monitoring dashboard
    // - Incident response system
  }

  /**
   * Clean up old event counters
   */
  cleanupEventCounters() {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours

    for (const [key, events] of this.eventCounters.entries()) {
      const recentEvents = events.filter((event) => event.timestamp > cutoff);

      if (recentEvents.length === 0) {
        this.eventCounters.delete(key);
      } else {
        this.eventCounters.set(key, recentEvents);
      }
    }
  }

  /**
   * Parse size string to bytes
   * @param {string} sizeStr - Size string (e.g., '100MB')
   * @returns {number} Size in bytes
   */
  parseSize(sizeStr) {
    const units = { B: 1, KB: 1024, MB: 1024 * 1024, GB: 1024 * 1024 * 1024 };
    const match = sizeStr.match(/^(\d+)([A-Z]{1,2})$/);

    if (!match) {
      return 100 * 1024 * 1024; // Default 100MB
    }

    const [, size, unit] = match;
    return parseInt(size) * (units[unit] || 1);
  }

  /**
   * Generate correlation ID
   * @returns {string} Correlation ID
   */
  generateCorrelationId() {
    return crypto.randomUUID();
  }

  /**
   * Get audit statistics
   * @returns {Object} Audit statistics
   */
  getAuditStats() {
    const stats = {
      eventCounters: {},
      alerts: {
        total: this.alertHistory.length,
        recent: this.alertHistory.filter(
          (alert) =>
            Date.now() - new Date(alert.timestamp).getTime() <
            24 * 60 * 60 * 1000
        ).length,
      },
      config: {
        logLevel: this.config.logLevel,
        enableConsoleOutput: this.config.enableConsoleOutput,
        enableFileOutput: this.config.enableFileOutput,
        hashUserIds: this.config.hashUserIds,
        hashIpAddresses: this.config.hashIpAddresses,
      },
    };

    // Count events by type
    for (const [key, events] of this.eventCounters.entries()) {
      stats.eventCounters[key] = {
        total: events.length,
        byType: {},
      };

      for (const event of events) {
        stats.eventCounters[key].byType[event.eventType] =
          (stats.eventCounters[key].byType[event.eventType] || 0) + 1;
      }
    }

    return stats;
  }

  /**
   * Destroy the audit logger
   */
  destroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }

    this.auditLogger.close();
    this.logger.info('Security audit logger destroyed');
  }
}

/**
 * Create Express middleware for security audit logging
 * @param {Object} config - Audit logger configuration
 * @returns {Function} Express middleware
 */
export function createSecurityAuditMiddleware(config = {}) {
  const auditLogger = new SecurityAuditLogger(config);

  return (req, res, next) => {
    const startTime = Date.now();

    // Store audit logger in request for use by other middleware
    req.auditLogger = auditLogger;

    // Override res.end to capture response details
    const originalEnd = res.end;
    res.end = function (...args) {
      const responseTime = Date.now() - startTime;

      // Log successful request completion
      if (req.user && res.statusCode < 400) {
        auditLogger.logDataAccess({
          correlationId: req.correlationId,
          userId: req.user.sub,
          userEmail: req.user.email,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          method: req.method,
          path: req.path,
          statusCode: res.statusCode,
          responseTime,
          resource: req.path,
          action: req.method.toLowerCase(),
          sensitive:
            req.path.includes('/admin') || req.path.includes('/sensitive'),
        });
      }

      originalEnd.apply(this, args);
    };

    next();
  };
}

export default SecurityAuditLogger;
