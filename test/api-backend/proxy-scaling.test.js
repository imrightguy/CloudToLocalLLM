import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
  jest,
} from "@jest/globals";
import { ProxyScalingService } from "../../services/api-backend/services/proxy-scaling-service.js";
import { v4 as uuidv4 } from "uuid";

/**
 * Property-Based Tests for Proxy Scaling
 * Feature: api-backend-enhancement, Property 8: Proxy state consistency
 * Validates: Requirements 5.5
 */

describe("ProxyScalingService", () => {
  let scalingService;
  let mockDb;
  const proxyId = uuidv4();
  const userId = uuidv4();

  beforeAll(() => {
    // Mock database
    mockDb = {
      query: jest.fn(),
    };

    scalingService = new ProxyScalingService(mockDb);
  });

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  describe("Scaling Policy Management", () => {
    it("should create a scaling policy with valid configuration", async () => {
      const policy = {
        minReplicas: 1,
        maxReplicas: 10,
        targetCpuPercent: 70,
        targetMemoryPercent: 80,
        targetRequestRate: 1000,
        scaleUpThreshold: 80,
        scaleDownThreshold: 30,
        scaleUpCooldownSeconds: 60,
        scaleDownCooldownSeconds: 300,
      };

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            min_replicas: policy.minReplicas,
            max_replicas: policy.maxReplicas,
            target_cpu_percent: policy.targetCpuPercent,
            target_memory_percent: policy.targetMemoryPercent,
            target_request_rate: policy.targetRequestRate,
            scale_up_threshold: policy.scaleUpThreshold,
            scale_down_threshold: policy.scaleDownThreshold,
            scale_up_cooldown_seconds: policy.scaleUpCooldownSeconds,
            scale_down_cooldown_seconds: policy.scaleDownCooldownSeconds,
            enabled: true,
            created_at: new Date(),
            updated_at: new Date(),
          },
        ],
      });

      const result = await scalingService.createScalingPolicy(
        proxyId,
        userId,
        policy,
      );

      expect(result).toBeDefined();
      expect(result.minReplicas).toBe(policy.minReplicas);
      expect(result.maxReplicas).toBe(policy.maxReplicas);
      expect(result.enabled).toBe(true);
    });

    it("should reject policy with invalid minReplicas", async () => {
      const policy = {
        minReplicas: 0, // Invalid
        maxReplicas: 10,
        targetCpuPercent: 70,
        targetMemoryPercent: 80,
        targetRequestRate: 1000,
        scaleUpThreshold: 80,
        scaleDownThreshold: 30,
        scaleUpCooldownSeconds: 60,
        scaleDownCooldownSeconds: 300,
      };

      await expect(
        scalingService.createScalingPolicy(proxyId, userId, policy),
      ).rejects.toThrow("minReplicas must be a positive integer");
    });

    it("should reject policy with maxReplicas less than minReplicas", async () => {
      const policy = {
        minReplicas: 10,
        maxReplicas: 5, // Invalid
        targetCpuPercent: 70,
        targetMemoryPercent: 80,
        targetRequestRate: 1000,
        scaleUpThreshold: 80,
        scaleDownThreshold: 30,
        scaleUpCooldownSeconds: 60,
        scaleDownCooldownSeconds: 300,
      };

      await expect(
        scalingService.createScalingPolicy(proxyId, userId, policy),
      ).rejects.toThrow("maxReplicas must be >= minReplicas");
    });

    it("should reject policy with invalid CPU percent", async () => {
      const policy = {
        minReplicas: 1,
        maxReplicas: 10,
        targetCpuPercent: 150, // Invalid
        targetMemoryPercent: 80,
        targetRequestRate: 1000,
        scaleUpThreshold: 80,
        scaleDownThreshold: 30,
        scaleUpCooldownSeconds: 60,
        scaleDownCooldownSeconds: 300,
      };

      await expect(
        scalingService.createScalingPolicy(proxyId, userId, policy),
      ).rejects.toThrow("targetCpuPercent must be between 0 and 100");
    });

    it("should reject policy with scaleDownThreshold >= scaleUpThreshold", async () => {
      const policy = {
        minReplicas: 1,
        maxReplicas: 10,
        targetCpuPercent: 70,
        targetMemoryPercent: 80,
        targetRequestRate: 1000,
        scaleUpThreshold: 50,
        scaleDownThreshold: 80, // Invalid
        scaleUpCooldownSeconds: 60,
        scaleDownCooldownSeconds: 300,
      };

      await expect(
        scalingService.createScalingPolicy(proxyId, userId, policy),
      ).rejects.toThrow(
        "scaleDownThreshold must be less than scaleUpThreshold",
      );
    });
  });

  describe("Load Metrics Recording", () => {
    it("should record load metrics with valid data", async () => {
      const metrics = {
        currentReplicas: 3,
        cpuPercent: 65,
        memoryPercent: 75,
        requestRate: 800,
        averageLatencyMs: 45,
        errorRate: 0.01,
        connectionCount: 150,
      };

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: metrics.currentReplicas,
            cpu_percent: metrics.cpuPercent,
            memory_percent: metrics.memoryPercent,
            request_rate: metrics.requestRate,
            average_latency_ms: metrics.averageLatencyMs,
            error_rate: metrics.errorRate,
            connection_count: metrics.connectionCount,
            load_score: 60.5,
            created_at: new Date(),
          },
        ],
      });

      const result = await scalingService.recordLoadMetrics(
        proxyId,
        userId,
        metrics,
      );

      expect(result).toBeDefined();
      expect(result.currentReplicas).toBe(metrics.currentReplicas);
      expect(result.loadScore).toBeDefined();
    });

    it("should reject metrics with missing required fields", async () => {
      const metrics = {
        currentReplicas: 3,
        cpuPercent: 65,
        // Missing other required fields
      };

      await expect(
        scalingService.recordLoadMetrics(proxyId, userId, metrics),
      ).rejects.toThrow("Missing required metric");
    });

    it("should calculate load score correctly", () => {
      const metrics = {
        cpuPercent: 40,
        memoryPercent: 30,
        requestRate: 500,
        errorRate: 0.01,
      };

      const loadScore = scalingService.calculateLoadScore(metrics);

      // Expected: 40*0.4 + 30*0.3 + (500/1000)*100*0.2 + 0.01*100*0.1
      // = 16 + 9 + 10 + 0.1 = 35.1
      expect(loadScore).toBeCloseTo(35.1, 1);
    });

    it("should cap load score at 100", () => {
      const metrics = {
        cpuPercent: 100,
        memoryPercent: 100,
        requestRate: 5000,
        errorRate: 1.0,
      };

      const loadScore = scalingService.calculateLoadScore(metrics);

      expect(loadScore).toBeLessThanOrEqual(100);
    });
  });

  describe("Scaling Evaluation", () => {
    it("should return no scaling needed when load is within thresholds", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            min_replicas: 1,
            max_replicas: 10,
            target_cpu_percent: 70,
            target_memory_percent: 80,
            target_request_rate: 1000,
            scale_up_threshold: 80,
            scale_down_threshold: 30,
            scale_up_cooldown_seconds: 60,
            scale_down_cooldown_seconds: 300,
            enabled: true,
            created_at: new Date(),
            updated_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 3,
            cpu_percent: 50,
            memory_percent: 60,
            request_rate: 500,
            average_latency_ms: 40,
            error_rate: 0.005,
            connection_count: 100,
            load_score: 45,
            created_at: new Date(),
          },
        ],
      });

      const decision = await scalingService.evaluateScaling(proxyId, userId);

      expect(decision.shouldScale).toBe(false);
    });

    it("should recommend scale up when load exceeds threshold", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            min_replicas: 1,
            max_replicas: 10,
            target_cpu_percent: 70,
            target_memory_percent: 80,
            target_request_rate: 1000,
            scale_up_threshold: 80,
            scale_down_threshold: 30,
            scale_up_cooldown_seconds: 60,
            scale_down_cooldown_seconds: 300,
            enabled: true,
            created_at: new Date(),
            updated_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 3,
            cpu_percent: 90,
            memory_percent: 85,
            request_rate: 1500,
            average_latency_ms: 100,
            error_rate: 0.05,
            connection_count: 500,
            load_score: 90,
            created_at: new Date(),
          },
        ],
      });

      const decision = await scalingService.evaluateScaling(proxyId, userId);

      expect(decision.shouldScale).toBe(true);
      expect(decision.scalingAction).toBe("scale_up");
    });

    it("should recommend scale down when load is below threshold", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            min_replicas: 1,
            max_replicas: 10,
            target_cpu_percent: 70,
            target_memory_percent: 80,
            target_request_rate: 1000,
            scale_up_threshold: 80,
            scale_down_threshold: 30,
            scale_up_cooldown_seconds: 60,
            scale_down_cooldown_seconds: 300,
            enabled: true,
            created_at: new Date(),
            updated_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 5,
            cpu_percent: 10,
            memory_percent: 15,
            request_rate: 100,
            average_latency_ms: 20,
            error_rate: 0.001,
            connection_count: 20,
            load_score: 15,
            created_at: new Date(),
          },
        ],
      });

      const decision = await scalingService.evaluateScaling(proxyId, userId);

      expect(decision.shouldScale).toBe(true);
      expect(decision.scalingAction).toBe("scale_down");
    });

    it("should respect minimum replicas when scaling down", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            min_replicas: 1,
            max_replicas: 10,
            target_cpu_percent: 70,
            target_memory_percent: 80,
            target_request_rate: 1000,
            scale_up_threshold: 80,
            scale_down_threshold: 30,
            scale_up_cooldown_seconds: 60,
            scale_down_cooldown_seconds: 300,
            enabled: true,
            created_at: new Date(),
            updated_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 1, // Already at minimum
            cpu_percent: 10,
            memory_percent: 15,
            request_rate: 100,
            average_latency_ms: 20,
            error_rate: 0.001,
            connection_count: 20,
            load_score: 15,
            created_at: new Date(),
          },
        ],
      });

      const decision = await scalingService.evaluateScaling(proxyId, userId);

      expect(decision.shouldScale).toBe(false);
    });

    it("should respect maximum replicas when scaling up", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            min_replicas: 1,
            max_replicas: 10,
            target_cpu_percent: 70,
            target_memory_percent: 80,
            target_request_rate: 1000,
            scale_up_threshold: 80,
            scale_down_threshold: 30,
            scale_up_cooldown_seconds: 60,
            scale_down_cooldown_seconds: 300,
            enabled: true,
            created_at: new Date(),
            updated_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 10, // Already at maximum
            cpu_percent: 90,
            memory_percent: 85,
            request_rate: 1500,
            average_latency_ms: 100,
            error_rate: 0.05,
            connection_count: 500,
            load_score: 90,
            created_at: new Date(),
          },
        ],
      });

      const decision = await scalingService.evaluateScaling(proxyId, userId);

      expect(decision.shouldScale).toBe(false);
    });
  });

  describe("Scaling Execution", () => {
    it("should execute scaling with valid parameters", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 3,
            cpu_percent: 90,
            memory_percent: 85,
            request_rate: 1500,
            average_latency_ms: 100,
            error_rate: 0.05,
            connection_count: 500,
            load_score: 90,
            created_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            event_type: "scale_up",
            previous_replicas: 3,
            new_replicas: 5,
            reason: "High load detected",
            triggered_by: "auto",
            load_metrics: JSON.stringify({
              cpuPercent: 90,
              memoryPercent: 85,
              requestRate: 1500,
              loadScore: 90,
            }),
            status: "in_progress",
            error_message: null,
            duration_ms: null,
            created_at: new Date(),
            completed_at: null,
          },
        ],
      });

      const result = await scalingService.executeScaling(
        proxyId,
        userId,
        5,
        "High load detected",
        "auto",
      );

      expect(result).toBeDefined();
      expect(result.eventType).toBe("scale_up");
      expect(result.previousReplicas).toBe(3);
      expect(result.newReplicas).toBe(5);
      expect(result.status).toBe("in_progress");
    });

    it("should reject scaling with invalid replica count", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 3,
            cpu_percent: 90,
            memory_percent: 85,
            request_rate: 1500,
            average_latency_ms: 100,
            error_rate: 0.05,
            connection_count: 500,
            load_score: 90,
            created_at: new Date(),
          },
        ],
      });

      await expect(
        scalingService.executeScaling(proxyId, userId, 0, "Test", "manual"),
      ).rejects.toThrow("newReplicaCount must be a positive integer");
    });
  });

  describe("Scaling Event Completion", () => {
    it("should reject invalid status for scaling event", async () => {
      const eventId = uuidv4();

      await expect(
        scalingService.completeScalingEvent(
          eventId,
          "invalid_status",
          null,
          5000,
        ),
      ).rejects.toThrow("status must be completed or failed");
    });

    it("should reject missing eventId", async () => {
      await expect(
        scalingService.completeScalingEvent(null, "completed", null, 5000),
      ).rejects.toThrow("eventId is required");
    });
  });

  describe("Scaling History and Summary", () => {
    it("should retrieve scaling events for a proxy", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            event_type: "scale_up",
            previous_replicas: 3,
            new_replicas: 5,
            reason: "High load",
            triggered_by: "auto",
            load_metrics: JSON.stringify({}),
            status: "completed",
            error_message: null,
            duration_ms: 5000,
            created_at: new Date(),
            completed_at: new Date(),
          },
        ],
      });

      const events = await scalingService.getScalingEvents(proxyId, 50);

      expect(Array.isArray(events)).toBe(true);
      expect(events.length).toBeGreaterThan(0);
    });

    it("should retrieve scaling summary", async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            event_type: "scale_up",
            previous_replicas: 3,
            new_replicas: 5,
            reason: "High load",
            triggered_by: "auto",
            load_metrics: JSON.stringify({}),
            status: "completed",
            error_message: null,
            duration_ms: 5000,
            created_at: new Date(),
            completed_at: new Date(),
          },
        ],
      });

      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            proxy_id: proxyId,
            user_id: userId,
            current_replicas: 5,
            cpu_percent: 75,
            memory_percent: 80,
            request_rate: 1000,
            average_latency_ms: 50,
            error_rate: 0.01,
            connection_count: 200,
            load_score: 70,
            created_at: new Date(),
          },
        ],
      });

      const summary = await scalingService.getScalingSummary(proxyId, 24);

      expect(summary).toBeDefined();
      expect(summary.proxyId).toBe(proxyId);
      expect(summary.scalingEvents).toBeDefined();
      expect(summary.loadMetrics).toBeDefined();
    });
  });

  describe("Error Handling", () => {
    it("should throw error when proxyId is missing", async () => {
      await expect(
        scalingService.createScalingPolicy(null, userId, {}),
      ).rejects.toThrow("proxyId and userId are required");
    });

    it("should throw error when userId is missing", async () => {
      await expect(
        scalingService.createScalingPolicy(proxyId, null, {}),
      ).rejects.toThrow("proxyId and userId are required");
    });

    it("should throw error when metrics is not an object", async () => {
      await expect(
        scalingService.recordLoadMetrics(proxyId, userId, "invalid"),
      ).rejects.toThrow("metrics must be an object");
    });
  });
});
