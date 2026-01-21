import winston from 'winston';

/**
 * ProxyDiagnosticsService - Manages proxy diagnostics and troubleshooting
 * Implements log collection, diagnostics endpoints, and troubleshooting information
 * for streaming proxy instances
 * Validates: Requirements 5.7
 */
export class ProxyDiagnosticsService {
  constructor(logger = null) {
    this.logger =
      logger ||
      winston.createLogger({
        level: process.env.LOG_LEVEL || 'info',
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.errors({ stack: true }),
          winston.format.json(),
        ),
        defaultMeta: { service: 'proxy-diagnostics' },
        transports: [
          new winston.transports.Console({
            format: winston.format.combine(
              winston.format.timestamp(),
              winston.format.simple(),
            ),
          }),
        ],
      });

    // Store diagnostic logs per proxy
    this.diagnosticLogs = new Map(); // proxyId -> array of log entries
    this.proxyDiagnosticInfo = new Map(); // proxyId -> diagnostic info
    this.proxyErrorHistory = new Map(); // proxyId -> array of errors
    this.proxyEventHistory = new Map(); // proxyId -> array of events

    // Configuration
    this.maxLogsPerProxy = parseInt(process.env.PROXY_MAX_LOGS || '1000', 10);
    this.maxErrorsPerProxy = parseInt(
      process.env.PROXY_MAX_ERRORS || '100',
      10,
    );
    this.maxEventsPerProxy = parseInt(
      process.env.PROXY_MAX_EVENTS || '500',
      10,
    );
    this.logRetentionMs = parseInt(
      process.env.PROXY_LOG_RETENTION || '3600000',
      10,
    ); // 1 hour default
  }

  /**
   * Register a proxy for diagnostics
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} proxyMetadata - Proxy metadata
   */
  registerProxy(proxyId, proxyMetadata) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    this.diagnosticLogs.set(proxyId, []);
    this.proxyErrorHistory.set(proxyId, []);
    this.proxyEventHistory.set(proxyId, []);

    this.proxyDiagnosticInfo.set(proxyId, {
      proxyId,
      registeredAt: new Date(),
      metadata: proxyMetadata,
      lastDiagnosticCheck: null,
      diagnosticStatus: 'healthy',
    });

    this.logger.info(`Registered proxy for diagnostics: ${proxyId}`, {
      proxyId,
      metadata: proxyMetadata,
    });
  }

  /**
   * Unregister a proxy from diagnostics
   * @param {string} proxyId - Unique proxy identifier
   */
  unregisterProxy(proxyId) {
    this.diagnosticLogs.delete(proxyId);
    this.proxyErrorHistory.delete(proxyId);
    this.proxyEventHistory.delete(proxyId);
    this.proxyDiagnosticInfo.delete(proxyId);

    this.logger.info(`Unregistered proxy from diagnostics: ${proxyId}`, {
      proxyId,
    });
  }

  /**
   * Add a diagnostic log entry
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} logEntry - Log entry object
   */
  addDiagnosticLog(proxyId, logEntry) {
    if (!this.diagnosticLogs.has(proxyId)) {
      this.registerProxy(proxyId, {});
    }

    const logs = this.diagnosticLogs.get(proxyId);
    const entry = {
      timestamp: new Date(),
      level: logEntry.level || 'info',
      message: logEntry.message,
      context: logEntry.context || {},
    };

    logs.push(entry);

    // Maintain max log size
    if (logs.length > this.maxLogsPerProxy) {
      logs.shift();
    }

    // Clean old logs
    this.cleanOldLogs(proxyId);
  }

  /**
   * Add an error to error history
   * @param {string} proxyId - Unique proxy identifier
   * @param {Error} error - Error object
   * @param {Object} context - Additional context
   */
  recordError(proxyId, error, context = {}) {
    if (!this.proxyErrorHistory.has(proxyId)) {
      this.registerProxy(proxyId, {});
    }

    const errors = this.proxyErrorHistory.get(proxyId);
    const errorEntry = {
      timestamp: new Date(),
      message: error.message,
      stack: error.stack,
      code: error.code,
      context,
    };

    errors.push(errorEntry);

    // Maintain max error size
    if (errors.length > this.maxErrorsPerProxy) {
      errors.shift();
    }

    this.logger.warn(`Error recorded for proxy: ${proxyId}`, {
      proxyId,
      error: error.message,
      context,
    });
  }

  /**
   * Record an event for diagnostics
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} eventType - Type of event
   * @param {Object} eventData - Event data
   */
  recordEvent(proxyId, eventType, eventData = {}) {
    if (!this.proxyEventHistory.has(proxyId)) {
      this.registerProxy(proxyId, {});
    }

    const events = this.proxyEventHistory.get(proxyId);
    const event = {
      timestamp: new Date(),
      type: eventType,
      data: eventData,
    };

    events.push(event);

    // Maintain max event size
    if (events.length > this.maxEventsPerProxy) {
      events.shift();
    }

    this.logger.debug(`Event recorded for proxy: ${proxyId}`, {
      proxyId,
      eventType,
      eventData,
    });
  }

  /**
   * Get diagnostic logs for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} options - Query options (limit, level, since)
   * @returns {Array} Array of log entries
   */
  getDiagnosticLogs(proxyId, options = {}) {
    if (!this.diagnosticLogs.has(proxyId)) {
      return [];
    }

    let logs = [...this.diagnosticLogs.get(proxyId)];

    // Filter by level if specified
    if (options.level) {
      logs = logs.filter((log) => log.level === options.level);
    }

    // Filter by time range if specified
    if (options.since) {
      const sinceTime = new Date(options.since);
      logs = logs.filter((log) => new Date(log.timestamp) >= sinceTime);
    }

    // Apply limit
    const limit = options.limit || 100;
    return logs.slice(-limit);
  }

  /**
   * Get error history for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} options - Query options (limit, since)
   * @returns {Array} Array of error entries
   */
  getErrorHistory(proxyId, options = {}) {
    if (!this.proxyErrorHistory.has(proxyId)) {
      return [];
    }

    let errors = [...this.proxyErrorHistory.get(proxyId)];

    // Filter by time range if specified
    if (options.since) {
      const sinceTime = new Date(options.since);
      errors = errors.filter((err) => new Date(err.timestamp) >= sinceTime);
    }

    // Apply limit
    const limit = options.limit || 50;
    return errors.slice(-limit);
  }

  /**
   * Get event history for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} options - Query options (limit, type, since)
   * @returns {Array} Array of event entries
   */
  getEventHistory(proxyId, options = {}) {
    if (!this.proxyEventHistory.has(proxyId)) {
      return [];
    }

    let events = [...this.proxyEventHistory.get(proxyId)];

    // Filter by type if specified
    if (options.type) {
      events = events.filter((evt) => evt.type === options.type);
    }

    // Filter by time range if specified
    if (options.since) {
      const sinceTime = new Date(options.since);
      events = events.filter((evt) => new Date(evt.timestamp) >= sinceTime);
    }

    // Apply limit
    const limit = options.limit || 100;
    return events.slice(-limit);
  }

  /**
   * Get comprehensive diagnostics for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Object} Comprehensive diagnostics object
   */
  getDiagnostics(proxyId) {
    if (!this.proxyDiagnosticInfo.has(proxyId)) {
      return {
        proxyId,
        status: 'unknown',
        message: 'Proxy not registered',
      };
    }

    const diagnosticInfo = this.proxyDiagnosticInfo.get(proxyId);
    const recentLogs = this.getDiagnosticLogs(proxyId, { limit: 50 });
    const recentErrors = this.getErrorHistory(proxyId, { limit: 20 });
    const recentEvents = this.getEventHistory(proxyId, { limit: 50 });

    // Analyze diagnostics
    const diagnosticStatus = this.analyzeDiagnostics(
      proxyId,
      recentErrors,
      recentLogs,
    );

    return {
      proxyId,
      diagnosticStatus,
      registeredAt: diagnosticInfo.registeredAt,
      lastDiagnosticCheck: diagnosticInfo.lastDiagnosticCheck,
      metadata: diagnosticInfo.metadata,
      summary: {
        totalLogs: this.diagnosticLogs.get(proxyId)?.length || 0,
        totalErrors: this.proxyErrorHistory.get(proxyId)?.length || 0,
        totalEvents: this.proxyEventHistory.get(proxyId)?.length || 0,
      },
      recentLogs,
      recentErrors,
      recentEvents,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get troubleshooting information for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Object} Troubleshooting information
   */
  getTroubleshootingInfo(proxyId) {
    if (!this.proxyDiagnosticInfo.has(proxyId)) {
      return {
        proxyId,
        status: 'unknown',
        message: 'Proxy not registered',
      };
    }

    const recentErrors = this.getErrorHistory(proxyId, { limit: 20 });
    const recentEvents = this.getEventHistory(proxyId, { limit: 50 });

    // Generate troubleshooting suggestions
    const suggestions = this.generateTroubleshootingSuggestions(
      proxyId,
      recentErrors,
      recentEvents,
    );

    return {
      proxyId,
      suggestions,
      recentErrors,
      recentEvents,
      commonIssues: this.identifyCommonIssues(proxyId),
      recommendedActions: this.getRecommendedActions(proxyId),
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Analyze diagnostics to determine status
   * @private
   * @param {string} proxyId - Unique proxy identifier
   * @param {Array} recentErrors - Recent errors
   * @param {Array} recentLogs - Recent logs
   * @returns {string} Diagnostic status
   */
  analyzeDiagnostics(_proxyId, recentErrors, _recentLogs) {
    if (recentErrors.length === 0) {
      return 'healthy';
    }

    // Check error frequency
    const errorCount = recentErrors.length;
    if (errorCount > 10) {
      return 'critical';
    } else if (errorCount > 5) {
      return 'unhealthy';
    } else {
      return 'degraded';
    }
  }

  /**
   * Generate troubleshooting suggestions
   * @private
   * @param {string} proxyId - Unique proxy identifier
   * @param {Array} recentErrors - Recent errors
   * @param {Array} recentEvents - Recent events
   * @returns {Array} Array of suggestions
   */
  generateTroubleshootingSuggestions(proxyId, recentErrors, _recentEvents) {
    const suggestions = [];

    if (recentErrors.length === 0) {
      suggestions.push({
        issue: 'No recent errors',
        suggestion: 'Proxy appears to be functioning normally',
        severity: 'info',
      });
      return suggestions;
    }

    // Analyze error patterns - check for lowercase versions too
    const errorMessages = recentErrors.map((e) => e.message.toLowerCase());
    const errorCounts = {};

    errorMessages.forEach((msg) => {
      errorCounts[msg] = (errorCounts[msg] || 0) + 1;
    });

    // Track which suggestions we've already added
    const addedSuggestions = new Set();

    // Generate suggestions based on error patterns
    Object.entries(errorCounts).forEach(([message, count]) => {
      if (message.includes('timeout') && !addedSuggestions.has('timeout')) {
        suggestions.push({
          issue: 'Timeout errors detected',
          suggestion:
            'Check network connectivity and increase timeout settings if needed',
          severity: 'warning',
          frequency: count,
        });
        addedSuggestions.add('timeout');
      } else if (
        message.includes('connection') &&
        !addedSuggestions.has('connection')
      ) {
        suggestions.push({
          issue: 'Connection errors detected',
          suggestion:
            'Verify proxy endpoint is reachable and firewall rules are correct',
          severity: 'warning',
          frequency: count,
        });
        addedSuggestions.add('connection');
      } else if (
        message.includes('memory') &&
        !addedSuggestions.has('memory')
      ) {
        suggestions.push({
          issue: 'Memory-related errors detected',
          suggestion:
            'Consider increasing proxy memory allocation or restarting the proxy',
          severity: 'critical',
          frequency: count,
        });
        addedSuggestions.add('memory');
      } else if (
        message.includes('authentication') &&
        !addedSuggestions.has('authentication')
      ) {
        suggestions.push({
          issue: 'Authentication errors detected',
          suggestion: 'Verify credentials and authentication configuration',
          severity: 'warning',
          frequency: count,
        });
        addedSuggestions.add('authentication');
      }
    });

    return suggestions;
  }

  /**
   * Identify common issues
   * @private
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Array} Array of common issues
   */
  identifyCommonIssues(proxyId) {
    const issues = [];
    const errors = this.getErrorHistory(proxyId, { limit: 100 });

    if (errors.length === 0) {
      return issues;
    }

    // Check for connection issues (case-insensitive)
    const connectionErrors = errors.filter((e) =>
      e.message.toLowerCase().includes('connection'),
    );
    if (connectionErrors.length > 5) {
      issues.push({
        type: 'connection',
        description: 'Frequent connection errors',
        count: connectionErrors.length,
      });
    }

    // Check for timeout issues (case-insensitive)
    const timeoutErrors = errors.filter((e) =>
      e.message.toLowerCase().includes('timeout'),
    );
    if (timeoutErrors.length > 5) {
      issues.push({
        type: 'timeout',
        description: 'Frequent timeout errors',
        count: timeoutErrors.length,
      });
    }

    // Check for resource issues (case-insensitive)
    const resourceErrors = errors.filter(
      (e) =>
        e.message.toLowerCase().includes('memory') ||
        e.message.toLowerCase().includes('resource'),
    );
    if (resourceErrors.length > 3) {
      issues.push({
        type: 'resource',
        description: 'Resource constraint issues',
        count: resourceErrors.length,
      });
    }

    return issues;
  }

  /**
   * Get recommended actions
   * @private
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Array} Array of recommended actions
   */
  getRecommendedActions(proxyId) {
    const actions = [];
    const issues = this.identifyCommonIssues(proxyId);

    issues.forEach((issue) => {
      switch (issue.type) {
        case 'connection':
          actions.push({
            action: 'Check network connectivity',
            steps: [
              'Verify proxy endpoint is reachable',
              'Check firewall rules',
              'Verify DNS resolution',
              'Check proxy logs for connection details',
            ],
          });
          break;
        case 'timeout':
          actions.push({
            action: 'Increase timeout settings',
            steps: [
              'Review current timeout configuration',
              'Increase timeout values if appropriate',
              'Check for slow network conditions',
              'Monitor proxy performance metrics',
            ],
          });
          break;
        case 'resource':
          actions.push({
            action: 'Address resource constraints',
            steps: [
              'Check proxy memory usage',
              'Consider increasing allocated resources',
              'Restart proxy if necessary',
              'Monitor resource usage over time',
            ],
          });
          break;
        default:
          break;
      }
    });

    return actions;
  }

  /**
   * Clean old logs based on retention policy
   * @private
   * @param {string} proxyId - Unique proxy identifier
   */
  cleanOldLogs(proxyId) {
    if (!this.diagnosticLogs.has(proxyId)) {
      return;
    }

    const logs = this.diagnosticLogs.get(proxyId);
    const cutoffTime = Date.now() - this.logRetentionMs;

    const filteredLogs = logs.filter(
      (log) => new Date(log.timestamp).getTime() > cutoffTime,
    );

    if (filteredLogs.length < logs.length) {
      this.diagnosticLogs.set(proxyId, filteredLogs);
    }
  }

  /**
   * Export diagnostics data
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Object} Complete diagnostics export
   */
  exportDiagnostics(proxyId) {
    return {
      proxyId,
      exportedAt: new Date().toISOString(),
      diagnostics: this.getDiagnostics(proxyId),
      troubleshooting: this.getTroubleshootingInfo(proxyId),
      allLogs: this.getDiagnosticLogs(proxyId, { limit: this.maxLogsPerProxy }),
      allErrors: this.getErrorHistory(proxyId, {
        limit: this.maxErrorsPerProxy,
      }),
      allEvents: this.getEventHistory(proxyId, {
        limit: this.maxEventsPerProxy,
      }),
    };
  }

  /**
   * Clear diagnostics for a proxy
   * @param {string} proxyId - Unique proxy identifier
   */
  clearDiagnostics(proxyId) {
    this.diagnosticLogs.set(proxyId, []);
    this.proxyErrorHistory.set(proxyId, []);
    this.proxyEventHistory.set(proxyId, []);

    if (this.proxyDiagnosticInfo.has(proxyId)) {
      const info = this.proxyDiagnosticInfo.get(proxyId);
      info.lastDiagnosticCheck = new Date();
    }

    this.logger.info(`Cleared diagnostics for proxy: ${proxyId}`, {
      proxyId,
    });
  }

  /**
   * Shutdown diagnostics service
   */
  shutdown() {
    this.diagnosticLogs.clear();
    this.proxyErrorHistory.clear();
    this.proxyEventHistory.clear();
    this.proxyDiagnosticInfo.clear();

    this.logger.info('Proxy diagnostics service shutdown complete');
  }
}

export default ProxyDiagnosticsService;
