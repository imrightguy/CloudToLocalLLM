import { jest } from "@jest/globals";

/**
 * Error Notification Service Tests
 *
 * Tests for critical error detection and notification mechanisms.
 * Validates notification configuration and delivery.
 *
 * Requirement 7.9: THE API SHALL support error notifications for critical issues
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import {
  ErrorNotificationService,
  ErrorSeverity,
  ErrorCategory,
  NotificationChannel,
} from "../../services/api-backend/services/error-notification-service.js";

describe("ErrorNotificationService", () => {
  let service;

  beforeEach(() => {
    service = new ErrorNotificationService({
      enableNotifications: true,
      notificationChannels: [NotificationChannel.LOG],
      criticalErrorThreshold: 3,
      notificationCooldown: 1000, // 1 second for testing
    });
  });

  afterEach(() => {
    service.clearHistory();
    service.resetMetrics();
    service.resetErrorCounts();
  });

  describe("Error Detection and Categorization", () => {
    it("should categorize database errors correctly", async () => {
      const error = new Error("Database connection failed");
      const result = await service.detectAndNotify(error);

      expect(result.notification.category).toBe(ErrorCategory.DATABASE);
    });

    it("should categorize authentication errors correctly", async () => {
      const error = new Error("Authentication failed: invalid token");
      const result = await service.detectAndNotify(error);

      expect(result.notification.category).toBe(ErrorCategory.AUTHENTICATION);
    });

    it("should categorize service errors correctly", async () => {
      const error = new Error("Service unavailable");
      const result = await service.detectAndNotify(error);

      expect(result.notification.category).toBe(ErrorCategory.SERVICE);
    });

    it("should categorize external API errors correctly", async () => {
      const error = new Error("HTTP request failed");
      const result = await service.detectAndNotify(error);

      expect(result.notification.category).toBe(ErrorCategory.EXTERNAL_API);
    });

    it("should categorize resource errors correctly", async () => {
      const error = new Error("Out of memory");
      await service.detectAndNotify(error);

      const history = service.getErrorHistory();
      expect(history[0].category).toBe(ErrorCategory.RESOURCE);
    });

    it("should categorize system errors correctly", async () => {
      const error = new Error("System error: critical failure");
      const result = await service.detectAndNotify(error);

      expect(result.notification.category).toBe(ErrorCategory.SYSTEM);
    });

    it("should default to unknown category for unrecognized errors", async () => {
      const error = new Error("Some random error");
      const result = await service.detectAndNotify(error);

      expect(result.notification.category).toBe(ErrorCategory.UNKNOWN);
    });
  });

  describe("Severity Determination", () => {
    it("should mark database errors as critical", async () => {
      const error = new Error("Database connection failed");
      const result = await service.detectAndNotify(error);

      expect(result.notification.severity).toBe(ErrorSeverity.CRITICAL);
    });

    it("should mark system errors as critical", async () => {
      const error = new Error("System error: critical failure");
      const result = await service.detectAndNotify(error);

      expect(result.notification.severity).toBe(ErrorSeverity.CRITICAL);
    });

    it("should mark authentication errors as high severity", async () => {
      const error = new Error("Authentication failed");
      const result = await service.detectAndNotify(error);

      expect(result.notification.severity).toBe(ErrorSeverity.HIGH);
    });

    it("should mark service errors as high severity", async () => {
      const error = new Error("Service error");
      const result = await service.detectAndNotify(error);

      expect(result.notification.severity).toBe(ErrorSeverity.HIGH);
    });

    it('should mark errors with "critical" in message as critical', async () => {
      const error = new Error("Critical failure in processing");
      const result = await service.detectAndNotify(error);

      expect(result.notification.severity).toBe(ErrorSeverity.CRITICAL);
    });

    it('should mark errors with "fatal" in message as critical', async () => {
      const error = new Error("Fatal error occurred");
      const result = await service.detectAndNotify(error);

      expect(result.notification.severity).toBe(ErrorSeverity.CRITICAL);
    });
  });

  describe("Notification Sending", () => {
    it("should send notification for critical errors", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database connection failed");
      const result = await service.detectAndNotify(error);

      expect(result.notificationSent).toBe(true);
      expect(handler).toHaveBeenCalled();
    });

    it("should include error context in notification", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      const context = {
        userId: "user123",
        endpoint: "/api/users",
        method: "GET",
      };

      await service.detectAndNotify(error, context);

      const notification = handler.mock.calls[0][0];
      expect(notification.context).toEqual(context);
    });

    it("should track notification metrics", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      const metrics = service.getMetrics();
      expect(metrics.notificationsSent).toBe(1);
      expect(metrics.totalErrorsDetected).toBe(1);
    });

    it("should handle notification handler errors gracefully", async () => {
      const handler = jest.fn().mockRejectedValue(new Error("Handler failed"));
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      const result = await service.detectAndNotify(error);

      expect(result.notificationSent).toBe(true);
      const metrics = service.getMetrics();
      expect(metrics.notificationsFailed).toBe(1);
    });
  });

  describe("Notification Cooldown", () => {
    it("should respect cooldown period between notifications", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      // Use an error that results in HIGH severity (not CRITICAL) to test cooldown
      const error = new Error("Some high error");

      // First notification should be sent
      const result1 = await service.detectAndNotify(error);
      expect(result1.notificationSent).toBe(true);

      // Second notification within cooldown should not be sent
      const result2 = await service.detectAndNotify(error);
      expect(result2.notificationSent).toBe(false);

      // Wait for cooldown to expire
      await new Promise((resolve) => setTimeout(resolve, 1100));

      // Third notification after cooldown should be sent
      const result3 = await service.detectAndNotify(error);
      expect(result3.notificationSent).toBe(true);
    });

    it("should bypass cooldown for critical errors", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database connection failed");

      // First notification
      const result1 = await service.detectAndNotify(error);
      expect(result1.notificationSent).toBe(true);

      // Critical errors should bypass cooldown
      const result2 = await service.detectAndNotify(error);
      expect(result2.notificationSent).toBe(true);
    });
  });

  describe("Error Count Threshold", () => {
    it("should send notification when error count exceeds threshold", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      // Use an error that results in MEDIUM severity so threshold logic applies
      const error = new Error("Minor notification");

      // First error - below threshold
      const result1 = await service.detectAndNotify(error);
      expect(result1.notificationSent).toBe(false);

      // Second error - below threshold
      const result2 = await service.detectAndNotify(error);
      expect(result2.notificationSent).toBe(false);

      // Third error - at threshold
      const result3 = await service.detectAndNotify(error);
      expect(result3.notificationSent).toBe(true);
    });
  });

  describe("Error History", () => {
    it("should maintain error history", async () => {
      const error1 = new Error("Database error");
      const error2 = new Error("Authentication error");

      await service.detectAndNotify(error1);
      await service.detectAndNotify(error2);

      const history = service.getErrorHistory();
      expect(history.length).toBe(2);
      expect(history[0].category).toBe(ErrorCategory.DATABASE);
      expect(history[1].category).toBe(ErrorCategory.AUTHENTICATION);
    });

    it("should filter error history by category", async () => {
      const dbError = new Error("Database error");
      const authError = new Error("Authentication error");

      await service.detectAndNotify(dbError);
      await service.detectAndNotify(authError);

      const dbHistory = service.getErrorHistory({
        category: ErrorCategory.DATABASE,
      });
      expect(dbHistory.length).toBe(1);
      expect(dbHistory[0].category).toBe(ErrorCategory.DATABASE);
    });

    it("should filter error history by severity", async () => {
      const criticalError = new Error("Database error");
      const mediumError = new Error("Some error");

      await service.detectAndNotify(criticalError);
      await service.detectAndNotify(mediumError);

      const criticalHistory = service.getErrorHistory({
        severity: ErrorSeverity.CRITICAL,
      });
      expect(criticalHistory.length).toBe(1);
      expect(criticalHistory[0].severity).toBe(ErrorSeverity.CRITICAL);
    });

    it("should limit error history results", async () => {
      for (let i = 0; i < 10; i++) {
        const error = new Error(`Error ${i}`);
        await service.detectAndNotify(error);
      }

      const history = service.getErrorHistory({ limit: 5 });
      expect(history.length).toBe(5);
    });

    it("should clear error history", () => {
      const error = new Error("Database error");
      service.detectAndNotify(error);

      let history = service.getErrorHistory();
      expect(history.length).toBeGreaterThan(0);

      service.clearHistory();
      history = service.getErrorHistory();
      expect(history.length).toBe(0);
    });
  });

  describe("Error Statistics", () => {
    it("should track error statistics by category", async () => {
      const dbError = new Error("Database error");
      const authError = new Error("Authentication error");

      await service.detectAndNotify(dbError);
      await service.detectAndNotify(authError);
      await service.detectAndNotify(dbError);

      const stats = service.getErrorStatistics();
      expect(stats.errorsByCategory[ErrorCategory.DATABASE]).toBe(2);
      expect(stats.errorsByCategory[ErrorCategory.AUTHENTICATION]).toBe(1);
    });

    it("should track critical error count", async () => {
      const criticalError = new Error("Database error");
      const normalError = new Error("Some error");

      await service.detectAndNotify(criticalError);
      await service.detectAndNotify(normalError);

      const stats = service.getErrorStatistics();
      expect(stats.criticalErrors).toBe(1);
      expect(stats.totalErrors).toBe(2);
    });

    it("should reset error counts", async () => {
      const error = new Error("Database error");
      await service.detectAndNotify(error);

      let stats = service.getErrorStatistics();
      expect(stats.totalErrors).toBe(1);

      service.resetErrorCounts();
      service.resetMetrics();
      stats = service.getErrorStatistics();
      expect(stats.totalErrors).toBe(0);
    });
  });

  describe("Metrics", () => {
    it("should track notification metrics", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      const metrics = service.getMetrics();
      expect(metrics.totalErrorsDetected).toBe(1);
      expect(metrics.criticalErrorsDetected).toBe(1);
      expect(metrics.notificationsSent).toBe(1);
    });

    it("should calculate average notification time", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      const metrics = service.getMetrics();
      expect(metrics.averageNotificationTime).toBeGreaterThanOrEqual(0);
    });

    it("should reset metrics", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      let metrics = service.getMetrics();
      expect(metrics.totalErrorsDetected).toBe(1);

      service.resetMetrics();
      metrics = service.getMetrics();
      expect(metrics.totalErrorsDetected).toBe(0);
      expect(metrics.notificationsSent).toBe(0);
    });
  });

  describe("Notification Handlers", () => {
    it("should register custom notification handler", () => {
      const handler = jest.fn();
      service.registerNotificationHandler("custom", handler);

      expect(service.notificationHandlers.has("custom")).toBe(true);
    });

    it("should reject invalid handler", () => {
      expect(() => {
        service.registerNotificationHandler("invalid", "not a function");
      }).toThrow("Handler must be a function");
    });

    it("should support multiple notification channels", async () => {
      const handler1 = jest.fn().mockResolvedValue(undefined);
      const handler2 = jest.fn().mockResolvedValue(undefined);

      service.config.notificationChannels = ["channel1", "channel2"];
      service.registerNotificationHandler("channel1", handler1);
      service.registerNotificationHandler("channel2", handler2);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      expect(handler1).toHaveBeenCalled();
      expect(handler2).toHaveBeenCalled();
    });
  });

  describe("Service Status", () => {
    it("should return service status", async () => {
      const error = new Error("Database error");
      await service.detectAndNotify(error);

      const status = service.getStatus();
      expect(status.enabled).toBe(true);
      expect(status.channels).toBeDefined();
      expect(status.queueSize).toBeDefined();
      expect(status.metrics).toBeDefined();
      expect(status.statistics).toBeDefined();
    });

    it("should include queue size in status", async () => {
      const handler = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 100)),
        );
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      const status = service.getStatus();
      expect(status.queueSize).toBeGreaterThanOrEqual(0);
    });
  });

  describe("Disabled Notifications", () => {
    it("should not send notifications when disabled", async () => {
      service.config.enableNotifications = false;
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const error = new Error("Database error");
      const result = await service.detectAndNotify(error);

      expect(result.notificationSent).toBe(false);
      expect(handler).not.toHaveBeenCalled();
    });
  });

  describe("Event Emission", () => {
    it("should emit notification-sent event", async () => {
      const handler = jest.fn().mockResolvedValue(undefined);
      service.registerNotificationHandler(NotificationChannel.LOG, handler);

      const eventListener = jest.fn();
      service.on("notification-sent", eventListener);

      const error = new Error("Database error");
      await service.detectAndNotify(error);

      expect(eventListener).toHaveBeenCalled();
    });
  });
});
