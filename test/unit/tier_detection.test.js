/**
 * Unit Tests for Tier Detection Logic
 *
 * Comprehensive test suite for the tier checking middleware
 * and user tier detection functionality.
 */

import { describe, it, expect } from "@jest/globals";
import {
  getUserTier,
  getTierFeatures,
  hasFeature,
  shouldUseDirectTunnel,
  USER_TIERS,
  TIER_FEATURES,
} from "../../services/api-backend/middleware/tier-check.js";

describe("Tier Detection Logic", () => {
  describe("getUserTier", () => {
    it("should return free tier for null user", () => {
      expect(getUserTier(null)).toBe(USER_TIERS.FREE);
    });

    it("should return free tier for undefined user", () => {
      expect(getUserTier(undefined)).toBe(USER_TIERS.FREE);
    });

    it("should return free tier for invalid user object", () => {
      expect(getUserTier({})).toBe(USER_TIERS.FREE);
      expect(getUserTier({ invalid: "object" })).toBe(USER_TIERS.FREE);
    });

    it("should return free tier for user without sub field", () => {
      const user = {
        "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.FREE);
    });

    it("should detect free tier from user metadata", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "free" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.FREE);
    });

    it("should detect premium tier from user metadata", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.PREMIUM);
    });

    it("should detect enterprise tier from user metadata", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "enterprise" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.ENTERPRISE);
    });

    it("should fallback to app metadata when user metadata is empty", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": {},
        "https://CloudToLocalLLM.com/app_metadata": { tier: "premium" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.PREMIUM);
    });

    it("should fallback to subscription field", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          subscription: "enterprise",
        },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.ENTERPRISE);
    });

    it("should handle case insensitive tier values", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "PREMIUM" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.PREMIUM);
    });

    it("should handle tier values with whitespace", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "  enterprise  " },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.ENTERPRISE);
    });

    it("should default to free for unknown tier values", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "unknown_tier" },
      };
      expect(getUserTier(user)).toBe(USER_TIERS.FREE);
    });

    it("should handle malformed metadata gracefully", () => {
      const user = {
        sub: "jwt|user123",
        "https://CloudToLocalLLM.com/user_metadata": "invalid_metadata",
      };
      expect(getUserTier(user)).toBe(USER_TIERS.FREE);
    });
  });

  describe("getTierFeatures", () => {
    it("should return correct features for free tier", () => {
      const features = getTierFeatures(USER_TIERS.FREE);
      expect(features.containerOrchestration).toBe(false);
      expect(features.teamFeatures).toBe(false);
      expect(features.apiAccess).toBe(false);
      expect(features.directTunnelOnly).toBe(true);
      expect(features.maxConnections).toBe(1);
    });

    it("should return correct features for premium tier", () => {
      const features = getTierFeatures(USER_TIERS.PREMIUM);
      expect(features.containerOrchestration).toBe(true);
      expect(features.teamFeatures).toBe(true);
      expect(features.apiAccess).toBe(true);
      expect(features.directTunnelOnly).toBe(false);
      expect(features.maxConnections).toBe(10);
    });

    it("should return correct features for enterprise tier", () => {
      const features = getTierFeatures(USER_TIERS.ENTERPRISE);
      expect(features.containerOrchestration).toBe(true);
      expect(features.teamFeatures).toBe(true);
      expect(features.apiAccess).toBe(true);
      expect(features.directTunnelOnly).toBe(false);
      expect(features.maxConnections).toBe(-1); // unlimited
    });

    it("should default to free tier features for invalid tier", () => {
      const features = getTierFeatures("invalid_tier");
      expect(features).toEqual(TIER_FEATURES[USER_TIERS.FREE]);
    });

    it("should handle null/undefined tier gracefully", () => {
      expect(getTierFeatures(null)).toEqual(TIER_FEATURES[USER_TIERS.FREE]);
      expect(getTierFeatures(undefined)).toEqual(
        TIER_FEATURES[USER_TIERS.FREE],
      );
    });
  });

  describe("hasFeature", () => {
    const freeUser = {
      sub: "jwt|free123",
      "https://CloudToLocalLLM.com/user_metadata": { tier: "free" },
    };

    const premiumUser = {
      sub: "jwt|premium123",
      "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
    };

    it("should return false for container orchestration for free user", () => {
      expect(hasFeature(freeUser, "containerOrchestration")).toBe(false);
    });

    it("should return true for container orchestration for premium user", () => {
      expect(hasFeature(premiumUser, "containerOrchestration")).toBe(true);
    });

    it("should return false for unknown features", () => {
      expect(hasFeature(premiumUser, "unknownFeature")).toBe(false);
    });

    it("should handle invalid feature names gracefully", () => {
      expect(hasFeature(premiumUser, null)).toBe(false);
      expect(hasFeature(premiumUser, undefined)).toBe(false);
      expect(hasFeature(premiumUser, "")).toBe(false);
    });

    it("should handle invalid user objects gracefully", () => {
      expect(hasFeature(null, "containerOrchestration")).toBe(false);
      expect(hasFeature(undefined, "containerOrchestration")).toBe(false);
    });
  });

  describe("shouldUseDirectTunnel", () => {
    it("should return true for free tier users", () => {
      const user = {
        sub: "jwt|free123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "free" },
      };
      expect(shouldUseDirectTunnel(user)).toBe(true);
    });

    it("should return false for premium tier users", () => {
      const user = {
        sub: "jwt|premium123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
      };
      expect(shouldUseDirectTunnel(user)).toBe(false);
    });

    it("should return false for enterprise tier users", () => {
      const user = {
        sub: "jwt|enterprise123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "enterprise" },
      };
      expect(shouldUseDirectTunnel(user)).toBe(false);
    });

    it("should return true for users with no tier (defaults to free)", () => {
      const user = {
        sub: "jwt|notier123",
        "https://CloudToLocalLLM.com/user_metadata": {},
      };
      expect(shouldUseDirectTunnel(user)).toBe(true);
    });

    it("should handle null user gracefully", () => {
      expect(shouldUseDirectTunnel(null)).toBe(true); // defaults to free
    });
  });

  describe("Integration Tests", () => {
    it("should maintain consistency between tier detection and feature access", () => {
      const testCases = [
        {
          user: {
            sub: "jwt|test1",
            "https://CloudToLocalLLM.com/user_metadata": { tier: "free" },
          },
          expectedTier: USER_TIERS.FREE,
          expectedDirectTunnel: true,
          expectedContainerAccess: false,
        },
        {
          user: {
            sub: "jwt|test2",
            "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
          },
          expectedTier: USER_TIERS.PREMIUM,
          expectedDirectTunnel: false,
          expectedContainerAccess: true,
        },
        {
          user: {
            sub: "jwt|test3",
            "https://CloudToLocalLLM.com/user_metadata": { tier: "enterprise" },
          },
          expectedTier: USER_TIERS.ENTERPRISE,
          expectedDirectTunnel: false,
          expectedContainerAccess: true,
        },
      ];

      testCases.forEach(
        ({
          user,
          expectedTier,
          expectedDirectTunnel,
          expectedContainerAccess,
        }) => {
          const detectedTier = getUserTier(user);
          const useDirectTunnel = shouldUseDirectTunnel(user);
          const hasContainerAccess = hasFeature(user, "containerOrchestration");

          expect(detectedTier).toBe(expectedTier);
          expect(useDirectTunnel).toBe(expectedDirectTunnel);
          expect(hasContainerAccess).toBe(expectedContainerAccess);
        },
      );
    });
  });
});
