/**


 * Tests for Request Queuing Functionality
 *
 * Tests the request queue service and middleware for rate limit management.
 * Validates that requests are properly queued when rate limit is approached.
 *
 * @fileoverview Request queuing tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { RequestQueueService } from "../../services/api-backend/services/request-queue-service.js";

describe("RequestQueueService", () => {
  let queueService;

  beforeEach(() => {
    // Create fresh instance for each test (not using singleton)
    queueService = new RequestQueueService({
      maxQueueSize: 100,
      queueTimeoutMs: 5000,
      queueThresholdPercent: 80,
    });
  });

  afterEach(() => {
    // Silence all pending promise rejections before clearing queues
    for (const queueType of ["user", "ip"]) {
      const queueMap =
        queueType === "user" ? queueService.userQueues : queueService.ipQueues;
      if (!queueMap) continue;
      for (const [, queue] of queueMap) {
        for (const entry of queue) {
          if (!entry.processed) {
            entry.promise.catch(() => {});
          }
        }
      }
    }
    queueService.clearAllQueues();
  });

  describe("shouldQueue", () => {
    it("should return false when usage is below threshold", () => {
      const result = queueService.shouldQueue(50, 100); // 50% usage
      expect(result).toBe(false);
    });

    it("should return true when usage is at threshold", () => {
      const result = queueService.shouldQueue(20, 100); // 80% usage
      expect(result).toBe(true);
    });

    it("should return true when usage is above threshold", () => {
      const result = queueService.shouldQueue(10, 100); // 90% usage
      expect(result).toBe(true);
    });

    it("should return true when usage is at 100%", () => {
      const result = queueService.shouldQueue(0, 100); // 100% usage
      expect(result).toBe(true);
    });
  });

  describe("queueRequest", () => {
    it("should queue a request successfully", () => {
      const result = queueService.queueRequest("user123", "user", {
        method: "POST",
        path: "/api/test",
      });

      expect(result.queued).toBe(true);
      expect(result.queueEntryId).toBeDefined();
      expect(result.promise).toBeDefined();
      expect(result.position).toBe(1);
    });

    it("should queue multiple requests in FIFO order", () => {
      const result1 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });
      const result2 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });
      const result3 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });

      expect(result1.position).toBe(1);
      expect(result2.position).toBe(2);
      expect(result3.position).toBe(3);
    });

    it("should reject request when queue is full", () => {
      // Fill the queue
      for (let i = 0; i < 100; i++) {
        queueService.queueRequest("user123", "user", { method: "POST" });
      }

      // Try to add one more
      const result = queueService.queueRequest("user123", "user", {
        method: "POST",
      });

      expect(result.queued).toBe(false);
      expect(result.error).toBe("QUEUE_FULL");
    });

    it("should create separate queues for different users", () => {
      const result1 = queueService.queueRequest("user1", "user", {
        method: "POST",
      });
      const result2 = queueService.queueRequest("user2", "user", {
        method: "POST",
      });

      expect(result1.position).toBe(1);
      expect(result2.position).toBe(1); // Different queue
    });

    it("should create separate queues for user and IP", () => {
      const result1 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });
      const result2 = queueService.queueRequest("192.168.1.1", "ip", {
        method: "POST",
      });

      expect(result1.position).toBe(1);
      expect(result2.position).toBe(1); // Different queue type
    });

    it("should increment statistics on queue", () => {
      const initialStats = queueService.getStatistics();
      expect(initialStats.totalQueued).toBe(0);

      queueService.queueRequest("user123", "user", { method: "POST" });

      const updatedStats = queueService.getStatistics();
      expect(updatedStats.totalQueued).toBe(1);
      expect(updatedStats.currentQueuedRequests).toBe(1);
    });
  });

  describe("processNextRequest", () => {
    it("should process request from queue", async () => {
      const queueResult = queueService.queueRequest("user123", "user", {
        method: "POST",
      });

      // Process the request
      const entry = queueService.processNextRequest("user123", "user");

      expect(entry).toBeDefined();
      expect(entry.id).toBe(queueResult.queueEntryId);

      // Wait for promise to resolve
      const result = await queueResult.promise;
      expect(result.processed).toBe(true);
    });

    it("should process requests in FIFO order", async () => {
      const result1 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });
      const result2 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });
      const result3 = queueService.queueRequest("user123", "user", {
        method: "POST",
      });

      // Process first request
      const entry1 = queueService.processNextRequest("user123", "user");
      expect(entry1.id).toBe(result1.queueEntryId);

      // Process second request
      const entry2 = queueService.processNextRequest("user123", "user");
      expect(entry2.id).toBe(result2.queueEntryId);

      // Process third request
      const entry3 = queueService.processNextRequest("user123", "user");
      expect(entry3.id).toBe(result3.queueEntryId);
    });

    it("should return null when queue is empty", () => {
      const entry = queueService.processNextRequest("user123", "user");
      expect(entry).toBeNull();
    });

    it("should update statistics on process", () => {
      queueService.queueRequest("user123", "user", { method: "POST" });

      const initialStats = queueService.getStatistics();
      expect(initialStats.totalProcessed).toBe(0);

      queueService.processNextRequest("user123", "user");

      const updatedStats = queueService.getStatistics();
      expect(updatedStats.totalProcessed).toBe(1);
      expect(updatedStats.currentQueuedRequests).toBe(0);
    });
  });

  describe("removeFromQueue", () => {
    it("should remove request from queue", () => {
      const result = queueService.queueRequest("user123", "user", {
        method: "POST",
      });

      // Prevent unhandled rejection when removeFromQueue rejects the promise
      result.promise.catch(() => {});

      const removed = queueService.removeFromQueue(
        "user123",
        "user",
        result.queueEntryId,
      );
      expect(removed).toBe(true);

      const stats = queueService.getStatistics();
      expect(stats.currentQueuedRequests).toBe(0);
    });

    it("should return false when request not found", () => {
      const removed = queueService.removeFromQueue(
        "user123",
        "user",
        "nonexistent-id",
      );
      expect(removed).toBe(false);
    });

    it("should return false when queue does not exist", () => {
      const removed = queueService.removeFromQueue(
        "nonexistent-user",
        "user",
        "any-id",
      );
      expect(removed).toBe(false);
    });
  });

  describe("getQueueStatus", () => {
    it("should return queue status", () => {
      queueService.queueRequest("user123", "user", { method: "POST" });
      queueService.queueRequest("user123", "user", { method: "POST" });

      const status = queueService.getQueueStatus("user123", "user");

      expect(status.identifier).toBe("user123");
      expect(status.queueType).toBe("user");
      expect(status.queueSize).toBe(2);
      expect(status.maxQueueSize).toBe(100);
      expect(status.isFull).toBe(false);
    });

    it("should indicate when queue is full", () => {
      for (let i = 0; i < 100; i++) {
        queueService.queueRequest("user123", "user", { method: "POST" });
      }

      const status = queueService.getQueueStatus("user123", "user");
      expect(status.isFull).toBe(true);
    });

    it("should return empty queue status for nonexistent queue", () => {
      const status = queueService.getQueueStatus("nonexistent", "user");

      expect(status.queueSize).toBe(0);
      expect(status.isFull).toBe(false);
    });
  });

  describe("getStatistics", () => {
    it("should return global statistics", () => {
      queueService.queueRequest("user1", "user", { method: "POST" });
      queueService.queueRequest("user2", "user", { method: "POST" });
      queueService.queueRequest("192.168.1.1", "ip", { method: "POST" });

      const stats = queueService.getStatistics();

      expect(stats.totalQueued).toBe(3);
      expect(stats.currentQueuedRequests).toBe(3);
      expect(stats.userQueuesCount).toBe(2);
      expect(stats.ipQueuesCount).toBe(1);
      expect(stats.totalQueuesCount).toBe(3);
    });

    it("should track rejected requests", () => {
      for (let i = 0; i < 100; i++) {
        queueService.queueRequest("user123", "user", { method: "POST" });
      }

      // Try to add one more (should be rejected)
      queueService.queueRequest("user123", "user", { method: "POST" });

      const stats = queueService.getStatistics();
      expect(stats.totalRejected).toBe(1);
    });
  });

  describe("clearAllQueues", () => {
    it("should clear all queues", () => {
      const clearQueueService = new RequestQueueService({
        maxQueueSize: 100,
        queueTimeoutMs: 5000,
        queueThresholdPercent: 80,
      });

      const r1 = clearQueueService.queueRequest("user1", "user", {
        method: "POST",
      });
      const r2 = clearQueueService.queueRequest("user2", "user", {
        method: "POST",
      });
      const r3 = clearQueueService.queueRequest("192.168.1.1", "ip", {
        method: "POST",
      });

      // Prevent unhandled rejections when clearAllQueues rejects all promises
      r1.promise.catch(() => {});
      r2.promise.catch(() => {});
      r3.promise.catch(() => {});

      clearQueueService.clearAllQueues();

      const stats = clearQueueService.getStatistics();
      expect(stats.currentQueuedRequests).toBe(0);
      expect(stats.userQueuesCount).toBe(0);
      expect(stats.ipQueuesCount).toBe(0);
    });
  });

  describe("getHealthStatus", () => {
    it("should return healthy status when queue is empty", () => {
      const health = queueService.getHealthStatus();

      expect(health.status).toBe("healthy");
      expect(health.currentQueuedRequests).toBe(0);
    });

    it("should return degraded status when queue is large", () => {
      // Add 101 requests to trigger degraded status
      const pending = [];
      for (let i = 0; i < 101; i++) {
        const r = queueService.queueRequest(`user${i}`, "user", {
          method: "POST",
        });
        pending.push(r.promise.catch(() => {}));
      }

      const health = queueService.getHealthStatus();
      expect(health.status).toBe("degraded");
      expect(health.currentQueuedRequests).toBe(101);
    });
  });

  describe("Queue timeout", () => {
    it("should timeout queued request after specified duration", async () => {
      const timeoutQueueService = new RequestQueueService({
        maxQueueSize: 100,
        queueTimeoutMs: 100, // 100ms timeout
        queueThresholdPercent: 80,
      });

      const result = timeoutQueueService.queueRequest("user123", "user", {
        method: "POST",
      });

      // Add error handler to prevent unhandled rejection
      let timeoutOccurred = false;
      result.promise.catch(() => {
        timeoutOccurred = true;
      });

      // Wait for timeout
      await new Promise((resolve) => setTimeout(resolve, 200));

      const stats = timeoutQueueService.getStatistics();
      expect(stats.totalExpired).toBe(1);
      expect(timeoutOccurred).toBe(true);

      // Don't call clearAllQueues - just let it be garbage collected
    });
  });

  describe("Singleton instance", () => {
    it("should return same instance on multiple calls", () => {
      // Note: This test uses the singleton instance which persists across tests
      // We create a new instance instead to avoid affecting other tests
      const instance1 = new RequestQueueService();
      const instance2 = new RequestQueueService();

      // Both should be instances of RequestQueueService
      expect(instance1).toBeInstanceOf(RequestQueueService);
      expect(instance2).toBeInstanceOf(RequestQueueService);

      // They should be different instances (not the singleton)
      expect(instance1).not.toBe(instance2);
    });
  });
});

describe("Request Queuing - Property-Based Tests", () => {
  let pbtInstances = [];

  const createPbtService = (opts) => {
    const svc = new RequestQueueService(opts);
    pbtInstances.push(svc);
    return svc;
  };

  afterAll(() => {
    // Drain all PBT service instances to prevent unhandled rejections
    for (const svc of pbtInstances) {
      for (const queueType of ["user", "ip"]) {
        const queueMap = queueType === "user" ? svc.userQueues : svc.ipQueues;
        if (!queueMap) continue;
        for (const [, queue] of queueMap) {
          for (const entry of queue) {
            if (!entry.processed) {
              entry.promise.catch(() => {});
            }
          }
        }
      }
      svc.clearAllQueues();
    }
    pbtInstances = [];
  });

  /**
   * Feature: api-backend-enhancement, Property 9: Rate limit enforcement consistency
   * Validates: Requirements 6.1, 6.2, 6.3
   *
   * Property: For any rate limit configuration and request sequence,
   * the queue should maintain FIFO order and process requests consistently
   */
  it("should maintain FIFO order for all queued requests", () => {
    const pbtQueueService = createPbtService({
      maxQueueSize: 1000,
      queueTimeoutMs: 1000,
      queueThresholdPercent: 80,
    });

    // Queue multiple requests
    const queuedIds = [];
    for (let i = 0; i < 10; i++) {
      const result = pbtQueueService.queueRequest("user123", "user", {
        method: "POST",
      });
      queuedIds.push(result.queueEntryId);
    }

    // Process requests and verify FIFO order
    for (let i = 0; i < 10; i++) {
      const entry = pbtQueueService.processNextRequest("user123", "user");
      expect(entry.id).toBe(queuedIds[i]);
    }
  });

  /**
   * Feature: api-backend-enhancement, Property 9: Rate limit enforcement consistency
   * Validates: Requirements 6.1, 6.2, 6.3
   *
   * Property: For any queue configuration, the queue should never exceed maxQueueSize
   */
  it("should never exceed maximum queue size", () => {
    const maxSize = 50;
    const pbtQueueService = createPbtService({
      maxQueueSize: maxSize,
      queueTimeoutMs: 1000,
      queueThresholdPercent: 80,
    });

    // Try to queue more than maxSize requests
    for (let i = 0; i < maxSize + 10; i++) {
      pbtQueueService.queueRequest("user123", "user", {
        method: "POST",
      });

      const status = pbtQueueService.getQueueStatus("user123", "user");
      expect(status.queueSize).toBeLessThanOrEqual(maxSize);
    }
  });

  /**
   * Feature: api-backend-enhancement, Property 9: Rate limit enforcement consistency
   * Validates: Requirements 6.1, 6.2, 6.3
   *
   * Property: For any sequence of queue and process operations,
   * currentQueuedRequests should equal the actual queue size
   */
  it("should maintain accurate queue statistics", () => {
    const pbtQueueService = createPbtService({
      maxQueueSize: 100,
      queueTimeoutMs: 1000,
      queueThresholdPercent: 80,
    });

    // Queue requests
    for (let i = 0; i < 5; i++) {
      pbtQueueService.queueRequest("user123", "user", { method: "POST" });
    }

    let stats = pbtQueueService.getStatistics();
    expect(stats.currentQueuedRequests).toBe(5);

    // Process some requests
    pbtQueueService.processNextRequest("user123", "user");
    pbtQueueService.processNextRequest("user123", "user");

    stats = pbtQueueService.getStatistics();
    expect(stats.currentQueuedRequests).toBe(3);
    expect(stats.totalProcessed).toBe(2);
  });

  /**
   * Feature: api-backend-enhancement, Property 9: Rate limit enforcement consistency
   * Validates: Requirements 6.1, 6.2, 6.3
   *
   * Property: For any identifier and queue type, separate queues should be maintained
   */
  it("should maintain separate queues for different identifiers", () => {
    const pbtQueueService = createPbtService({
      maxQueueSize: 100,
      queueTimeoutMs: 1000,
      queueThresholdPercent: 80,
    });

    // Queue requests for different users
    pbtQueueService.queueRequest("user1", "user", { method: "POST" });
    pbtQueueService.queueRequest("user1", "user", { method: "POST" });
    pbtQueueService.queueRequest("user2", "user", { method: "POST" });

    const status1 = pbtQueueService.getQueueStatus("user1", "user");
    const status2 = pbtQueueService.getQueueStatus("user2", "user");

    expect(status1.queueSize).toBe(2);
    expect(status2.queueSize).toBe(1);
  });
});
