/**


 * Property-Based Tests for User Tier System Validation
 *
 * Tests the tier validation middleware and tier-based feature access control
 * to ensure consistent behavior across all user tiers and features.
 *
 * **Feature: api-backend-enhancement, Property 3: Permission enforcement consistency**
 * **Validates: Requirements 2.4**
 */

import { describe, it, expect } from "@jest/globals";
import {
  getUserTier,
  getTierFeatures,
  hasFeature,
  USER_TIERS,
  TIER_FEATURES,
  shouldUseDirectTunnel,
  getUpgradeMessage,
} from "../../services/api-backend/middleware/tier-check.js";

describe("User Tier System Validation", () => {
  describe("getUserTier", () => {
    it("should return free tier for user without tier metadata", () => {
      const user = { sub: "user123" };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should return free tier for null user", () => {
      const tier = getUserTier(null);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should extract tier from user metadata", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "premium",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.PREMIUM);
    });

    it("should extract tier from app metadata", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/app_metadata": {
          tier: "enterprise",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.ENTERPRISE);
    });

    it("should normalize tier to lowercase", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "PREMIUM",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.PREMIUM);
    });

    it("should handle invalid tier by returning free", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "invalid_tier",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should prioritize user_metadata over app_metadata", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "premium",
        },
        "https://CloudToLocalLLM.com/app_metadata": {
          tier: "enterprise",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.PREMIUM);
    });

    it("should handle subscription field as fallback", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          subscription: "premium",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.PREMIUM);
    });
  });

  describe("getTierFeatures", () => {
    it("should return features for free tier", () => {
      const features = getTierFeatures(USER_TIERS.FREE);
      expect(features).toBeDefined();
      expect(features.containerOrchestration).toBe(false);
      expect(features.maxConnections).toBe(1);
    });

    it("should return features for premium tier", () => {
      const features = getTierFeatures(USER_TIERS.PREMIUM);
      expect(features).toBeDefined();
      expect(features.containerOrchestration).toBe(true);
      expect(features.maxConnections).toBe(10);
    });

    it("should return features for enterprise tier", () => {
      const features = getTierFeatures(USER_TIERS.ENTERPRISE);
      expect(features).toBeDefined();
      expect(features.containerOrchestration).toBe(true);
      expect(features.maxConnections).toBe(-1); // unlimited
    });

    it("should return free tier features for invalid tier", () => {
      const features = getTierFeatures("invalid_tier");
      expect(features).toEqual(getTierFeatures(USER_TIERS.FREE));
    });

    it("should normalize tier name to lowercase", () => {
      const features1 = getTierFeatures("PREMIUM");
      const features2 = getTierFeatures(USER_TIERS.PREMIUM);
      expect(features1).toEqual(features2);
    });
  });

  describe("hasFeature", () => {
    it("should return true for free tier user with free tier feature", () => {
      const user = { sub: "user123" };
      const hasAccess = hasFeature(user, "directTunnelOnly");
      expect(hasAccess).toBe(true);
    });

    it("should return false for free tier user without premium feature", () => {
      const user = { sub: "user123" };
      const hasAccess = hasFeature(user, "containerOrchestration");
      expect(hasAccess).toBe(false);
    });

    it("should return true for premium tier user with premium feature", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "premium",
        },
      };
      const hasAccess = hasFeature(user, "containerOrchestration");
      expect(hasAccess).toBe(true);
    });

    it("should return true for enterprise tier user with all features", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "enterprise",
        },
      };
      const hasAccess = hasFeature(user, "containerOrchestration");
      expect(hasAccess).toBe(true);
    });

    it("should return false for unknown feature", () => {
      const user = { sub: "user123" };
      const hasAccess = hasFeature(user, "unknown_feature");
      expect(hasAccess).toBe(false);
    });
  });

  describe("shouldUseDirectTunnel", () => {
    it("should return true for free tier users", () => {
      const user = { sub: "user123" };
      const shouldUse = shouldUseDirectTunnel(user);
      expect(shouldUse).toBe(true);
    });

    it("should return false for premium tier users", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "premium",
        },
      };
      const shouldUse = shouldUseDirectTunnel(user);
      expect(shouldUse).toBe(false);
    });

    it("should return false for enterprise tier users", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "enterprise",
        },
      };
      const shouldUse = shouldUseDirectTunnel(user);
      expect(shouldUse).toBe(false);
    });
  });

  describe("getUpgradeMessage", () => {
    it("should return upgrade message for free tier", () => {
      const message = getUpgradeMessage(USER_TIERS.FREE, "advanced features");
      expect(message).toContain("Premium");
      expect(message).toContain("advanced features");
    });

    it("should return upgrade message for premium tier", () => {
      const message = getUpgradeMessage(
        USER_TIERS.PREMIUM,
        "advanced features",
      );
      expect(message).toContain("Enterprise");
      expect(message).toContain("advanced features");
    });

    it("should return neutral message for enterprise tier", () => {
      const message = getUpgradeMessage(
        USER_TIERS.ENTERPRISE,
        "advanced features",
      );
      expect(message).toContain("current plan");
    });
  });

  describe("Tier Hierarchy Consistency", () => {
    it("should maintain consistent tier hierarchy", () => {
      const tierHierarchy = [
        USER_TIERS.FREE,
        USER_TIERS.PREMIUM,
        USER_TIERS.ENTERPRISE,
      ];

      // Each higher tier should have all features of lower tiers (except directTunnelOnly which is inverse)
      for (let i = 0; i < tierHierarchy.length - 1; i++) {
        const lowerTier = tierHierarchy[i];
        const higherTier = tierHierarchy[i + 1];

        const lowerFeatures = getTierFeatures(lowerTier);
        const higherFeatures = getTierFeatures(higherTier);

        // Check that higher tier has at least the same features as lower tier
        Object.entries(lowerFeatures).forEach(([feature, enabled]) => {
          // Skip directTunnelOnly as it's inverse (true for free, false for premium/enterprise)
          if (feature === "directTunnelOnly") {
            return;
          }
          if (enabled === true) {
            expect(higherFeatures[feature]).toBe(true);
          }
        });
      }
    });

    it("should have consistent feature definitions across all tiers", () => {
      const allFeatures = new Set();

      Object.values(TIER_FEATURES).forEach((tierFeatures) => {
        Object.keys(tierFeatures).forEach((feature) => {
          allFeatures.add(feature);
        });
      });

      // All tiers should have the same set of features
      Object.values(TIER_FEATURES).forEach((tierFeatures) => {
        allFeatures.forEach((feature) => {
          expect(feature in tierFeatures).toBe(true);
        });
      });
    });
  });

  describe("Feature Access Control", () => {
    it("should enforce feature access based on tier", () => {
      const features = [
        "containerOrchestration",
        "teamFeatures",
        "apiAccess",
        "prioritySupport",
        "advancedNetworking",
        "multipleInstances",
      ];

      features.forEach((feature) => {
        const freeUser = { sub: "user1" };
        const premiumUser = {
          sub: "user2",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
        };

        const freeHasAccess = hasFeature(freeUser, feature);
        const premiumHasAccess = hasFeature(premiumUser, feature);

        // Premium users should have access to all features that free users don't
        if (!freeHasAccess) {
          expect(premiumHasAccess).toBe(true);
        }
      });
    });

    it("should handle connection limits correctly", () => {
      const freeFeatures = getTierFeatures(USER_TIERS.FREE);
      const premiumFeatures = getTierFeatures(USER_TIERS.PREMIUM);
      const enterpriseFeatures = getTierFeatures(USER_TIERS.ENTERPRISE);

      // Free tier has fewer connections than premium
      expect(freeFeatures.maxConnections).toBeLessThan(
        premiumFeatures.maxConnections,
      );
      // Premium tier has fewer connections than enterprise (which is unlimited)
      expect(premiumFeatures.maxConnections).toBeGreaterThan(0);
      expect(enterpriseFeatures.maxConnections).toBe(-1); // unlimited
    });

    it("should handle model limits correctly", () => {
      const freeFeatures = getTierFeatures(USER_TIERS.FREE);
      const premiumFeatures = getTierFeatures(USER_TIERS.PREMIUM);
      const enterpriseFeatures = getTierFeatures(USER_TIERS.ENTERPRISE);

      // Free tier has fewer models than premium
      expect(freeFeatures.maxModels).toBeLessThan(premiumFeatures.maxModels);
      // Premium tier has fewer models than enterprise (which is unlimited)
      expect(premiumFeatures.maxModels).toBeGreaterThan(0);
      expect(enterpriseFeatures.maxModels).toBe(-1); // unlimited
    });
  });

  describe("Edge Cases", () => {
    it("should handle user with empty metadata object", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {},
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should handle user with null metadata", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": null,
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should handle user with whitespace-only tier", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "   ",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should handle missing sub field", () => {
      const user = {
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: "premium",
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });

    it("should handle non-string tier value", () => {
      const user = {
        sub: "user123",
        "https://CloudToLocalLLM.com/user_metadata": {
          tier: 123,
        },
      };
      const tier = getUserTier(user);
      expect(tier).toBe(USER_TIERS.FREE);
    });
  });

  describe("Tier Validation Consistency", () => {
    /**
     * Property: For any user, getUserTier should always return a valid tier
     * **Validates: Requirements 2.4**
     */
    it("should always return a valid tier for any user", () => {
      const testUsers = [
        null,
        undefined,
        { sub: "user1" },
        {
          sub: "user2",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
        },
        {
          sub: "user3",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "ENTERPRISE" },
        },
        {
          sub: "user4",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "invalid" },
        },
      ];

      testUsers.forEach((user) => {
        const tier = getUserTier(user);
        expect(Object.values(USER_TIERS)).toContain(tier);
      });
    });

    /**
     * Property: For any valid tier, getTierFeatures should return a consistent feature set
     * **Validates: Requirements 2.4**
     */
    it("should return consistent features for each tier", () => {
      Object.values(USER_TIERS).forEach((tier) => {
        const features1 = getTierFeatures(tier);
        const features2 = getTierFeatures(tier);

        expect(features1).toEqual(features2);
      });
    });

    /**
     * Property: For any user and feature, hasFeature should be consistent with getTierFeatures
     * **Validates: Requirements 2.4**
     */
    it("should maintain consistency between hasFeature and getTierFeatures", () => {
      const testUsers = [
        { sub: "user1" },
        {
          sub: "user2",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
        },
        {
          sub: "user3",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "enterprise" },
        },
      ];

      const features = [
        "containerOrchestration",
        "teamFeatures",
        "apiAccess",
        "prioritySupport",
        "advancedNetworking",
        "multipleInstances",
        "directTunnelOnly",
      ];

      testUsers.forEach((user) => {
        const tier = getUserTier(user);
        const tierFeatures = getTierFeatures(tier);

        features.forEach((feature) => {
          const hasAccessViaFunction = hasFeature(user, feature);
          const hasAccessViaFeatures = tierFeatures[feature] === true;

          expect(hasAccessViaFunction).toBe(hasAccessViaFeatures);
        });
      });
    });
  });
});
