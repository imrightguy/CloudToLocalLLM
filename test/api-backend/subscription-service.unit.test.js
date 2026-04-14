/**
 * SubscriptionService Unit Tests
 *
 * Tests for subscription management — create, update, cancel, webhook handling.
 * Mocks Stripe client, logger, and database.
 */

import { jest, describe, it, expect, beforeEach } from "@jest/globals";

jest.unstable_mockModule(
  "../../services/api-backend/services/stripe-client.js",
  () => ({
    default: {
      getClient: jest.fn(),
      handleStripeError: jest.fn((e) => ({
        message: e.message,
        type: "stripe_error",
      })),
    },
  }),
);

jest.unstable_mockModule("../../services/api-backend/logger.js", () => ({
  default: {
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
  },
}));

jest.unstable_mockModule("uuid", () => ({
  v4: jest.fn(() => "test-uuid-1234"),
}));

const { default: SubscriptionService } = await import(
  "../../services/api-backend/services/subscription-service.js"
);
const { default: stripeClient } = await import(
  "../../services/api-backend/services/stripe-client.js"
);

function createMockDb(queryResults = {}) {
  const queries = [];
  const db = {
    query: jest.fn(async (sql, params) => {
      queries.push({ sql, params });
      for (const [key, result] of Object.entries(queryResults)) {
        if (sql.includes(key)) {
          return result;
        }
      }
      return { rows: [], rowCount: 0 };
    }),
    _queries: queries,
  };
  return db;
}

describe("SubscriptionService", () => {
  let service;
  let mockDb;
  let mockStripe;

  beforeEach(() => {
    jest.clearAllMocks();

    mockStripe = {
      customers: { create: jest.fn() },
      paymentMethods: { attach: jest.fn() },
      subscriptions: {
        create: jest.fn(),
        retrieve: jest.fn(),
        update: jest.fn(),
        cancel: jest.fn(),
      },
    };

    stripeClient.getClient.mockReturnValue(mockStripe);
    stripeClient.handleStripeError.mockImplementation((e) => ({
      message: e.message,
      type: "stripe_error",
    }));

    mockDb = createMockDb();
    service = new SubscriptionService(mockDb);
  });

  describe("_mapSubscriptionStatus", () => {
    it("should map all known Stripe statuses correctly", () => {
      expect(service._mapSubscriptionStatus("active")).toBe("active");
      expect(service._mapSubscriptionStatus("canceled")).toBe("canceled");
      expect(service._mapSubscriptionStatus("incomplete")).toBe("incomplete");
      expect(service._mapSubscriptionStatus("incomplete_expired")).toBe("canceled");
      expect(service._mapSubscriptionStatus("past_due")).toBe("past_due");
      expect(service._mapSubscriptionStatus("trialing")).toBe("trialing");
      expect(service._mapSubscriptionStatus("unpaid")).toBe("past_due");
    });

    it("should default unknown statuses to incomplete", () => {
      expect(service._mapSubscriptionStatus("unknown_status")).toBe("incomplete");
      expect(service._mapSubscriptionStatus("")).toBe("incomplete");
    });
  });

  describe("getSubscription", () => {
    it("should return subscription when found", async () => {
      const sub = { id: "sub-1", tier: "premium", status: "active" };
      mockDb = createMockDb({ "WHERE id = $1": { rows: [sub], rowCount: 1 } });
      service = new SubscriptionService(mockDb);

      const result = await service.getSubscription("sub-1");
      expect(result).toEqual(sub);
    });

    it("should return null when not found", async () => {
      mockDb = createMockDb({ "WHERE id = $1": { rows: [], rowCount: 0 } });
      service = new SubscriptionService(mockDb);

      const result = await service.getSubscription("nonexistent");
      expect(result).toBeNull();
    });
  });

  describe("getUserSubscriptions", () => {
    it("should return subscriptions for a user", async () => {
      const subs = [
        { id: "sub-1", user_id: "user-1", tier: "premium" },
        { id: "sub-2", user_id: "user-1", tier: "free" },
      ];
      mockDb = createMockDb({ "WHERE user_id = $1": { rows: subs, rowCount: 2 } });
      service = new SubscriptionService(mockDb);

      const result = await service.getUserSubscriptions("user-1");
      expect(result).toEqual(subs);
      expect(result).toHaveLength(2);
    });

    it("should return empty array when user has no subscriptions", async () => {
      mockDb = createMockDb({ "WHERE user_id = $1": { rows: [], rowCount: 0 } });
      service = new SubscriptionService(mockDb);

      const result = await service.getUserSubscriptions("user-no-subs");
      expect(result).toEqual([]);
    });
  });

  describe("initialize", () => {
    it("should set stripe client from stripeClient module", () => {
      expect(service.stripe).toBeNull();
      service.initialize();
      expect(service.stripe).toBe(mockStripe);
      expect(stripeClient.getClient).toHaveBeenCalledTimes(1);
    });
  });

  describe("createSubscription", () => {
    it("should successfully create a subscription", async () => {
      const dbSub = { id: "test-uuid-1234", user_id: "user-1", tier: "premium", status: "active" };
      let callIndex = 0;
      mockDb.query.mockImplementation(async () => {
        callIndex++;
        if (callIndex === 1) return { rows: [{ email: "test@example.com" }] };
        if (callIndex === 2) return { rows: [] };
        if (callIndex === 3) return { rows: [dbSub], rowCount: 1 };
        return { rows: [] };
      });

      mockStripe.customers.create.mockResolvedValue({ id: "cus_test123" });
      mockStripe.subscriptions.create.mockResolvedValue({
        id: "stripe_sub_123",
        status: "active",
        current_period_start: 1700000000,
        current_period_end: 1702000000,
        cancel_at_period_end: false,
        canceled_at: null,
        trial_start: null,
        trial_end: null,
      });

      const result = await service.createSubscription({
        userId: "user-1",
        tier: "premium",
        paymentMethodId: "pm_test123",
        priceId: "price_test123",
      });

      expect(result.success).toBe(true);
      expect(result.subscription).toEqual(dbSub);
      expect(mockStripe.subscriptions.create).toHaveBeenCalledWith(
        expect.objectContaining({
          customer: "cus_test123",
          items: [{ price: "price_test123" }],
          default_payment_method: "pm_test123",
        }),
      );
    });

    it("should reuse existing Stripe customer", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async () => {
        callIndex++;
        if (callIndex === 1) return { rows: [{ email: "test@example.com" }] };
        if (callIndex === 2) return { rows: [{ stripe_customer_id: "cus_existing" }] };
        if (callIndex === 3) return { rows: [{ id: "test-uuid-1234", status: "active" }] };
        return { rows: [] };
      });

      mockStripe.paymentMethods.attach.mockResolvedValue({});
      mockStripe.subscriptions.create.mockResolvedValue({
        id: "stripe_sub_456",
        status: "active",
        current_period_start: 1700000000,
        current_period_end: 1702000000,
        cancel_at_period_end: false,
        canceled_at: null,
        trial_start: null,
        trial_end: null,
      });

      const result = await service.createSubscription({
        userId: "user-1",
        tier: "premium",
        paymentMethodId: "pm_test123",
        priceId: "price_test123",
      });

      expect(result.success).toBe(true);
      expect(mockStripe.paymentMethods.attach).toHaveBeenCalledWith("pm_test123", {
        customer: "cus_existing",
      });
      expect(mockStripe.customers.create).not.toHaveBeenCalled();
    });

    it("should return error when user not found", async () => {
      mockDb.query.mockResolvedValue({ rows: [] });

      const result = await service.createSubscription({
        userId: "nonexistent",
        tier: "premium",
        paymentMethodId: "pm_test123",
        priceId: "price_test123",
      });

      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
    });

    it("should handle Stripe API errors", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async () => {
        callIndex++;
        if (callIndex === 1) return { rows: [{ email: "test@example.com" }] };
        return { rows: [] };
      });

      mockStripe.customers.create.mockRejectedValue(new Error("Stripe API error"));

      const result = await service.createSubscription({
        userId: "user-1",
        tier: "premium",
        paymentMethodId: "pm_test123",
        priceId: "price_test123",
      });

      expect(result.success).toBe(false);
      expect(stripeClient.handleStripeError).toHaveBeenCalled();
    });
  });

  describe("updateSubscription", () => {
    it("should return error when subscription not found", async () => {
      mockDb.query.mockResolvedValue({ rows: [] });

      const result = await service.updateSubscription("nonexistent", { tier: "enterprise" });
      expect(result.success).toBe(false);
    });

    it("should update subscription with new price", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async (sql) => {
        callIndex++;
        if (sql.includes("WHERE id = $1") && callIndex === 1) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1", tier: "premium" }] };
        }
        if (sql.includes("UPDATE")) {
          return { rows: [{ id: "sub-1", tier: "premium", status: "active" }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.retrieve.mockResolvedValue({
        id: "stripe_sub_1",
        items: { data: [{ id: "si_test" }] },
      });
      mockStripe.subscriptions.update.mockResolvedValue({
        id: "stripe_sub_1",
        status: "active",
        current_period_start: 1700000000,
        current_period_end: 1702000000,
        cancel_at_period_end: false,
        canceled_at: null,
      });

      const result = await service.updateSubscription("sub-1", { priceId: "price_new" });

      expect(result.success).toBe(true);
      expect(mockStripe.subscriptions.update).toHaveBeenCalledWith(
        "stripe_sub_1",
        expect.objectContaining({ items: [{ id: "si_test", price: "price_new" }] }),
      );
    });

    it("should update cancel_at_period_end flag", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async (sql) => {
        callIndex++;
        if (sql.includes("WHERE id = $1") && callIndex === 1) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1" }] };
        }
        if (sql.includes("UPDATE")) {
          return { rows: [{ id: "sub-1", cancel_at_period_end: true }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.update.mockResolvedValue({
        id: "stripe_sub_1",
        status: "active",
        current_period_start: 1700000000,
        current_period_end: 1702000000,
        cancel_at_period_end: true,
        canceled_at: null,
      });

      const result = await service.updateSubscription("sub-1", { cancelAtPeriodEnd: true });

      expect(result.success).toBe(true);
      expect(mockStripe.subscriptions.update).toHaveBeenCalledWith("stripe_sub_1", {
        cancel_at_period_end: true,
      });
    });

    it("should handle Stripe errors during update", async () => {
      mockDb.query.mockImplementation(async (sql) => {
        if (sql.includes("WHERE id = $1")) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1" }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.update.mockRejectedValue(new Error("Stripe update failed"));

      const result = await service.updateSubscription("sub-1", { cancelAtPeriodEnd: true });

      expect(result.success).toBe(false);
      expect(stripeClient.handleStripeError).toHaveBeenCalled();
    });
  });

  describe("cancelSubscription", () => {
    it("should return error when subscription not found", async () => {
      mockDb.query.mockResolvedValue({ rows: [] });
      const result = await service.cancelSubscription("nonexistent");
      expect(result.success).toBe(false);
    });

    it("should cancel immediately when immediate=true", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async (sql) => {
        callIndex++;
        if (sql.includes("WHERE id = $1") && callIndex === 1) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1" }] };
        }
        if (sql.includes("UPDATE")) {
          return { rows: [{ id: "sub-1", status: "canceled" }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.cancel.mockResolvedValue({
        id: "stripe_sub_1",
        status: "canceled",
        cancel_at_period_end: false,
        canceled_at: 1700000000,
      });

      const result = await service.cancelSubscription("sub-1", true);

      expect(result.success).toBe(true);
      expect(mockStripe.subscriptions.cancel).toHaveBeenCalledWith("stripe_sub_1");
    });

    it("should cancel at period end when immediate=false", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async (sql) => {
        callIndex++;
        if (sql.includes("WHERE id = $1") && callIndex === 1) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1" }] };
        }
        if (sql.includes("UPDATE")) {
          return { rows: [{ id: "sub-1", status: "active", cancel_at_period_end: true }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.update.mockResolvedValue({
        id: "stripe_sub_1",
        status: "active",
        cancel_at_period_end: true,
        canceled_at: null,
      });

      const result = await service.cancelSubscription("sub-1", false);

      expect(result.success).toBe(true);
      expect(mockStripe.subscriptions.update).toHaveBeenCalledWith("stripe_sub_1", {
        cancel_at_period_end: true,
      });
    });

    it("should default to cancel at period end", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async (sql) => {
        callIndex++;
        if (sql.includes("WHERE id = $1") && callIndex === 1) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1" }] };
        }
        if (sql.includes("UPDATE")) {
          return { rows: [{ id: "sub-1" }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.update.mockResolvedValue({
        id: "stripe_sub_1",
        status: "active",
        cancel_at_period_end: true,
        canceled_at: null,
      });

      await service.cancelSubscription("sub-1");

      expect(mockStripe.subscriptions.update).toHaveBeenCalled();
      expect(mockStripe.subscriptions.cancel).not.toHaveBeenCalled();
    });

    it("should handle Stripe errors during cancellation", async () => {
      mockDb.query.mockImplementation(async (sql) => {
        if (sql.includes("WHERE id = $1")) {
          return { rows: [{ id: "sub-1", stripe_subscription_id: "stripe_sub_1" }] };
        }
        return { rows: [] };
      });

      mockStripe.subscriptions.update.mockRejectedValue(new Error("Stripe cancel failed"));

      const result = await service.cancelSubscription("sub-1", false);

      expect(result.success).toBe(false);
      expect(stripeClient.handleStripeError).toHaveBeenCalled();
    });
  });

  describe("handleWebhook", () => {
    it("should route subscription.created events", async () => {
      await service.handleWebhook({
        type: "customer.subscription.created",
        id: "evt_1",
        data: { object: { id: "sub_1" } },
      });
    });

    it("should route subscription.updated events", async () => {
      mockDb.query.mockResolvedValue({ rows: [] });
      await service.handleWebhook({
        type: "customer.subscription.updated",
        id: "evt_2",
        data: {
          object: {
            id: "stripe_sub_1",
            status: "active",
            current_period_start: 1700000000,
            current_period_end: 1702000000,
            cancel_at_period_end: false,
            canceled_at: null,
          },
        },
      });
    });

    it("should route subscription.deleted events and update DB", async () => {
      mockDb.query.mockResolvedValue({ rows: [], rowCount: 0 });
      await service.handleWebhook({
        type: "customer.subscription.deleted",
        id: "evt_3",
        data: { object: { id: "stripe_sub_1" } },
      });
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringContaining("status = 'canceled'"),
        ["stripe_sub_1"],
      );
    });

    it("should handle invoice.payment_succeeded", async () => {
      await service.handleWebhook({
        type: "invoice.payment_succeeded",
        id: "evt_4",
        data: { object: { id: "inv_1" } },
      });
    });

    it("should handle invoice.payment_failed", async () => {
      await service.handleWebhook({
        type: "invoice.payment_failed",
        id: "evt_5",
        data: { object: { id: "inv_2" } },
      });
    });

    it("should handle unknown event types gracefully", async () => {
      await expect(
        service.handleWebhook({
          type: "unknown.event.type",
          id: "evt_unknown",
          data: { object: {} },
        }),
      ).resolves.not.toThrow();
    });

    it("should re-throw errors from webhook handlers", async () => {
      mockDb.query.mockRejectedValue(new Error("DB error"));
      await expect(
        service.handleWebhook({
          type: "customer.subscription.deleted",
          id: "evt_err",
          data: { object: { id: "sub_err" } },
        }),
      ).rejects.toThrow("DB error");
    });
  });

  describe("_handleSubscriptionUpdated", () => {
    it("should update subscription when found by Stripe ID", async () => {
      let callIndex = 0;
      mockDb.query.mockImplementation(async (sql) => {
        callIndex++;
        if (sql.includes("stripe_subscription_id = $1") && callIndex === 1) {
          return { rows: [{ id: "sub-1" }] };
        }
        return { rows: [] };
      });

      await service._handleSubscriptionUpdated({
        id: "stripe_sub_1",
        status: "active",
        current_period_start: 1700000000,
        current_period_end: 1702000000,
        cancel_at_period_end: false,
        canceled_at: null,
      });

      expect(mockDb.query).toHaveBeenCalledTimes(2);
    });

    it("should skip update when subscription not found by Stripe ID", async () => {
      mockDb.query.mockResolvedValue({ rows: [] });

      await service._handleSubscriptionUpdated({
        id: "nonexistent_stripe_sub",
        status: "active",
        current_period_start: 1700000000,
        current_period_end: 1702000000,
        cancel_at_period_end: false,
        canceled_at: null,
      });

      expect(mockDb.query).toHaveBeenCalledTimes(1);
    });
  });
});
