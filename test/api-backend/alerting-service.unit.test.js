/**
 * Unit Tests for AlertingService
 *
 * Tests alerting functionality:
 * - Email alerts
 * - Slack webhook notifications
 * - PagerDuty integration
 * - Multi-channel alert dispatch
 *
 * Issue #175: Implement Backend Unit Tests
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import * as alertingService from "../../services/api-backend/services/alerting-service.js";
import nodemailer from "nodemailer";

// Mock dependencies
jest.mock("nodemailer");
jest.mock("node-fetch");

// Save original env vars
const originalEnv = { ...process.env };

describe("AlertingService", () => {
  beforeEach(() => {
    // Reset environment variables for each test
    process.env = { ...originalEnv };
    jest.clearAllMocks();
  });

  afterEach(() => {
    // Restore original env vars
    process.env = originalEnv;
  });

  describe("getAlertingStatus", () => {
    it("should return alerting status with all channels disabled by default", () => {
      const status = alertingService.getAlertingStatus();
      expect(status).toEqual({
        email: { enabled: false, configured: false, recipient: "" },
        slack: { enabled: false, configured: false },
        pagerduty: { enabled: false, configured: false },
      });
    });

    it("should detect email configuration", () => {
      process.env.ALERT_EMAIL_ENABLED = "true";
      process.env.ALERT_EMAIL_TO = "admin@example.com";
      process.env.ALERT_EMAIL_SMTP_USER = "user";
      process.env.ALERT_EMAIL_SMTP_PASS = "pass";

      const status = alertingService.getAlertingStatus();
      expect(status.email.enabled).toBe(true);
      expect(status.email.configured).toBe(true);
      expect(status.email.recipient).toBe("admin@example.com");
    });

    it("should detect Slack configuration", () => {
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";

      const status = alertingService.getAlertingStatus();
      expect(status.slack.enabled).toBe(true);
      expect(status.slack.configured).toBe(true);
    });

    it("should detect PagerDuty configuration", () => {
      process.env.ALERT_PAGERDUTY_ENABLED = "true";
      process.env.ALERT_PAGERDUTY_INTEGRATION_KEY = "test-key-123";

      const status = alertingService.getAlertingStatus();
      expect(status.pagerduty.enabled).toBe(true);
      expect(status.pagerduty.configured).toBe(true);
    });

    it("should show not configured when missing required fields", () => {
      process.env.ALERT_EMAIL_ENABLED = "true";
      // Missing SMTP credentials

      const status = alertingService.getAlertingStatus();
      expect(status.email.enabled).toBe(true);
      expect(status.email.configured).toBe(false);
    });
  });

  describe("sendAlert", () => {
    const { sendAlert } = alertingService;

    it("should skip email when not enabled", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        { key: "value" },
        "warning",
      );

      expect(results.email.success).toBe(false);
      expect(results.email.reason).toBe("Email alerts not configured");
    });

    it("should skip Slack when not enabled", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.slack.success).toBe(false);
      expect(results.slack.reason).toBe("Slack alerts not configured");
    });

    it("should skip PagerDuty when not enabled", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.pagerduty.success).toBe(false);
      expect(results.pagerduty.reason).toBe("PagerDuty alerts not configured");
    });
  });

  describe("sendSlackAlert (via sendAlert)", () => {
    const { sendAlert } = alertingService;

    beforeEach(() => {
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";
    });

    it("should send Slack alert successfully", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        { userId: 123 },
        "warning",
      );

      expect(results.slack.success).toBe(true);
      expect(fetch).toHaveBeenCalledWith(
        "https://hooks.slack.com/services/test",
        expect.objectContaining({
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: expect.stringContaining("Test Alert"),
        }),
      );
    });

    it("should handle Slack webhook failure", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({
        ok: false,
        status: 400,
        text: async () => "Bad Request",
      });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.slack.success).toBe(false);
      expect(results.slack.reason).toContain("HTTP 400");
    });

    it("should handle Slack network errors", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockRejectedValue(new Error("Network error"));

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.slack.success).toBe(false);
      expect(results.slack.reason).toBe("Network error");
    });

    it("should include metadata in Slack alert", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        { userId: 123, email: "test@example.com" },
        "warning",
      );

      expect(results.slack.success).toBe(true);
      const fetchCallArgs = fetch.mock.calls[0];
      const body = JSON.parse(fetchCallArgs[1].body);
      expect(body.attachments[0].fields).toContainEqual({
        title: "userId",
        value: "123",
        short: true,
      });
      expect(body.attachments[0].fields).toContainEqual({
        title: "email",
        value: "test@example.com",
        short: true,
      });
    });
  });

  describe("sendPagerDutyAlert (via sendAlert)", () => {
    const { sendAlert } = alertingService;

    beforeEach(() => {
      process.env.ALERT_PAGERDUTY_ENABLED = "true";
      process.env.ALERT_PAGERDUTY_INTEGRATION_KEY = "test-key-123";
    });

    it("should send PagerDuty alert successfully", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({
        ok: true,
        json: async () => ({ dedup_key: "dedup-123" }),
      });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        { userId: 123 },
        "critical",
      );

      expect(results.pagerduty.success).toBe(true);
      expect(results.pagerduty.dedupKey).toBe("dedup-123");
      expect(fetch).toHaveBeenCalledWith(
        "https://events.pagerduty.com/v2/enqueue",
        expect.objectContaining({
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: expect.stringContaining("test-key-123"),
        }),
      );
    });

    it("should handle PagerDuty API failure", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({
        ok: false,
        status: 401,
        text: async () => "Unauthorized",
      });

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.pagerduty.success).toBe(false);
      expect(results.pagerduty.reason).toContain("HTTP 401");
    });

    it("should handle PagerDuty network errors", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockRejectedValue(new Error("Network error"));

      const results = await sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.pagerduty.success).toBe(false);
      expect(results.pagerduty.reason).toBe("Network error");
    });

    it("should pass severity correctly to PagerDuty", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({
        ok: true,
        json: async () => ({ dedup_key: "dedup-123" }),
      });

      await sendAlert(
        "test_alert",
        "Critical Alert",
        "This is critical",
        {},
        "critical",
      );

      const fetchCallArgs = fetch.mock.calls[0];
      const body = JSON.parse(fetchCallArgs[1].body);
      expect(body.payload.severity).toBe("critical");
    });
  });

  describe("Multi-channel alert dispatch", () => {
    const { sendAlert } = alertingService;

    beforeEach(() => {
      // Enable all channels
      process.env.ALERT_EMAIL_ENABLED = "true";
      process.env.ALERT_EMAIL_TO = "admin@example.com";
      process.env.ALERT_EMAIL_SMTP_USER = "user";
      process.env.ALERT_EMAIL_SMTP_PASS = "pass";
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";
      process.env.ALERT_PAGERDUTY_ENABLED = "true";
      process.env.ALERT_PAGERDUTY_INTEGRATION_KEY = "test-key-123";

      const { fetch } = require("node-fetch");
      fetch.mockResolvedValue({ ok: true });
    });

    it("should send alert to all enabled channels", async () => {
      const results = await sendAlert(
        "test_alert",
        "Multi-channel Alert",
        "Alert sent to all channels",
        { metadata: "value" },
        "error",
      );

      expect(results.email.success).toBe(true);
      expect(results.slack.success).toBe(true);
      expect(results.pagerduty.success).toBe(true);
    });

    it("should handle partial failures gracefully", async () => {
      const { fetch } = require("node-fetch");
      fetch.mockImplementation((url) => {
        if (url.includes("pagerduty")) {
          return Promise.resolve({
            ok: false,
            status: 500,
            text: async () => "Error",
          });
        }
        return Promise.resolve({ ok: true });
      });

      const results = await sendAlert(
        "test_alert",
        "Partial Failure Alert",
        "Some channels fail",
      );

      expect(results.email.success).toBe(true);
      expect(results.slack.success).toBe(true);
      expect(results.pagerduty.success).toBe(false);
      expect(results.pagerduty.reason).toContain("HTTP 500");
    });
  });

  describe("Alert metadata handling", () => {
    const { sendAlert } = alertingService;

    beforeEach(() => {
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";
    });

    it("should handle empty metadata", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const results = await sendAlert(
        "test_alert",
        "No Metadata Alert",
        "Alert with no metadata",
      );

      expect(results.slack.success).toBe(true);
    });

    it("should handle complex nested metadata", async () => {
      const { fetch } = await import("node-fetch");
      fetch.mockResolvedValue({ ok: true });

      const complexMetadata = {
        userId: 123,
        error: { message: "Test error", stack: "..." },
        timing: { start: 123456, end: 123457 },
      };

      const results = await sendAlert(
        "test_alert",
        "Complex Metadata",
        "Alert with complex metadata",
        complexMetadata,
      );

      expect(results.slack.success).toBe(true);
      const fetchCallArgs = fetch.mock.calls[0];
      const body = JSON.parse(fetchCallArgs[1].body);
      expect(body.attachments[0].fields).toBeDefined();
    });
  });
});
