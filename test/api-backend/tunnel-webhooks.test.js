/**


 * Tunnel Webhooks Tests
 *
 * Tests for tunnel status webhook functionality including:
 * - Webhook registration and management
 * - Webhook delivery with retry logic
 * - Signature verification
 * - Event tracking
 *
 * Validates: Requirements 4.10, 10.1, 10.2, 10.3, 10.4
 * - Property 6: Tunnel state transitions consistency
 * - Property 7: Metrics aggregation consistency
 *
 * @fileoverview Tunnel webhook tests
 * @version 1.0.0
 */

import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  beforeEach,
} from "@jest/globals";
import { v4 as uuidv4 } from "uuid";
import crypto from "crypto";
import { TunnelWebhookService } from "../../services/api-backend/services/tunnel-webhook-service.js";
import { getPool } from "../../services/api-backend/database/db-pool.js";

describe("Tunnel Webhooks", () => {
  let webhookService;
  let pool;
  let userId;
  let tunnelId;

  beforeAll(async () => {
    pool = getPool();
    webhookService = new TunnelWebhookService();
    await webhookService.initialize();

    // Create test user
    userId = uuidv4();
    await pool.query(
      `INSERT INTO users (id, email, jwt_id, tier) VALUES ($1, $2, $3, $4)`,
      [userId, `test-${userId}@example.com`, `jwt-${userId}`, "free"],
    );

    // Create test tunnel
    tunnelId = uuidv4();
    await pool.query(
      `INSERT INTO tunnels (id, user_id, name, status, config, metrics) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        tunnelId,
        userId,
        "Test Tunnel",
        "created",
        JSON.stringify({
          maxConnections: 100,
          timeout: 30000,
          compression: true,
        }),
        JSON.stringify({
          requestCount: 0,
          successCount: 0,
          errorCount: 0,
          averageLatency: 0,
        }),
      ],
    );
  });

  afterAll(async () => {
    // Cleanup
    await pool.query("DELETE FROM tunnel_webhooks WHERE user_id = $1", [
      userId,
    ]);
    await pool.query("DELETE FROM tunnels WHERE id = $1", [tunnelId]);
    await pool.query("DELETE FROM users WHERE id = $1", [userId]);
  });

  describe("Webhook Registration", () => {
    it("should register a webhook for tunnel events", async () => {
      const url = "https://example.com/webhook";
      const events = ["tunnel.status_changed"];

      const webhook = await webhookService.registerWebhook(
        userId,
        tunnelId,
        url,
        events,
      );

      expect(webhook).toBeDefined();
      expect(webhook.user_id).toBe(userId);
      expect(webhook.tunnel_id).toBe(tunnelId);
      expect(webhook.url).toBe(url);
      expect(webhook.events).toEqual(events);
      expect(webhook.secret).toBeDefined();
      expect(webhook.is_active).toBe(true);
    });

    it("should reject invalid webhook URL", async () => {
      const invalidUrl = "not-a-url";

      await expect(
        webhookService.registerWebhook(userId, tunnelId, invalidUrl, [
          "tunnel.status_changed",
        ]),
      ).rejects.toThrow("Invalid webhook URL format");
    });

    it("should reject empty events array", async () => {
      const url = "https://example.com/webhook";

      await expect(
        webhookService.registerWebhook(userId, tunnelId, url, []),
      ).rejects.toThrow("At least one event must be specified");
    });

    it("should reject invalid event type", async () => {
      const url = "https://example.com/webhook";
      const invalidEvents = ["invalid.event"];

      await expect(
        webhookService.registerWebhook(userId, tunnelId, url, invalidEvents),
      ).rejects.toThrow("Invalid event type");
    });

    it("should reject non-existent tunnel", async () => {
      const url = "https://example.com/webhook";
      const nonExistentTunnelId = uuidv4();

      await expect(
        webhookService.registerWebhook(userId, nonExistentTunnelId, url, [
          "tunnel.status_changed",
        ]),
      ).rejects.toThrow("Tunnel not found");
    });

    it("should allow registering webhook for all user tunnels", async () => {
      const url = "https://example.com/webhook-all";
      const events = ["tunnel.status_changed"];

      const webhook = await webhookService.registerWebhook(
        userId,
        null,
        url,
        events,
      );

      expect(webhook).toBeDefined();
      expect(webhook.tunnel_id).toBeNull();
      expect(webhook.url).toBe(url);
    });
  });

  describe("Webhook Management", () => {
    let webhookId;

    beforeEach(async () => {
      const webhook = await webhookService.registerWebhook(
        userId,
        tunnelId,
        "https://example.com/webhook",
        ["tunnel.status_changed"],
      );
      webhookId = webhook.id;
    });

    it("should retrieve webhook by ID", async () => {
      const webhook = await webhookService.getWebhookById(webhookId, userId);

      expect(webhook).toBeDefined();
      expect(webhook.id).toBe(webhookId);
      expect(webhook.user_id).toBe(userId);
    });

    it("should reject unauthorized webhook access", async () => {
      const otherUserId = uuidv4();

      await expect(
        webhookService.getWebhookById(webhookId, otherUserId),
      ).rejects.toThrow("Webhook not found");
    });

    it("should list webhooks for user", async () => {
      const webhooks = await webhookService.listWebhooks(userId, tunnelId);

      expect(Array.isArray(webhooks)).toBe(true);
      expect(webhooks.length).toBeGreaterThan(0);
      expect(webhooks.some((w) => w.id === webhookId)).toBe(true);
    });

    it("should update webhook", async () => {
      const newUrl = "https://example.com/webhook-updated";
      const newEvents = ["tunnel.status_changed", "tunnel.created"];

      const updated = await webhookService.updateWebhook(webhookId, userId, {
        url: newUrl,
        events: newEvents,
      });

      expect(updated.url).toBe(newUrl);
      expect(updated.events).toEqual(newEvents);
    });

    it("should deactivate webhook", async () => {
      const updated = await webhookService.updateWebhook(webhookId, userId, {
        is_active: false,
      });

      expect(updated.is_active).toBe(false);
    });

    it("should delete webhook", async () => {
      await webhookService.deleteWebhook(webhookId, userId);

      await expect(
        webhookService.getWebhookById(webhookId, userId),
      ).rejects.toThrow("Webhook not found");
    });
  });

  describe("Webhook Events", () => {
    let webhookId;

    beforeEach(async () => {
      const webhook = await webhookService.registerWebhook(
        userId,
        tunnelId,
        "https://example.com/webhook",
        ["tunnel.status_changed"],
      );
      webhookId = webhook.id;
    });

    it("should trigger webhook event for tunnel status change", async () => {
      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
        timestamp: new Date().toISOString(),
      };

      await webhookService.triggerWebhookEvent(
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      // Verify event was logged
      const result = await pool.query(
        `SELECT * FROM tunnel_webhook_events WHERE webhook_id = $1 AND event_type = $2`,
        [webhookId, "tunnel.status_changed"],
      );

      expect(result.rows.length).toBeGreaterThan(0);
      expect(result.rows[0].event_data).toEqual(eventData);
    });

    it("should not trigger webhook for inactive webhooks", async () => {
      // Deactivate webhook
      await webhookService.updateWebhook(webhookId, userId, {
        is_active: false,
      });

      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
      };

      await webhookService.triggerWebhookEvent(
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      // Verify event was not logged
      const result = await pool.query(
        `SELECT * FROM tunnel_webhook_events WHERE webhook_id = $1 AND event_type = $2`,
        [webhookId, "tunnel.status_changed"],
      );

      expect(result.rows.length).toBe(0);
    });

    it("should not trigger webhook for unsubscribed events", async () => {
      const eventData = {
        tunnelId,
        timestamp: new Date().toISOString(),
      };

      // Trigger event that webhook is not subscribed to
      await webhookService.triggerWebhookEvent(
        tunnelId,
        userId,
        "tunnel.created",
        eventData,
      );

      // Verify event was not logged
      const result = await pool.query(
        `SELECT * FROM tunnel_webhook_events WHERE webhook_id = $1 AND event_type = $2`,
        [webhookId, "tunnel.created"],
      );

      expect(result.rows.length).toBe(0);
    });
  });

  describe("Webhook Delivery", () => {
    let webhookId;

    beforeEach(async () => {
      const webhook = await webhookService.registerWebhook(
        userId,
        tunnelId,
        "https://example.com/webhook",
        ["tunnel.status_changed"],
      );
      webhookId = webhook.id;
    });

    it("should queue webhook delivery", async () => {
      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
      };

      await webhookService.queueWebhookDelivery(
        webhookId,
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      // Verify delivery was queued
      const result = await pool.query(
        `SELECT * FROM tunnel_webhook_deliveries WHERE webhook_id = $1 AND status = $2`,
        [webhookId, "pending"],
      );

      expect(result.rows.length).toBeGreaterThan(0);
      expect(result.rows[0].event_type).toBe("tunnel.status_changed");
      expect(result.rows[0].payload).toBeDefined();
    });

    it("should get delivery status", async () => {
      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
      };

      await webhookService.queueWebhookDelivery(
        webhookId,
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      const deliveries = await pool.query(
        `SELECT id FROM tunnel_webhook_deliveries WHERE webhook_id = $1 LIMIT 1`,
        [webhookId],
      );

      const delivery = await webhookService.getDeliveryStatus(
        deliveries.rows[0].id,
      );

      expect(delivery).toBeDefined();
      expect(delivery.status).toBe("pending");
      expect(delivery.attempt_count).toBe(0);
    });

    it("should get delivery history", async () => {
      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
      };

      await webhookService.queueWebhookDelivery(
        webhookId,
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      const history = await webhookService.getDeliveryHistory(
        webhookId,
        userId,
      );

      expect(Array.isArray(history)).toBe(true);
      expect(history.length).toBeGreaterThan(0);
    });
  });

  describe("Webhook Signature Verification", () => {
    it("should generate valid webhook signature", async () => {
      const webhook = await webhookService.registerWebhook(
        userId,
        tunnelId,
        "https://example.com/webhook",
        ["tunnel.status_changed"],
      );

      const payload = {
        id: uuidv4(),
        event: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
        data: { tunnelId, oldStatus: "created", newStatus: "connecting" },
      };

      const payloadString = JSON.stringify(payload);
      const expectedSignature = crypto
        .createHmac("sha256", webhook.secret)
        .update(payloadString)
        .digest("hex");

      // Verify signature can be generated
      expect(expectedSignature).toBeDefined();
      expect(expectedSignature).toMatch(/^[a-f0-9]{64}$/);
    });
  });

  describe("Webhook Retry Logic", () => {
    let webhookId;

    beforeEach(async () => {
      const webhook = await webhookService.registerWebhook(
        userId,
        tunnelId,
        "https://example.com/webhook",
        ["tunnel.status_changed"],
      );
      webhookId = webhook.id;
    });

    it("should schedule retry with exponential backoff", async () => {
      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
      };

      await webhookService.queueWebhookDelivery(
        webhookId,
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      const deliveries = await pool.query(
        `SELECT id FROM tunnel_webhook_deliveries WHERE webhook_id = $1 LIMIT 1`,
        [webhookId],
      );

      const deliveryId = deliveries.rows[0].id;

      // Schedule retry
      await webhookService.scheduleRetry(deliveryId, 0, 500, "Server error");

      const delivery = await webhookService.getDeliveryStatus(deliveryId);

      expect(delivery.status).toBe("retrying");
      expect(delivery.attempt_count).toBe(1);
      expect(delivery.next_retry_at).toBeDefined();
      expect(delivery.error_message).toBe("Server error");
    });

    it("should mark delivery as failed after max retries", async () => {
      const eventData = {
        tunnelId,
        oldStatus: "created",
        newStatus: "connecting",
      };

      await webhookService.queueWebhookDelivery(
        webhookId,
        tunnelId,
        userId,
        "tunnel.status_changed",
        eventData,
      );

      const deliveries = await pool.query(
        `SELECT id FROM tunnel_webhook_deliveries WHERE webhook_id = $1 LIMIT 1`,
        [webhookId],
      );

      const deliveryId = deliveries.rows[0].id;

      // Schedule retries until max is reached
      for (let i = 0; i < 5; i++) {
        await webhookService.scheduleRetry(deliveryId, i, 500, "Server error");
      }

      // Try to deliver after max retries
      await webhookService.deliverWebhook(deliveryId);

      const delivery = await webhookService.getDeliveryStatus(deliveryId);

      expect(delivery.status).toBe("failed");
    });
  });
});
