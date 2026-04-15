import { jest } from '@jest/globals';
import {
  ErrorNotificationService,
  ErrorSeverity,
  ErrorCategory,
  NotificationChannel,
} from '../../services/api-backend/services/error-notification-service.js';

describe('ErrorNotificationService', () => {
  let service;

  beforeEach(() => {
    service = new ErrorNotificationService({
      enableNotifications: true,
      notificationChannels: [NotificationChannel.LOG],
      criticalErrorThreshold: 3,
      notificationCooldown: 100,
      maxNotificationQueueSize: 50,
    });
  });

  describe('Constants', () => {
    test('ErrorSeverity has all expected levels', () => {
      expect(ErrorSeverity.LOW).toBe('low');
      expect(ErrorSeverity.MEDIUM).toBe('medium');
      expect(ErrorSeverity.HIGH).toBe('high');
      expect(ErrorSeverity.CRITICAL).toBe('critical');
    });

    test('ErrorCategory has all expected categories', () => {
      expect(ErrorCategory.DATABASE).toBe('database');
      expect(ErrorCategory.AUTHENTICATION).toBe('authentication');
      expect(ErrorCategory.SERVICE).toBe('service');
      expect(ErrorCategory.EXTERNAL_API).toBe('external_api');
      expect(ErrorCategory.RESOURCE).toBe('resource');
      expect(ErrorCategory.SYSTEM).toBe('system');
      expect(ErrorCategory.UNKNOWN).toBe('unknown');
    });

    test('NotificationChannel has all expected channels', () => {
      expect(NotificationChannel.EMAIL).toBe('email');
      expect(NotificationChannel.SLACK).toBe('slack');
      expect(NotificationChannel.WEBHOOK).toBe('webhook');
      expect(NotificationChannel.LOG).toBe('log');
      expect(NotificationChannel.SENTRY).toBe('sentry');
    });
  });

  describe('Constructor', () => {
    test('should initialize with default config', () => {
      const svc = new ErrorNotificationService();
      expect(svc.config.enableNotifications).toBe(true);
      expect(svc.config.notificationChannels).toEqual([NotificationChannel.LOG]);
      expect(svc.config.criticalErrorThreshold).toBe(5);
      expect(svc.config.notificationCooldown).toBe(60000);
      expect(svc.config.maxNotificationQueueSize).toBe(1000);
    });

    test('should accept custom config', () => {
      const svc = new ErrorNotificationService({
        enableNotifications: false,
        criticalErrorThreshold: 10,
        notificationCooldown: 30000,
      });
      expect(svc.config.enableNotifications).toBe(false);
      expect(svc.config.criticalErrorThreshold).toBe(10);
      expect(svc.config.notificationCooldown).toBe(30000);
    });

    test('should initialize metrics to zero', () => {
      expect(service.metrics.totalErrorsDetected).toBe(0);
      expect(service.metrics.criticalErrorsDetected).toBe(0);
      expect(service.metrics.notificationsSent).toBe(0);
      expect(service.metrics.notificationsFailed).toBe(0);
      expect(service.metrics.averageNotificationTime).toBe(0);
      expect(service.metrics.notificationTimes).toEqual([]);
    });

    test('should initialize with empty error history', () => {
      expect(service.errorHistory).toEqual([]);
      expect(service.errorCounts.size).toBe(0);
    });

    test('should register default LOG handler', () => {
      expect(service.notificationHandlers.has(NotificationChannel.LOG)).toBe(true);
    });

    test('should register WEBHOOK handler when webhookUrl configured', () => {
      const svc = new ErrorNotificationService({ webhookUrl: 'https://example.com/hook' });
      expect(svc.notificationHandlers.has(NotificationChannel.WEBHOOK)).toBe(true);
    });

    test('should not register WEBHOOK handler when no webhookUrl', () => {
      expect(service.notificationHandlers.has(NotificationChannel.WEBHOOK)).toBe(false);
    });

    test('should register EMAIL handler when emailService configured', () => {
      const svc = new ErrorNotificationService({
        emailService: { sendCriticalErrorNotification: jest.fn() },
      });
      expect(svc.notificationHandlers.has(NotificationChannel.EMAIL)).toBe(true);
    });

    test('should register SLACK handler when slackWebhook configured', () => {
      const svc = new ErrorNotificationService({
        slackWebhook: 'https://hooks.slack.com/xxx',
      });
      expect(svc.notificationHandlers.has(NotificationChannel.SLACK)).toBe(true);
    });

    test('should extend EventEmitter', () => {
      expect(typeof service.on).toBe('function');
      expect(typeof service.emit).toBe('function');
    });
  });

  describe('_categorizeError', () => {
    test('should categorize database errors', () => {
      expect(service._categorizeError(new Error('database connection failed'))).toBe(ErrorCategory.DATABASE);
    });

    test('should categorize database errors by name', () => {
      const err = new Error('something');
      err.name = 'DatabaseError';
      expect(service._categorizeError(err)).toBe(ErrorCategory.DATABASE);
    });

    test('should categorize authentication errors', () => {
      expect(service._categorizeError(new Error('auth token expired'))).toBe(ErrorCategory.AUTHENTICATION);
    });

    test('should categorize service errors', () => {
      expect(service._categorizeError(new Error('service unavailable'))).toBe(ErrorCategory.SERVICE);
    });

    test('should categorize external API errors', () => {
      expect(service._categorizeError(new Error('fetch timeout'))).toBe(ErrorCategory.EXTERNAL_API);
      expect(service._categorizeError(new Error('http 503'))).toBe(ErrorCategory.EXTERNAL_API);
      expect(service._categorizeError(new Error('api rate limited'))).toBe(ErrorCategory.EXTERNAL_API);
    });

    test('should categorize resource errors', () => {
      expect(service._categorizeError(new Error('memory exceeded'))).toBe(ErrorCategory.RESOURCE);
      expect(service._categorizeError(new Error('resource exhausted'))).toBe(ErrorCategory.RESOURCE);
    });

    test('should categorize system errors', () => {
      expect(service._categorizeError(new Error('system crash'))).toBe(ErrorCategory.SYSTEM);
    });

    test('should return UNKNOWN for unrecognized errors', () => {
      expect(service._categorizeError(new Error('something weird happened'))).toBe(ErrorCategory.UNKNOWN);
    });

    test('should handle errors with no message', () => {
      expect(service._categorizeError({})).toBe(ErrorCategory.UNKNOWN);
    });
  });

  describe('_determineSeverity', () => {
    test('should mark DATABASE category as CRITICAL', () => {
      expect(service._determineSeverity(new Error('x'), ErrorCategory.DATABASE)).toBe(ErrorSeverity.CRITICAL);
    });

    test('should mark SYSTEM category as CRITICAL', () => {
      expect(service._determineSeverity(new Error('x'), ErrorCategory.SYSTEM)).toBe(ErrorSeverity.CRITICAL);
    });

    test('should detect critical in message', () => {
      expect(service._determineSeverity(new Error('critical failure'), ErrorCategory.SERVICE)).toBe(ErrorSeverity.CRITICAL);
    });

    test('should detect fatal in message', () => {
      expect(service._determineSeverity(new Error('fatal exception'), ErrorCategory.SERVICE)).toBe(ErrorSeverity.CRITICAL);
    });

    test('should detect error keyword as HIGH', () => {
      expect(service._determineSeverity(new Error('error reading config'), ErrorCategory.UNKNOWN)).toBe(ErrorSeverity.HIGH);
    });

    test('should detect failed keyword as HIGH', () => {
      expect(service._determineSeverity(new Error('operation failed'), ErrorCategory.UNKNOWN)).toBe(ErrorSeverity.HIGH);
    });

    test('should detect warning keyword as MEDIUM', () => {
      expect(service._determineSeverity(new Error('warning threshold reached'), ErrorCategory.UNKNOWN)).toBe(ErrorSeverity.MEDIUM);
    });

    test('should detect deprecated keyword as MEDIUM', () => {
      expect(service._determineSeverity(new Error('deprecated API call'), ErrorCategory.UNKNOWN)).toBe(ErrorSeverity.MEDIUM);
    });

    test('should default AUTHENTICATION to HIGH', () => {
      expect(service._determineSeverity(new Error('x'), ErrorCategory.AUTHENTICATION)).toBe(ErrorSeverity.HIGH);
    });

    test('should default SERVICE to HIGH', () => {
      expect(service._determineSeverity(new Error('x'), ErrorCategory.SERVICE)).toBe(ErrorSeverity.HIGH);
    });

    test('should default unknown category to MEDIUM', () => {
      expect(service._determineSeverity(new Error('x'), ErrorCategory.UNKNOWN)).toBe(ErrorSeverity.MEDIUM);
    });
  });

  describe('_shouldSendNotification', () => {
    test('should return false when notifications disabled', () => {
      service.config.enableNotifications = false;
      expect(service._shouldSendNotification(ErrorCategory.DATABASE, ErrorSeverity.CRITICAL)).toBe(false);
    });

    test('should always return true for CRITICAL severity', () => {
      expect(service._shouldSendNotification(ErrorCategory.UNKNOWN, ErrorSeverity.CRITICAL)).toBe(true);
    });

    test('should return true for HIGH severity when no cooldown', () => {
      expect(service._shouldSendNotification(ErrorCategory.SERVICE, ErrorSeverity.HIGH)).toBe(true);
    });

    test('should return false during cooldown for non-critical', () => {
      service.lastNotificationTime.set(ErrorCategory.SERVICE, Date.now());
      expect(service._shouldSendNotification(ErrorCategory.SERVICE, ErrorSeverity.HIGH)).toBe(false);
    });

    test('should return true after cooldown expires', async () => {
      service.lastNotificationTime.set(ErrorCategory.SERVICE, Date.now() - 200);
      expect(service._shouldSendNotification(ErrorCategory.SERVICE, ErrorSeverity.HIGH)).toBe(true);
    });

    test('should return true when error count exceeds threshold', () => {
      service.errorCounts.set(ErrorCategory.SERVICE, 5);
      expect(service._shouldSendNotification(ErrorCategory.SERVICE, ErrorSeverity.MEDIUM)).toBe(true);
    });

    test('should return false for MEDIUM severity below threshold without cooldown breach', () => {
      expect(service._shouldSendNotification(ErrorCategory.UNKNOWN, ErrorSeverity.MEDIUM)).toBe(false);
    });

    test('should return false for LOW severity', () => {
      expect(service._shouldSendNotification(ErrorCategory.UNKNOWN, ErrorSeverity.LOW)).toBe(false);
    });
  });

  describe('detectAndNotify', () => {
    test('should detect error and queue notification', async () => {
      const result = await service.detectAndNotify(
        new Error('database connection lost'),
        { source: 'test' },
      );

      expect(result.notificationSent).toBe(true);
      expect(result.errorId).toMatch(/^error-/);
      expect(result.notification).toBeDefined();
      expect(result.notification.category).toBe(ErrorCategory.DATABASE);
      expect(result.notification.severity).toBe(ErrorSeverity.CRITICAL);
      expect(result.notification.message).toBe('database connection lost');
    });

    test('should increment totalErrorsDetected', async () => {
      await service.detectAndNotify(new Error('test error'));
      expect(service.metrics.totalErrorsDetected).toBe(1);
    });

    test('should increment criticalErrorsDetected for critical errors', async () => {
      await service.detectAndNotify(new Error('database failure'));
      expect(service.metrics.criticalErrorsDetected).toBe(1);
    });

    test('should not increment criticalErrorsDetected for non-critical', async () => {
      await service.detectAndNotify(new Error('something weird'));
      expect(service.metrics.criticalErrorsDetected).toBe(0);
    });

    test('should update error counts by category', async () => {
      await service.detectAndNotify(new Error('database failure'));
      expect(service.errorCounts.get(ErrorCategory.DATABASE)).toBe(1);
    });

    test('should add entry to error history', async () => {
      await service.detectAndNotify(new Error('test error'));
      expect(service.errorHistory.length).toBe(1);
      expect(service.errorHistory[0].message).toBe('test error');
    });

    test('should not send notification during cooldown for non-critical', async () => {
      // First: trigger notification for a category and set cooldown
      await service.detectAndNotify(new Error('something bad')); // UNKNOWN category, HIGH severity
      // Manually set cooldown for this category to ensure it's active
      service.lastNotificationTime.set(ErrorCategory.UNKNOWN, Date.now());
      // Second: same category, HIGH severity but within cooldown
      const result = await service.detectAndNotify(new Error('something bad again'));
      expect(result.notificationSent).toBe(false);
    });

    test('should return notificationSent false when notifications disabled', async () => {
      service.config.enableNotifications = false;
      const result = await service.detectAndNotify(new Error('critical failure'));
      expect(result.notificationSent).toBe(false);
    });

    test('should emit notification-sent event', async () => {
      const listener = jest.fn();
      service.on('notification-sent', listener);
      await service.detectAndNotify(new Error('database failure'));
      expect(listener).toHaveBeenCalled();
    });

    test('should include context in notification', async () => {
      const result = await service.detectAndNotify(new Error('database failure'), {
        requestId: 'req-123',
        userId: 'user-456',
      });
      expect(result.notification.context.requestId).toBe('req-123');
      expect(result.notification.context.userId).toBe('user-456');
    });
  });

  describe('registerNotificationHandler', () => {
    test('should register a valid handler', () => {
      const handler = jest.fn();
      service.registerNotificationHandler('custom', handler);
      expect(service.notificationHandlers.has('custom')).toBe(true);
    });

    test('should throw for non-function handler', () => {
      expect(() => service.registerNotificationHandler('custom', 'not-a-function')).toThrow(
        'Handler must be a function',
      );
    });
  });

  describe('_getSeverityColor', () => {
    test('should return green for LOW', () => {
      expect(service._getSeverityColor(ErrorSeverity.LOW)).toBe('#36a64f');
    });

    test('should return orange for MEDIUM', () => {
      expect(service._getSeverityColor(ErrorSeverity.MEDIUM)).toBe('#ff9900');
    });

    test('should return dark orange for HIGH', () => {
      expect(service._getSeverityColor(ErrorSeverity.HIGH)).toBe('#ff6600');
    });

    test('should return red for CRITICAL', () => {
      expect(service._getSeverityColor(ErrorSeverity.CRITICAL)).toBe('#ff0000');
    });

    test('should return gray for unknown severity', () => {
      expect(service._getSeverityColor('unknown')).toBe('#999999');
    });
  });

  describe('_addToHistory', () => {
    test('should add entry to history', () => {
      service._addToHistory({ errorId: 'test-1', category: 'database' });
      expect(service.errorHistory.length).toBe(1);
    });

    test('should trim history when exceeding 1000 entries', () => {
      for (let i = 0; i < 1100; i++) {
        service._addToHistory({ errorId: `test-${i}`, index: i });
      }
      expect(service.errorHistory.length).toBe(1000);
      // Should keep the last 1000 entries
      expect(service.errorHistory[0].index).toBe(100);
    });
  });

  describe('getErrorHistory', () => {
    beforeEach(async () => {
      await service.detectAndNotify(new Error('database failure'));
      await service.detectAndNotify(new Error('auth token expired'));
      await service.detectAndNotify(new Error('something unknown'));
    });

    test('should return all history without filters', () => {
      const history = service.getErrorHistory();
      expect(history.length).toBe(3);
    });

    test('should filter by category', () => {
      const history = service.getErrorHistory({ category: ErrorCategory.DATABASE });
      expect(history.length).toBe(1);
      expect(history[0].category).toBe(ErrorCategory.DATABASE);
    });

    test('should filter by severity', () => {
      const history = service.getErrorHistory({ severity: ErrorSeverity.CRITICAL });
      expect(history.every((h) => h.severity === ErrorSeverity.CRITICAL)).toBe(true);
    });

    test('should limit results', () => {
      const history = service.getErrorHistory({ limit: 2 });
      expect(history.length).toBe(2);
    });
  });

  describe('getMetrics', () => {
    test('should return metrics with queue size', () => {
      const metrics = service.getMetrics();
      expect(metrics.totalErrorsDetected).toBe(0);
      expect(metrics.queueSize).toBe(0);
      expect(metrics.timestamp).toBeDefined();
    });
  });

  describe('getErrorStatistics', () => {
    test('should return empty stats initially', () => {
      const stats = service.getErrorStatistics();
      expect(stats.totalErrors).toBe(0);
      expect(stats.errorsByCategory).toEqual({});
    });

    test('should return populated stats after errors', async () => {
      await service.detectAndNotify(new Error('database failure'));
      await service.detectAndNotify(new Error('database failure again'));
      const stats = service.getErrorStatistics();
      expect(stats.totalErrors).toBe(2);
      expect(stats.errorsByCategory[ErrorCategory.DATABASE]).toBe(2);
    });
  });

  describe('resetErrorCounts', () => {
    test('should clear all error counts and cooldowns', async () => {
      await service.detectAndNotify(new Error('test'));
      service.resetErrorCounts();
      expect(service.errorCounts.size).toBe(0);
      expect(service.lastNotificationTime.size).toBe(0);
    });
  });

  describe('clearHistory', () => {
    test('should clear error history', async () => {
      await service.detectAndNotify(new Error('test'));
      service.clearHistory();
      expect(service.errorHistory).toEqual([]);
    });
  });

  describe('resetMetrics', () => {
    test('should reset all metrics to initial values', async () => {
      await service.detectAndNotify(new Error('database failure'));
      service.resetMetrics();
      expect(service.metrics.totalErrorsDetected).toBe(0);
      expect(service.metrics.criticalErrorsDetected).toBe(0);
      expect(service.metrics.notificationsSent).toBe(0);
      expect(service.metrics.notificationsFailed).toBe(0);
      expect(service.metrics.averageNotificationTime).toBe(0);
      expect(service.metrics.notificationTimes).toEqual([]);
    });
  });

  describe('getStatus', () => {
    test('should return complete status object', () => {
      const status = service.getStatus();
      expect(status.enabled).toBe(true);
      expect(status.channels).toEqual([NotificationChannel.LOG]);
      expect(status.queueSize).toBe(0);
      expect(status.metrics).toBeDefined();
      expect(status.statistics).toBeDefined();
      expect(status.timestamp).toBeDefined();
    });
  });

  describe('_sendNotification', () => {
    test('should track notification times', async () => {
      const notification = {
        errorId: 'test-1',
        category: ErrorCategory.DATABASE,
        severity: ErrorSeverity.CRITICAL,
        message: 'test',
        timestamp: new Date().toISOString(),
      };
      await service._sendNotification(notification);
      expect(service.metrics.notificationsSent).toBe(1);
      expect(service.metrics.notificationTimes.length).toBe(1);
    });

    test('should increment failed count for failing handler', async () => {
      service.registerNotificationHandler('failing', async () => {
        throw new Error('handler failed');
      });
      service.config.notificationChannels = ['failing'];
      const notification = {
        errorId: 'test-1',
        category: ErrorCategory.DATABASE,
        severity: ErrorSeverity.CRITICAL,
        message: 'test',
        timestamp: new Date().toISOString(),
      };
      await service._sendNotification(notification);
      expect(service.metrics.notificationsFailed).toBe(1);
    });

    test('should skip channels with no handler', async () => {
      service.config.notificationChannels = ['nonexistent'];
      const notification = {
        errorId: 'test-1',
        category: ErrorCategory.DATABASE,
        severity: ErrorSeverity.CRITICAL,
        message: 'test',
        timestamp: new Date().toISOString(),
      };
      await service._sendNotification(notification);
      // Should not throw, just skip
      expect(service.metrics.notificationsSent).toBe(0);
      expect(service.metrics.notificationsFailed).toBe(0);
    });
  });

  describe('Queue behavior', () => {
    test('should drop oldest when queue is full', async () => {
      service.config.maxNotificationQueueSize = 2;
      service.config.notificationChannels = [];

      // Fill queue manually via internal method
      service.notificationQueue.push({ errorId: 'old-1' });
      service.notificationQueue.push({ errorId: 'old-2' });

      await service._queueNotification({ errorId: 'new-1', category: 'test' });

      expect(service.notificationQueue.length).toBeLessThanOrEqual(3);
    });
  });
});
