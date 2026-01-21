/**
 * Error Notification Service
 *
 * Implements critical error detection and notification mechanisms.
 * Provides notification configuration and delivery for critical issues.
 *
 * Requirement 7.9: THE API SHALL support error notifications for critical issues
 */

import winston from 'winston';
import EventEmitter from 'events';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'error-notification' },
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
 * Error severity levels
 */
export const ErrorSeverity = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  CRITICAL: 'critical',
};

/**
 * Error categories for classification
 */
export const ErrorCategory = {
  DATABASE: 'database',
  AUTHENTICATION: 'authentication',
  SERVICE: 'service',
  EXTERNAL_API: 'external_api',
  RESOURCE: 'resource',
  SYSTEM: 'system',
  UNKNOWN: 'unknown',
};

/**
 * Notification channels
 */
export const NotificationChannel = {
  EMAIL: 'email',
  SLACK: 'slack',
  WEBHOOK: 'webhook',
  LOG: 'log',
  SENTRY: 'sentry',
};

/**
 * Error Notification Service
 * Manages critical error detection and notifications
 */
export class ErrorNotificationService extends EventEmitter {
  constructor(config = {}) {
    super();

    // Configuration
    this.config = {
      enableNotifications: config.enableNotifications !== false,
      notificationChannels: config.notificationChannels || [
        NotificationChannel.LOG,
      ],
      criticalErrorThreshold: config.criticalErrorThreshold || 5, // errors per minute
      notificationCooldown: config.notificationCooldown || 60000, // 1 minute
      maxNotificationQueueSize: config.maxNotificationQueueSize || 1000,
      ...config,
    };

    // Notification handlers
    this.notificationHandlers = new Map();

    // Error tracking
    this.errorHistory = [];
    this.errorCounts = new Map(); // Track errors by category
    this.lastNotificationTime = new Map(); // Track last notification time per category

    // Metrics
    this.metrics = {
      totalErrorsDetected: 0,
      criticalErrorsDetected: 0,
      notificationsSent: 0,
      notificationsFailed: 0,
      averageNotificationTime: 0,
      notificationTimes: [],
    };

    // Notification queue
    this.notificationQueue = [];
    this.isProcessingQueue = false;

    // Initialize default handlers
    this._initializeDefaultHandlers();
  }

  /**
   * Initialize default notification handlers
   * @private
   */
  _initializeDefaultHandlers() {
    // Log handler (always available)
    this.registerNotificationHandler(
      NotificationChannel.LOG,
      async (notification) => {
        logger.error('Critical error notification', {
          errorId: notification.errorId,
          category: notification.category,
          severity: notification.severity,
          message: notification.message,
          timestamp: notification.timestamp,
        });
      },
    );

    // Webhook handler (if configured)
    if (this.config.webhookUrl) {
      this.registerNotificationHandler(
        NotificationChannel.WEBHOOK,
        async (notification) => {
          try {
            const response = await fetch(this.config.webhookUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${this.config.webhookToken || ''}`,
              },
              body: JSON.stringify(notification),
              timeout: 5000,
            });

            if (!response.ok) {
              throw new Error(`Webhook returned status ${response.status}`);
            }
          } catch (error) {
            logger.error('Failed to send webhook notification', {
              error: error.message,
              webhookUrl: this.config.webhookUrl,
            });
            throw error;
          }
        },
      );
    }

    // Email handler (if configured)
    if (this.config.emailService) {
      this.registerNotificationHandler(
        NotificationChannel.EMAIL,
        async (notification) => {
          try {
            await this.config.emailService.sendCriticalErrorNotification(
              notification,
            );
          } catch (error) {
            logger.error('Failed to send email notification', {
              error: error.message,
            });
            throw error;
          }
        },
      );
    }

    // Slack handler (if configured)
    if (this.config.slackWebhook) {
      this.registerNotificationHandler(
        NotificationChannel.SLACK,
        async (notification) => {
          try {
            const message = {
              text: `🚨 Critical Error: ${notification.message}`,
              attachments: [
                {
                  color: this._getSeverityColor(notification.severity),
                  fields: [
                    {
                      title: 'Error ID',
                      value: notification.errorId,
                      short: true,
                    },
                    {
                      title: 'Category',
                      value: notification.category,
                      short: true,
                    },
                    {
                      title: 'Severity',
                      value: notification.severity,
                      short: true,
                    },
                    {
                      title: 'Timestamp',
                      value: notification.timestamp,
                      short: true,
                    },
                    {
                      title: 'Details',
                      value: notification.details || 'N/A',
                      short: false,
                    },
                  ],
                },
              ],
            };

            const response = await fetch(this.config.slackWebhook, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(message),
              timeout: 5000,
            });

            if (!response.ok) {
              throw new Error(
                `Slack webhook returned status ${response.status}`,
              );
            }
          } catch (error) {
            logger.error('Failed to send Slack notification', {
              error: error.message,
            });
            throw error;
          }
        },
      );
    }
  }

  /**
   * Get color for severity level (for Slack)
   * @private
   * @param {string} severity - Severity level
   * @returns {string} - Color code
   */
  _getSeverityColor(severity) {
    const colors = {
      [ErrorSeverity.LOW]: '#36a64f',
      [ErrorSeverity.MEDIUM]: '#ff9900',
      [ErrorSeverity.HIGH]: '#ff6600',
      [ErrorSeverity.CRITICAL]: '#ff0000',
    };
    return colors[severity] || '#999999';
  }

  /**
   * Register a notification handler for a channel
   * @param {string} channel - Notification channel
   * @param {Function} handler - Handler function
   */
  registerNotificationHandler(channel, handler) {
    if (typeof handler !== 'function') {
      throw new Error('Handler must be a function');
    }
    this.notificationHandlers.set(channel, handler);
    logger.info(`Notification handler registered for channel: ${channel}`);
  }

  /**
   * Detect critical error and send notifications
   * @param {Object} error - Error object
   * @param {Object} context - Error context
   * @returns {Promise<Object>} - Notification result
   */
  async detectAndNotify(error, context = {}) {
    const errorId = `error-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const timestamp = new Date().toISOString();

    try {
      // Categorize error
      const category = this._categorizeError(error);
      const severity = this._determineSeverity(error, category);

      // Track error
      this.metrics.totalErrorsDetected++;
      if (severity === ErrorSeverity.CRITICAL) {
        this.metrics.criticalErrorsDetected++;
      }

      // Update error counts
      const currentCount = this.errorCounts.get(category) || 0;
      this.errorCounts.set(category, currentCount + 1);

      // Add to history
      this._addToHistory({
        errorId,
        category,
        severity,
        message: error.message,
        timestamp,
        context,
      });

      // Check if notification should be sent
      const shouldNotify = this._shouldSendNotification(category, severity);

      if (!shouldNotify) {
        logger.debug(
          'Error detected but notification not sent (cooldown or low severity)',
          {
            errorId,
            category,
            severity,
          },
        );
        return {
          errorId,
          notificationSent: false,
          reason: 'Cooldown or low severity',
        };
      }

      // Create notification
      const notification = {
        errorId,
        category,
        severity,
        message: error.message,
        timestamp,
        details: error.stack || error.toString(),
        context,
      };

      // Queue notification
      await this._queueNotification(notification);

      logger.info('Critical error notification queued', {
        errorId,
        category,
        severity,
      });

      return {
        errorId,
        notificationSent: true,
        notification,
      };
    } catch (notificationError) {
      logger.error('Error in detectAndNotify', {
        errorId,
        error: notificationError.message,
      });
      throw notificationError;
    }
  }

  /**
   * Categorize error based on type and message
   * @private
   * @param {Error} error - Error object
   * @returns {string} - Error category
   */
  _categorizeError(error) {
    const message = error.message?.toLowerCase() || '';
    const name = error.name?.toLowerCase() || '';

    if (message.includes('database') || name.includes('database')) {
      return ErrorCategory.DATABASE;
    }
    if (message.includes('auth') || name.includes('auth')) {
      return ErrorCategory.AUTHENTICATION;
    }
    if (message.includes('service') || name.includes('service')) {
      return ErrorCategory.SERVICE;
    }
    if (
      message.includes('api') ||
      message.includes('fetch') ||
      message.includes('http')
    ) {
      return ErrorCategory.EXTERNAL_API;
    }
    if (message.includes('memory') || message.includes('resource')) {
      return ErrorCategory.RESOURCE;
    }
    if (message.includes('system') || name.includes('system')) {
      return ErrorCategory.SYSTEM;
    }

    return ErrorCategory.UNKNOWN;
  }

  /**
   * Determine error severity
   * @private
   * @param {Error} error - Error object
   * @param {string} category - Error category
   * @returns {string} - Severity level
   */
  _determineSeverity(error, category) {
    // Critical categories
    if (
      category === ErrorCategory.DATABASE ||
      category === ErrorCategory.SYSTEM
    ) {
      return ErrorSeverity.CRITICAL;
    }

    // Check error message for severity indicators
    const message = error.message?.toLowerCase() || '';
    if (message.includes('critical') || message.includes('fatal')) {
      return ErrorSeverity.CRITICAL;
    }
    if (message.includes('error') || message.includes('failed')) {
      return ErrorSeverity.HIGH;
    }
    if (message.includes('warning') || message.includes('deprecated')) {
      return ErrorSeverity.MEDIUM;
    }

    // Default based on category
    if (
      category === ErrorCategory.AUTHENTICATION ||
      category === ErrorCategory.SERVICE
    ) {
      return ErrorSeverity.HIGH;
    }

    return ErrorSeverity.MEDIUM;
  }

  /**
   * Check if notification should be sent
   * @private
   * @param {string} category - Error category
   * @param {string} severity - Error severity
   * @returns {boolean} - Whether to send notification
   */
  _shouldSendNotification(category, severity) {
    if (!this.config.enableNotifications) {
      return false;
    }

    // Always notify for critical errors
    if (severity === ErrorSeverity.CRITICAL) {
      return true;
    }

    // Check cooldown
    const lastNotification = this.lastNotificationTime.get(category);
    if (lastNotification) {
      const timeSinceLastNotification = Date.now() - lastNotification;
      if (timeSinceLastNotification < this.config.notificationCooldown) {
        return false;
      }
    }

    // Check error count threshold
    const errorCount = this.errorCounts.get(category) || 0;
    if (errorCount >= this.config.criticalErrorThreshold) {
      return true;
    }

    return severity === ErrorSeverity.HIGH;
  }

  /**
   * Queue notification for delivery
   * @private
   * @param {Object} notification - Notification object
   * @returns {Promise<void>}
   */
  async _queueNotification(notification) {
    if (this.notificationQueue.length >= this.config.maxNotificationQueueSize) {
      logger.warn('Notification queue full, dropping oldest notification');
      this.notificationQueue.shift();
    }

    this.notificationQueue.push(notification);
    this.lastNotificationTime.set(notification.category, Date.now());

    // Process queue
    await this._processNotificationQueue();
  }

  /**
   * Process notification queue
   * @private
   * @returns {Promise<void>}
   */
  async _processNotificationQueue() {
    if (this.isProcessingQueue || this.notificationQueue.length === 0) {
      return;
    }

    this.isProcessingQueue = true;

    try {
      while (this.notificationQueue.length > 0) {
        const notification = this.notificationQueue.shift();
        await this._sendNotification(notification);
      }
    } finally {
      this.isProcessingQueue = false;
    }
  }

  /**
   * Send notification through configured channels
   * @private
   * @param {Object} notification - Notification object
   * @returns {Promise<void>}
   */
  async _sendNotification(notification) {
    const startTime = Date.now();
    const channels = this.config.notificationChannels || [
      NotificationChannel.LOG,
    ];

    for (const channel of channels) {
      try {
        const handler = this.notificationHandlers.get(channel);
        if (!handler) {
          logger.warn(`No handler registered for channel: ${channel}`);
          continue;
        }

        await handler(notification);
        this.metrics.notificationsSent++;

        logger.debug(`Notification sent via ${channel}`, {
          errorId: notification.errorId,
          channel,
        });
      } catch (error) {
        this.metrics.notificationsFailed++;
        logger.error(`Failed to send notification via ${channel}`, {
          errorId: notification.errorId,
          channel,
          error: error.message,
        });
      }
    }

    // Update metrics
    const duration = Date.now() - startTime;
    this.metrics.notificationTimes.push(duration);
    this._updateAverageNotificationTime();

    // Emit event
    this.emit('notification-sent', notification);
  }

  /**
   * Add entry to error history
   * @private
   * @param {Object} entry - History entry
   */
  _addToHistory(entry) {
    this.errorHistory.push(entry);

    // Keep history size manageable (max 1000 entries)
    if (this.errorHistory.length > 1000) {
      this.errorHistory = this.errorHistory.slice(-1000);
    }
  }

  /**
   * Update average notification time
   * @private
   */
  _updateAverageNotificationTime() {
    if (this.metrics.notificationTimes.length === 0) {
      this.metrics.averageNotificationTime = 0;
      return;
    }

    const sum = this.metrics.notificationTimes.reduce((a, b) => a + b, 0);
    this.metrics.averageNotificationTime = Math.round(
      sum / this.metrics.notificationTimes.length,
    );

    // Keep only last 100 notification times for memory efficiency
    if (this.metrics.notificationTimes.length > 100) {
      this.metrics.notificationTimes =
        this.metrics.notificationTimes.slice(-100);
    }
  }

  /**
   * Get error history
   * @param {Object} options - Filter options
   * @param {string} options.category - Filter by category
   * @param {string} options.severity - Filter by severity
   * @param {number} options.limit - Limit results
   * @returns {Array} - Error history
   */
  getErrorHistory(options = {}) {
    let history = [...this.errorHistory];

    if (options.category) {
      history = history.filter((h) => h.category === options.category);
    }

    if (options.severity) {
      history = history.filter((h) => h.severity === options.severity);
    }

    if (options.limit) {
      history = history.slice(-options.limit);
    }

    return history;
  }

  /**
   * Get notification metrics
   * @returns {Object} - Metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      queueSize: this.notificationQueue.length,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get error statistics
   * @returns {Object} - Error statistics
   */
  getErrorStatistics() {
    const stats = {};
    let totalFromCounts = 0;
    for (const [category, count] of this.errorCounts) {
      stats[category] = count;
      totalFromCounts += count;
    }

    return {
      totalErrors: totalFromCounts,
      criticalErrors: this.metrics.criticalErrorsDetected, // Note: This is still lifetime
      errorsByCategory: stats,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Reset error counts
   */
  resetErrorCounts() {
    this.errorCounts.clear();
    this.lastNotificationTime.clear();
    logger.info('Error counts and notification cooldowns reset');
  }

  /**
   * Clear error history
   */
  clearHistory() {
    this.errorHistory = [];
    logger.info('Error history cleared');
  }

  /**
   * Reset all metrics
   */
  resetMetrics() {
    this.metrics = {
      totalErrorsDetected: 0,
      criticalErrorsDetected: 0,
      notificationsSent: 0,
      notificationsFailed: 0,
      averageNotificationTime: 0,
      notificationTimes: [],
    };
    logger.info('Error notification metrics reset');
  }

  /**
   * Get notification status
   * @returns {Object} - Notification status
   */
  getStatus() {
    return {
      enabled: this.config.enableNotifications,
      channels: this.config.notificationChannels,
      queueSize: this.notificationQueue.length,
      metrics: this.getMetrics(),
      statistics: this.getErrorStatistics(),
      timestamp: new Date().toISOString(),
    };
  }
}

// Singleton instance
export const errorNotificationService = new ErrorNotificationService({
  enableNotifications: process.env.ERROR_NOTIFICATIONS_ENABLED !== 'false',
  notificationChannels: (
    process.env.ERROR_NOTIFICATION_CHANNELS || 'log'
  ).split(','),
  criticalErrorThreshold: parseInt(process.env.CRITICAL_ERROR_THRESHOLD || '5'),
  notificationCooldown: parseInt(process.env.NOTIFICATION_COOLDOWN || '60000'),
  webhookUrl: process.env.ERROR_NOTIFICATION_WEBHOOK_URL,
  webhookToken: process.env.ERROR_NOTIFICATION_WEBHOOK_TOKEN,
  slackWebhook: process.env.ERROR_NOTIFICATION_SLACK_WEBHOOK,
});
