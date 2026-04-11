/**
 * Alert Configuration Service Tests
 *
 * Tests for alert configuration management:
 * - Threshold management
 * - Channel configuration
 * - Alert history tracking
 * - Alert cooldown
 *
 * Requirements: 8.10 (Real-time alerting for critical metrics)
 */

import { describe, it, expect, beforeEach } from "@jest/globals";
import AlertConfigurationService from "../../services/api-backend/services/alert-configuration-service.js";

describe("Alert Configuration Service", () => {
  let service;

  beforeEach(() => {
    // Create fresh instance for each test
    service = new AlertConfigurationService();
  });

  describe("Threshold Management", () => {
    it("should return default thresholds", () => {
      const thresholds = service.getThresholds();

      expect(thresholds).toBeDefined();
      expect(thresholds.responseTime).toBeDefined();
      expect(thresholds.responseTime.warning).toBeLessThan(
        thresholds.responseTime.critical,
      );
      expect(thresholds.errorRate).toBeDefined();
      expect(thresholds.cpuUsage).toBeDefined();
      expect(thresholds.memoryUsage).toBeDefined();
    });

    it("should update thresholds", () => {
      const newThresholds = {
        responseTime: { warning: 300, critical: 800 },
      };

      const updated = service.updateThresholds(newThresholds);

      expect(updated.responseTime.warning).toBe(300);
      expect(updated.responseTime.critical).toBe(800);
    });

    it("should validate threshold values", () => {
      const invalidThresholds = {
        responseTime: { warning: 1000, critical: 500 }, // warning > critical
      };

      expect(() => {
        service.updateThresholds(invalidThresholds);
      }).toThrow();
    });

    it("should reset to default thresholds", () => {
      service.updateThresholds({
        responseTime: { warning: 100, critical: 200 },
      });

      service.resetToDefaults();

      const thresholds = service.getThresholds();
      expect(thresholds.responseTime.warning).toBe(500);
      expect(thresholds.responseTime.critical).toBe(1000);
    });
  });

  describe("Channel Configuration", () => {
    it("should return enabled channels", () => {
      const channels = service.getEnabledChannels();

      expect(channels).toBeDefined();
      expect(channels).toHaveProperty("email");
      expect(channels).toHaveProperty("slack");
      expect(channels).toHaveProperty("pagerduty");
    });

    it("should update enabled channels", () => {
      const updated = service.updateEnabledChannels({
        email: false,
        slack: true,
      });

      expect(updated.email).toBe(false);
      expect(updated.slack).toBe(true);
    });

    it("should ignore unknown channels", () => {
      const updated = service.updateEnabledChannels({
        email: true,
        unknownChannel: true,
      });

      expect(updated).not.toHaveProperty("unknownChannel");
      expect(updated.email).toBe(true);
    });
  });

  describe("Threshold Checking", () => {
    it("should detect critical threshold exceeded", () => {
      const result = service.checkThreshold("responseTime", 1500);

      expect(result.shouldAlert).toBe(true);
      expect(result.severity).toBe("critical");
    });

    it("should detect warning threshold exceeded", () => {
      const result = service.checkThreshold("responseTime", 750);

      expect(result.shouldAlert).toBe(true);
      expect(result.severity).toBe("warning");
    });

    it("should not alert when below threshold", () => {
      const result = service.checkThreshold("responseTime", 300);

      expect(result.shouldAlert).toBe(false);
      expect(result.severity).toBeNull();
    });

    it("should handle unknown metrics", () => {
      const result = service.checkThreshold("unknownMetric", 100);

      expect(result.shouldAlert).toBe(false);
      expect(result.severity).toBeNull();
    });
  });

  describe("Alert Cooldown", () => {
    it("should not be in cooldown initially", () => {
      const inCooldown = service.isInCooldown("test_alert");

      expect(inCooldown).toBe(false);
    });

    it("should enter cooldown after recording alert", () => {
      service.recordAlert("test_alert", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      const inCooldown = service.isInCooldown("test_alert");

      expect(inCooldown).toBe(true);
    });

    it("should exit cooldown after duration expires", async () => {
      // Create service with short cooldown for testing
      const testService = new AlertConfigurationService();
      testService.cooldownDuration = 100; // 100ms

      testService.recordAlert("test_alert", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      expect(testService.isInCooldown("test_alert")).toBe(true);

      // Wait for cooldown to expire
      await new Promise((resolve) => setTimeout(resolve, 150));

      expect(testService.isInCooldown("test_alert")).toBe(false);
    });
  });

  describe("Alert History", () => {
    it("should record alerts in history", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      service.recordAlert("alert2", {
        metric: "errorRate",
        severity: "critical",
        value: 15,
      });

      const history = service.getAlertHistory();

      expect(history.length).toBe(2);
      expect(history[0].key).toBe("alert1");
      expect(history[1].key).toBe("alert2");
    });

    it("should filter history by metric", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      service.recordAlert("alert2", {
        metric: "errorRate",
        severity: "critical",
        value: 15,
      });

      const history = service.getAlertHistory({ metric: "responseTime" });

      expect(history.length).toBe(1);
      expect(history[0].metric).toBe("responseTime");
    });

    it("should filter history by severity", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      service.recordAlert("alert2", {
        metric: "errorRate",
        severity: "critical",
        value: 15,
      });

      const history = service.getAlertHistory({ severity: "critical" });

      expect(history.length).toBe(1);
      expect(history[0].severity).toBe("critical");
    });

    it("should limit history size", () => {
      const testService = new AlertConfigurationService();
      testService.maxHistorySize = 5;

      for (let i = 0; i < 10; i++) {
        testService.recordAlert(`alert${i}`, {
          metric: "responseTime",
          severity: "warning",
          value: 600,
        });
      }

      const history = testService.getAlertHistory({ limit: 100 });

      expect(history.length).toBeLessThanOrEqual(5);
    });
  });

  describe("Active Alerts", () => {
    it("should track active alerts", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      const activeAlerts = service.getActiveAlerts();

      expect(activeAlerts.length).toBe(1);
      expect(activeAlerts[0].key).toBe("alert1");
    });

    it("should clear active alerts", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      service.clearAlert("alert1");

      const activeAlerts = service.getActiveAlerts();

      expect(activeAlerts.length).toBe(0);
    });

    it("should maintain multiple active alerts", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      service.recordAlert("alert2", {
        metric: "errorRate",
        severity: "critical",
        value: 15,
      });

      const activeAlerts = service.getActiveAlerts();

      expect(activeAlerts.length).toBe(2);
    });
  });

  describe("Status Reporting", () => {
    it("should return complete status", () => {
      service.recordAlert("alert1", {
        metric: "responseTime",
        severity: "warning",
        value: 600,
      });

      const status = service.getStatus();

      expect(status).toHaveProperty("thresholds");
      expect(status).toHaveProperty("enabledChannels");
      expect(status).toHaveProperty("activeAlerts");
      expect(status).toHaveProperty("alertHistorySize");
      expect(status).toHaveProperty("cooldownDuration");
      expect(status.activeAlerts.length).toBe(1);
    });
  });
});
