/**


 * Tunnel Sharing and Access Control Tests
 *
 * Tests for tunnel sharing functionality including:
 * - Sharing tunnels with other users
 * - Managing permissions (read, write, admin)
 * - Creating and revoking share tokens
 * - Verifying access control
 * - Tracking access logs
 *
 * Validates: Requirements 4.8
 * - Supports tunnel sharing and access control
 * - Implements permission management for tunnel access
 *
 * @fileoverview Tunnel sharing tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeAll, afterAll } from "@jest/globals";
import { v4 as uuidv4 } from "uuid";
import { TunnelSharingService } from "../../services/api-backend/services/tunnel-sharing-service.js";
import { getPool } from "../../services/api-backend/database/db-pool.js";

describe("Tunnel Sharing Service", () => {
  let tunnelSharingService;
  let pool;
  let testUserId1;
  let testUserId2;
  let testTunnelId;

  beforeAll(async () => {
    // Initialize service
    tunnelSharingService = new TunnelSharingService();
    await tunnelSharingService.initialize();
    pool = getPool();

    // Create test users
    testUserId1 = uuidv4();
    testUserId2 = uuidv4();

    // Insert test users
    await pool.query(
      `INSERT INTO users (id, email, jwt_id, tier, is_active)
       VALUES ($1, $2, $3, $4, $5)`,
      [testUserId1, "test1@example.com", "jwt|test1", "free", true],
    );

    await pool.query(
      `INSERT INTO users (id, email, jwt_id, tier, is_active)
       VALUES ($1, $2, $3, $4, $5)`,
      [testUserId2, "test2@example.com", "jwt|test2", "free", true],
    );

    // Create test tunnel
    testTunnelId = uuidv4();
    await pool.query(
      `INSERT INTO tunnels (id, user_id, name, status, config)
       VALUES ($1, $2, $3, $4, $5)`,
      [testTunnelId, testUserId1, "Test Tunnel", "created", "{}"],
    );
  });

  afterAll(async () => {
    // Clean up test data
    await pool.query("DELETE FROM tunnel_shares WHERE tunnel_id = $1", [
      testTunnelId,
    ]);
    await pool.query("DELETE FROM tunnel_share_tokens WHERE tunnel_id = $1", [
      testTunnelId,
    ]);
    await pool.query("DELETE FROM tunnel_access_logs WHERE tunnel_id = $1", [
      testTunnelId,
    ]);
    await pool.query("DELETE FROM tunnels WHERE id = $1", [testTunnelId]);
    await pool.query("DELETE FROM users WHERE id = $1", [testUserId1]);
    await pool.query("DELETE FROM users WHERE id = $1", [testUserId2]);
  });

  describe("shareTunnel", () => {
    it("should share a tunnel with another user", async () => {
      const share = await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      expect(share).toBeDefined();
      expect(share.tunnelId).toBe(testTunnelId);
      expect(share.ownerId).toBe(testUserId1);
      expect(share.sharedWithUserId).toBe(testUserId2);
      expect(share.permission).toBe("read");
    });

    it("should not share tunnel with non-existent user", async () => {
      const nonExistentUserId = uuidv4();

      await expect(
        tunnelSharingService.shareTunnel(
          testTunnelId,
          testUserId1,
          nonExistentUserId,
          "read",
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("User to share with not found");
    });

    it("should not share tunnel with self", async () => {
      await expect(
        tunnelSharingService.shareTunnel(
          testTunnelId,
          testUserId1,
          testUserId1,
          "read",
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("Cannot share tunnel with yourself");
    });

    it("should reject invalid permission", async () => {
      await expect(
        tunnelSharingService.shareTunnel(
          testTunnelId,
          testUserId1,
          testUserId2,
          "invalid",
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("Invalid permission");
    });

    it("should not share tunnel not owned by user", async () => {
      const otherTunnelId = uuidv4();
      await pool.query(
        `INSERT INTO tunnels (id, user_id, name, status, config)
         VALUES ($1, $2, $3, $4, $5)`,
        [otherTunnelId, testUserId2, "Other Tunnel", "created", "{}"],
      );

      await expect(
        tunnelSharingService.shareTunnel(
          otherTunnelId,
          testUserId1,
          testUserId2,
          "read",
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("Tunnel not found or you do not have permission");

      await pool.query("DELETE FROM tunnels WHERE id = $1", [otherTunnelId]);
    });
  });

  describe("getTunnelShares", () => {
    it("should get all shares for a tunnel", async () => {
      // Create a share first
      await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "write",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      const shares = await tunnelSharingService.getTunnelShares(
        testTunnelId,
        testUserId1,
      );

      expect(Array.isArray(shares)).toBe(true);
      expect(shares.length).toBeGreaterThan(0);
      expect(shares[0].tunnelId).toBe(testTunnelId);
      expect(shares[0].permission).toBe("write");
    });

    it("should not get shares for tunnel not owned by user", async () => {
      const otherTunnelId = uuidv4();
      await pool.query(
        `INSERT INTO tunnels (id, user_id, name, status, config)
         VALUES ($1, $2, $3, $4, $5)`,
        [otherTunnelId, testUserId2, "Other Tunnel", "created", "{}"],
      );

      await expect(
        tunnelSharingService.getTunnelShares(otherTunnelId, testUserId1),
      ).rejects.toThrow("Tunnel not found or you do not have permission");

      await pool.query("DELETE FROM tunnels WHERE id = $1", [otherTunnelId]);
    });
  });

  describe("revokeTunnelAccess", () => {
    it("should revoke tunnel access from a user", async () => {
      // Create a share first
      await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      // Revoke access
      await tunnelSharingService.revokeTunnelAccess(
        testTunnelId,
        testUserId1,
        testUserId2,
        "127.0.0.1",
        "Mozilla/5.0",
      );

      // Verify access is revoked
      const shares = await tunnelSharingService.getTunnelShares(
        testTunnelId,
        testUserId1,
      );
      const revokedShare = shares.find(
        (s) => s.shared_with_user_id === testUserId2,
      );
      expect(revokedShare.is_active).toBe(false);
    });

    it("should not revoke access for tunnel not owned by user", async () => {
      const otherTunnelId = uuidv4();
      await pool.query(
        `INSERT INTO tunnels (id, user_id, name, status, config)
         VALUES ($1, $2, $3, $4, $5)`,
        [otherTunnelId, testUserId2, "Other Tunnel", "created", "{}"],
      );

      await expect(
        tunnelSharingService.revokeTunnelAccess(
          otherTunnelId,
          testUserId1,
          testUserId2,
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("Tunnel not found or you do not have permission");

      await pool.query("DELETE FROM tunnels WHERE id = $1", [otherTunnelId]);
    });
  });

  describe("createShareToken", () => {
    it("should create a share token", async () => {
      const token = await tunnelSharingService.createShareToken(
        testTunnelId,
        testUserId1,
        "read",
        24,
        null,
        "127.0.0.1",
        "Mozilla/5.0",
      );

      expect(token).toBeDefined();
      expect(token.id).toBeDefined();
      expect(token.token).toBeDefined();
      expect(token.tunnelId).toBe(testTunnelId);
      expect(token.permission).toBe("read");
      expect(token.expiresAt).toBeDefined();
    });

    it("should create token with max uses", async () => {
      const token = await tunnelSharingService.createShareToken(
        testTunnelId,
        testUserId1,
        "write",
        24,
        10,
        "127.0.0.1",
        "Mozilla/5.0",
      );

      expect(token.maxUses).toBe(10);
    });

    it("should reject invalid permission for token", async () => {
      await expect(
        tunnelSharingService.createShareToken(
          testTunnelId,
          testUserId1,
          "invalid",
          24,
          null,
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("Invalid permission");
    });
  });

  describe("getShareTokens", () => {
    it("should get all share tokens for a tunnel", async () => {
      // Create a token first
      await tunnelSharingService.createShareToken(
        testTunnelId,
        testUserId1,
        "read",
        24,
        null,
        "127.0.0.1",
        "Mozilla/5.0",
      );

      const tokens = await tunnelSharingService.getShareTokens(
        testTunnelId,
        testUserId1,
      );

      expect(Array.isArray(tokens)).toBe(true);
      expect(tokens.length).toBeGreaterThan(0);
      expect(tokens[0].tunnelId).toBe(testTunnelId);
    });
  });

  describe("revokeShareToken", () => {
    it("should revoke a share token", async () => {
      // Create a token first
      const token = await tunnelSharingService.createShareToken(
        testTunnelId,
        testUserId1,
        "read",
        24,
        null,
        "127.0.0.1",
        "Mozilla/5.0",
      );

      // Revoke token
      await tunnelSharingService.revokeShareToken(
        token.id,
        testUserId1,
        "127.0.0.1",
        "Mozilla/5.0",
      );

      // Verify token is revoked
      const tokens = await tunnelSharingService.getShareTokens(
        testTunnelId,
        testUserId1,
      );
      const revokedToken = tokens.find((t) => t.id === token.id);
      expect(revokedToken.is_active).toBe(false);
    });
  });

  describe("verifyTunnelAccess", () => {
    it("should verify owner has admin access", async () => {
      const access = await tunnelSharingService.verifyTunnelAccess(
        testTunnelId,
        testUserId1,
        "read",
      );

      expect(access.hasAccess).toBe(true);
      expect(access.isOwner).toBe(true);
      expect(access.permission).toBe("admin");
    });

    it("should verify shared user has read access", async () => {
      // Create a share first
      await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      const access = await tunnelSharingService.verifyTunnelAccess(
        testTunnelId,
        testUserId2,
        "read",
      );

      expect(access.hasAccess).toBe(true);
      expect(access.isOwner).toBe(false);
      expect(access.permission).toBe("read");
    });

    it("should deny access for user without permission", async () => {
      const otherUserId = uuidv4();
      await pool.query(
        `INSERT INTO users (id, email, jwt_id, tier, is_active)
         VALUES ($1, $2, $3, $4, $5)`,
        [otherUserId, "test3@example.com", "jwt|test3", "free", true],
      );

      const access = await tunnelSharingService.verifyTunnelAccess(
        testTunnelId,
        otherUserId,
        "read",
      );

      expect(access.hasAccess).toBe(false);
      expect(access.isOwner).toBe(false);

      await pool.query("DELETE FROM users WHERE id = $1", [otherUserId]);
    });

    it("should deny write access when only read is granted", async () => {
      // Create a share with read permission
      await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      const access = await tunnelSharingService.verifyTunnelAccess(
        testTunnelId,
        testUserId2,
        "write",
      );

      expect(access.hasAccess).toBe(false);
    });
  });

  describe("getSharedTunnels", () => {
    it("should get tunnels shared with a user", async () => {
      // Create a share first
      await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      const tunnels = await tunnelSharingService.getSharedTunnels(testUserId2, {
        limit: 50,
        offset: 0,
      });

      expect(Array.isArray(tunnels)).toBe(true);
      const sharedTunnel = tunnels.find((t) => t.id === testTunnelId);
      expect(sharedTunnel).toBeDefined();
      expect(sharedTunnel.permission).toBe("read");
    });
  });

  describe("getTunnelAccessLogs", () => {
    it("should get tunnel access logs", async () => {
      const logs = await tunnelSharingService.getTunnelAccessLogs(
        testTunnelId,
        testUserId1,
        {
          limit: 50,
          offset: 0,
        },
      );

      expect(Array.isArray(logs)).toBe(true);
      expect(logs.length).toBeGreaterThan(0);
      expect(logs[0].tunnelId).toBe(testTunnelId);
    });

    it("should not get logs for tunnel not owned by user", async () => {
      const otherTunnelId = uuidv4();
      await pool.query(
        `INSERT INTO tunnels (id, user_id, name, status, config)
         VALUES ($1, $2, $3, $4, $5)`,
        [otherTunnelId, testUserId2, "Other Tunnel", "created", "{}"],
      );

      await expect(
        tunnelSharingService.getTunnelAccessLogs(otherTunnelId, testUserId1, {
          limit: 50,
          offset: 0,
        }),
      ).rejects.toThrow("Tunnel not found or you do not have permission");

      await pool.query("DELETE FROM tunnels WHERE id = $1", [otherTunnelId]);
    });
  });

  describe("updateSharePermission", () => {
    it("should update share permission", async () => {
      // Create a share first
      const share = await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      // Update permission
      const updated = await tunnelSharingService.updateSharePermission(
        share.id,
        testUserId1,
        "write",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      expect(updated.permission).toBe("write");
    });

    it("should reject invalid permission update", async () => {
      // Create a share first
      const share = await tunnelSharingService.shareTunnel(
        testTunnelId,
        testUserId1,
        testUserId2,
        "read",
        "127.0.0.1",
        "Mozilla/5.0",
      );

      await expect(
        tunnelSharingService.updateSharePermission(
          share.id,
          testUserId1,
          "invalid",
          "127.0.0.1",
          "Mozilla/5.0",
        ),
      ).rejects.toThrow("Invalid permission");
    });
  });
});
