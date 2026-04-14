import {
  createUserManagementDetails,
  createPaymentDetails,
  createSubscriptionDetails,
} from "../../services/api-backend/utils/audit-logger.js";

describe("audit-logger helpers", () => {
  describe("createUserManagementDetails", () => {
    it("returns details with changes, request body, and timestamp", () => {
      const req = { body: { email: "new@example.com" } };
      const changes = { role: "admin" };

      const result = createUserManagementDetails(req, changes);

      expect(result).toMatchObject({
        changes: { role: "admin" },
        requestBody: { email: "new@example.com" },
      });
      expect(result.timestamp).toBeDefined();
      expect(() => new Date(result.timestamp)).not.toThrow();
    });

    it("defaults to empty changes if not provided", () => {
      const req = { body: {} };
      const result = createUserManagementDetails(req);

      expect(result.changes).toEqual({});
      expect(result.requestBody).toEqual({});
    });
  });

  describe("createPaymentDetails", () => {
    it("returns payment details with amount, currency, reason, and transactionId", () => {
      const req = { body: {} };
      const paymentInfo = {
        amount: 29.99,
        currency: "USD",
        reason: "monthly_charge",
        transactionId: "txn_123",
      };

      const result = createPaymentDetails(req, paymentInfo);

      expect(result).toMatchObject({
        amount: 29.99,
        currency: "USD",
        reason: "monthly_charge",
        transactionId: "txn_123",
      });
      expect(result.timestamp).toBeDefined();
    });

    it("defaults to empty object if no paymentInfo", () => {
      const req = {};
      const result = createPaymentDetails(req);

      expect(result.amount).toBeUndefined();
      expect(result.currency).toBeUndefined();
      expect(result.timestamp).toBeDefined();
    });
  });

  describe("createSubscriptionDetails", () => {
    it("returns subscription details with tier and charge info", () => {
      const req = {};
      const subInfo = {
        previousTier: "free",
        newTier: "pro",
        proratedCharge: 15.0,
        effectiveDate: "2026-04-12",
      };

      const result = createSubscriptionDetails(req, subInfo);

      expect(result).toMatchObject({
        previousTier: "free",
        newTier: "pro",
        proratedCharge: 15.0,
        effectiveDate: "2026-04-12",
      });
      expect(result.timestamp).toBeDefined();
    });

    it("defaults gracefully with empty subInfo", () => {
      const result = createSubscriptionDetails({});

      expect(result.previousTier).toBeUndefined();
      expect(result.newTier).toBeUndefined();
      expect(result.timestamp).toBeDefined();
    });
  });

  describe("timestamp consistency", () => {
    it("all helpers produce valid ISO timestamps", () => {
      const req = { body: {} };

      const userResult = createUserManagementDetails(req);
      const paymentResult = createPaymentDetails(req);
      const subResult = createSubscriptionDetails(req);

      [userResult, paymentResult, subResult].forEach((r) => {
        expect(r.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
      });
    });
  });
});
