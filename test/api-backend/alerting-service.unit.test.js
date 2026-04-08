/**
 * Unit Tests for Alerting Service
 *
 * Tests alerting capabilities: email, Slack, PagerDuty.
 * Uses dependency injection (_testSetFetch, _testSetNodemailer) to avoid ESM mocking issues.
 */

import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from "@jest/globals";
import * as alertingService from "../../services/api-backend/services/alerting-service.js";

const mockFetch = jest.fn();
const mockSendMail = jest.fn();
const mockCreateTransport = jest.fn();

const mockNodemailer = {
  createTransport: mockCreateTransport,
};

const originalEnv = { ...process.env };

describe("AlertingService", () => {
  beforeEach(() => {
    process.env = { ...originalEnv };
    jest.clearAllMocks();
    mockFetch.mockReset();
    mockCreateTransport.mockReset();
    mockSendMail.mockReset();

    mockCreateTransport.mockReturnValue({ sendMail: mockSendMail });
    mockSendMail.mockResolvedValue({ messageId: "test-msg-id" });
    mockFetch.mockResolvedValue({ ok: true });

    alertingService._testSetFetch(mockFetch);
    alertingService._testSetNodemailer(mockNodemailer);
    alertingService._testReset();
    // Re-inject after reset (reset restores originals)
    alertingService._testSetFetch(mockFetch);
    alertingService._testSetNodemailer(mockNodemailer);
  });

  afterEach(() => {
    process.env = originalEnv;
    alertingService._testReset();
  });

  describe("getAlertingStatus", () => {
    it("should return status with all channels disabled by default", () => {
      const status = alertingService.getAlertingStatus();
      expect(status.email.enabled).toBe(false);
      expect(status.slack.enabled).toBe(false);
      expect(status.pagerduty.enabled).toBe(false);
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
      process.env.ALERT_PAGERDUTY_INTEGRATION_KEY = "test-key";

      const status = alertingService.getAlertingStatus();
      expect(status.pagerduty.enabled).toBe(true);
      expect(status.pagerduty.configured).toBe(true);
    });

    it("should show not configured when missing required fields", () => {
      process.env.ALERT_EMAIL_ENABLED = "true";
      process.env.ALERT_EMAIL_TO = "admin@example.com";

      const status = alertingService.getAlertingStatus();
      expect(status.email.enabled).toBe(true);
      expect(status.email.configured).toBe(false);
    });
  });

  describe("sendAlert", () => {
    it("should skip email when not enabled", async () => {
      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        { key: "value" },
      );
      expect(results.email.success).toBe(false);
    });

    it("should skip Slack when not enabled", async () => {
      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );
      expect(results.slack.success).toBe(false);
    });

    it("should skip PagerDuty when not enabled", async () => {
      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );
      expect(results.pagerduty.success).toBe(false);
    });
  });

  describe("sendSlackAlert (via sendAlert)", () => {
    beforeEach(() => {
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";
    });

    it("should send Slack alert successfully", async () => {
      mockFetch.mockResolvedValue({ ok: true });

      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        {},
      );

      expect(results.slack.success).toBe(true);
      expect(mockFetch).toHaveBeenCalledWith(
        "https://hooks.slack.com/services/test",
        expect.objectContaining({
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: expect.stringContaining("Test Alert"),
        }),
      );
    });

    it("should handle Slack webhook failure", async () => {
      mockFetch.mockResolvedValue({
        ok: false,
        status: 400,
        text: async () => "Bad Request",
      });

      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.slack.success).toBe(false);
      expect(results.slack.reason).toContain("HTTP 400");
    });

    it("should handle Slack network errors", async () => {
      mockFetch.mockRejectedValue(new Error("Network error"));

      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
      );

      expect(results.slack.success).toBe(false);
      expect(results.slack.reason).toBe("Network error");
    });
  });

  describe("sendPagerDutyAlert (via sendAlert)", () => {
    beforeEach(() => {
      process.env.ALERT_PAGERDUTY_ENABLED = "true";
      process.env.ALERT_PAGERDUTY_INTEGRATION_KEY = "test-key-123";
    });

    it("should send PagerDuty alert successfully", async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({ dedup_key: "test-dedup-key" }),
      });

      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        {},
        "critical",
      );

      expect(results.pagerduty.success).toBe(true);
      expect(results.pagerduty.dedupKey).toBe("test-dedup-key");
    });

    it("should handle PagerDuty API failure", async () => {
      mockFetch.mockResolvedValue({
        ok: false,
        status: 400,
        text: async () => "Invalid routing key",
      });

      const results = await alertingService.sendAlert(
        "test_alert",
        "Test Alert",
        "This is a test alert",
        {},
        "critical",
      );

      expect(results.pagerduty.success).toBe(false);
      expect(results.pagerduty.reason).toContain("HTTP 400");
    });

    it("should include severity in PagerDuty payload", async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({ dedup_key: "test-key" }),
      });

      await alertingService.sendAlert(
        "test_alert",
        "Critical Alert",
        "This is critical",
        {},
        "critical",
      );

      const callArgs = mockFetch.mock.calls.find(
        (c) => c[0] === "https://events.pagerduty.com/v2/enqueue",
      );
      const body = JSON.parse(callArgs[1].body);
      expect(body.payload.severity).toBe("critical");
    });
  });

  describe("Multi-channel alert dispatch", () => {
    beforeEach(() => {
      process.env.ALERT_EMAIL_ENABLED = "true";
      process.env.ALERT_EMAIL_TO = "admin@example.com";
      process.env.ALERT_EMAIL_SMTP_USER = "user";
      process.env.ALERT_EMAIL_SMTP_PASS = "pass";
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";
      process.env.ALERT_PAGERDUTY_ENABLED = "true";
      process.env.ALERT_PAGERDUTY_INTEGRATION_KEY = "test-key-123";

      mockFetch.mockResolvedValue({ ok: true });
      mockFetch.mockImplementation((url) => {
        if (url.includes("pagerduty")) {
          return Promise.resolve({
            ok: true,
            json: async () => ({ dedup_key: "dedup-123" }),
          });
        }
        return Promise.resolve({ ok: true });
      });
    });

    it("should send alert to all enabled channels", async () => {
      const results = await alertingService.sendAlert(
        "test_alert",
        "Multi-channel Alert",
        "Alert sent to all channels",
        { metadata: "value" },
      );

      expect(results.email.success).toBe(true);
      expect(results.slack.success).toBe(true);
      expect(results.pagerduty.success).toBe(true);
    });

    it("should handle partial failures gracefully", async () => {
      mockFetch.mockImplementation((url) => {
        if (url.includes("pagerduty")) {
          return Promise.resolve({
            ok: false,
            status: 500,
            text: async () => "Internal Server Error",
          });
        }
        if (url.includes("slack")) {
          return Promise.resolve({ ok: true });
        }
        return Promise.resolve({ ok: true });
      });

      const results = await alertingService.sendAlert(
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
    beforeEach(() => {
      process.env.ALERT_SLACK_ENABLED = "true";
      process.env.ALERT_SLACK_WEBHOOK_URL =
        "https://hooks.slack.com/services/test";
    });

    it("should handle empty metadata", async () => {
      mockFetch.mockResolvedValue({ ok: true });

      const results = await alertingService.sendAlert(
        "test_alert",
        "No Metadata Alert",
        "Alert with no metadata",
      );

      expect(results.slack.success).toBe(true);
    });

    it("should handle complex nested metadata", async () => {
      mockFetch.mockResolvedValue({ ok: true });

      const complexMetadata = {
        userId: 123,
        error: { message: "Test error", stack: "..." },
        timing: { start: 123456, end: 123457 },
      };

      const results = await alertingService.sendAlert(
        "test_alert",
        "Complex Metadata",
        "Alert with complex metadata",
        complexMetadata,
      );

      expect(results.slack.success).toBe(true);
      const slackCall = mockFetch.mock.calls.find(
        (c) => c[0] === "https://hooks.slack.com/services/test",
      );
      const body = JSON.parse(slackCall[1].body);
      expect(body.attachments[0].fields).toBeDefined();
    });
  });
});
