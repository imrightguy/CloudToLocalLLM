/**
 * Alert Triggering Service Tests
 *
 * Tests for alert triggering logic:
 * - Metric recording and buffering
 * - Threshold evaluation
 * - Alert triggering
 * - Service lifecycle
 *
 * Requirements: 8.10 (Real-time alerting for critical metrics)
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import AlertTriggeringService from "../../services/api-backend/services/alert-triggering-service.js";

describe("Alert Triggering Service", () => {
  let service;

  beforeEach(() => {
    service = new AlertTriggeringService();
  });

  afterEach(() => {
    if (service.isRunning) {
      service.stop();
    }
  });

  describe("Service Lifecycle", () => {
    it("should start service", () => {
      service.start();

      expect(service.isRunning).toBe(true);
      expect(service.evaluationTimer).toBeDefined();
    });

    it("should stop service", () => {
      service.start();
      service.stop();

      expect(service.isRunning).toBe(false);
      expect(service.evaluationTimer).toBeNull();
    });

    it("should not start if already running", () => {
      service.start();
      const timer1 = service.evaluationTimer;

      service.start();
      const timer2 = service.evaluationTimer;

      expect(timer1).toBe(timer2);
    });

    it("should not stop if not running", () => {
      expect(() => {
        service.stop();
      }).not.toThrow();
    });
  });

  describe("Metric Recording", () => {
    it("should record metric", () => {
      service.recordMetric("responseTime", 450);

      const buffer = service.metricsBuffer.get("responseTime");

      expect(buffer).toBeDefined();
      expect(buffer.length).toBe(1);
      expect(buffer[0].value).toBe(450);
    });

    it("should record multiple metrics", () => {
      service.recordMetric("responseTime", 450);
      service.recordMetric("responseTime", 550);
      service.recordMetric("errorRate", 3);

      expect(service.metricsBuffer.size).toBe(2);
      expect(service.metricsBuffer.get("responseTime").length).toBe(2);
      expect(service.metricsBuffer.get("errorRate").length).toBe(1);
    });

    it("should maintain buffer size limit", () => {
      service.bufferSize = 5;

      for (let i = 0; i < 10; i++) {
        service.recordMetric("responseTime", 400 + i);
      }

      const buffer = service.metricsBuffer.get("responseTime");

      expect(buffer.length).toBeLessThanOrEqual(5);
    });

    it("should record metadata with metric", () => {
      service.recordMetric("responseTime", 450, { endpoint: "/api/users" });

      const buffer = service.metricsBuffer.get("responseTime");

      expect(buffer[0].metadata).toEqual({ endpoint: "/api/users" });
    });
  });

  describe("Metric Statistics", () => {
    it("should calculate metric statistics", () => {
      service.recordMetric("responseTime", 400);
      service.recordMetric("responseTime", 500);
      service.recordMetric("responseTime", 600);

      const stats = service.getMetricStats("responseTime");

      expect(stats).toBeDefined();
      expect(stats.count).toBe(3);
      expect(stats.average).toBe(500);
      expect(stats.max).toBe(600);
      expect(stats.min).toBe(400);
      expect(stats.latest).toBe(600);
    });

    it("should return null for non-existent metric", () => {
      const stats = service.getMetricStats("nonExistent");

      expect(stats).toBeNull();
    });

    it("should handle single metric value", () => {
      service.recordMetric("responseTime", 500);

      const stats = service.getMetricStats("responseTime");

      expect(stats.average).toBe(500);
      expect(stats.max).toBe(500);
      expect(stats.min).toBe(500);
      expect(stats.latest).toBe(500);
    });
  });

  describe("Alert Triggering", () => {
    it("should manually trigger alert without error", async () => {
      // This test verifies that manual trigger doesn't throw
      await expect(
        service.manualTrigger("responseTime", 1500, "critical"),
      ).resolves.not.toThrow();
    });

    it("should trigger alert with metric statistics", async () => {
      service.recordMetric("responseTime", 400);
      service.recordMetric("responseTime", 500);
      service.recordMetric("responseTime", 600);

      const stats = service.getMetricStats("responseTime");

      // Verify stats are calculated correctly
      expect(stats.average).toBe(500);
      expect(stats.max).toBe(600);
      expect(stats.min).toBe(400);

      // Trigger alert should not throw
      await expect(
        service.triggerAlert("responseTime", stats, "warning"),
      ).resolves.not.toThrow();
    });
  });

  describe("Service Status", () => {
    it("should return service status", () => {
      service.recordMetric("responseTime", 450);
      service.recordMetric("errorRate", 3);

      const status = service.getStatus();

      expect(status).toHaveProperty("isRunning");
      expect(status).toHaveProperty("evaluationInterval");
      expect(status).toHaveProperty("metricsTracked");
      expect(status).toHaveProperty("metrics");
      expect(status.metricsTracked).toBe(2);
    });
  });

  describe("All Metric Statistics", () => {
    it("should return all metric statistics", () => {
      service.recordMetric("responseTime", 450);
      service.recordMetric("responseTime", 550);
      service.recordMetric("errorRate", 3);
      service.recordMetric("errorRate", 5);

      const allStats = service.getAllMetricStats();

      expect(allStats).toHaveProperty("responseTime");
      expect(allStats).toHaveProperty("errorRate");
      expect(allStats.responseTime.average).toBe(500);
      expect(allStats.errorRate.average).toBe(4);
    });

    it("should return empty object when no metrics recorded", () => {
      const allStats = service.getAllMetricStats();

      expect(allStats).toEqual({});
    });
  });
});
