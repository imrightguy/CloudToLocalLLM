import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
  jest,
} from "@jest/globals";
import { ProxyFailoverService } from "../../services/api-backend/services/proxy-failover-service.js";
import { v4 as uuidv4 } from "uuid";

/**
 * Proxy Failover Service Tests
 * Tests failover configuration, instance management, and failover execution
 * Validates: Requirements 5.8
 */

describe("ProxyFailoverService", () => {
  let service;
  let mockDb;
  let userId;
  let proxyId;
  let instanceId1;
  let instanceId2;

  beforeAll(() => {
    userId = uuidv4();
    proxyId = `proxy-${uuidv4()}`;
    instanceId1 = uuidv4();
    instanceId2 = uuidv4();

    // Mock database
    mockDb = {
      query: jest.fn(),
    };

    service = new ProxyFailoverService(mockDb);
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("Failover Configuration", () => {
    it("should create failover configuration with defaults", async () => {
      const mockConfig = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        failover_strategy: "priority",
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        unhealthy_threshold: 3,
        healthy_threshold: 2,
        max_recovery_attempts: 3,
        recovery_backoff_seconds: 5,
        enable_auto_failover: true,
        enable_auto_recovery: true,
        enable_load_balancing: false,
        load_balancing_algorithm: "round_robin",
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockConfig] });

      const result = await service.createFailoverConfiguration(proxyId, userId);

      expect(result).toBeDefined();
      expect(result.proxyId).toBe(proxyId);
      expect(result.failoverStrategy).toBe("priority");
      expect(result.enableAutoFailover).toBe(true);
    });

    it("should merge custom config with defaults", async () => {
      const customConfig = {
        failoverStrategy: "round_robin",
        enableAutoFailover: false,
      };

      const mockConfig = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        failover_strategy: "round_robin",
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        unhealthy_threshold: 3,
        healthy_threshold: 2,
        max_recovery_attempts: 3,
        recovery_backoff_seconds: 5,
        enable_auto_failover: false,
        enable_auto_recovery: true,
        enable_load_balancing: false,
        load_balancing_algorithm: "round_robin",
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockConfig] });

      const result = await service.createFailoverConfiguration(
        proxyId,
        userId,
        customConfig,
      );

      expect(result.failoverStrategy).toBe("round_robin");
      expect(result.enableAutoFailover).toBe(false);
    });

    it("should validate failover strategy", async () => {
      const invalidConfig = {
        failoverStrategy: "invalid_strategy",
      };

      await expect(
        service.createFailoverConfiguration(proxyId, userId, invalidConfig),
      ).rejects.toThrow("failoverStrategy must be one of");
    });

    it("should get failover configuration", async () => {
      const mockConfig = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        failover_strategy: "priority",
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        unhealthy_threshold: 3,
        healthy_threshold: 2,
        max_recovery_attempts: 3,
        recovery_backoff_seconds: 5,
        enable_auto_failover: true,
        enable_auto_recovery: true,
        enable_load_balancing: false,
        load_balancing_algorithm: "round_robin",
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockConfig] });

      const result = await service.getFailoverConfiguration(proxyId);

      expect(result).toBeDefined();
      expect(result.proxyId).toBe(proxyId);
    });

    it("should return null if configuration not found", async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      const result = await service.getFailoverConfiguration(proxyId);

      expect(result).toBeNull();
    });
  });

  describe("Proxy Instance Management", () => {
    it("should register proxy instance", async () => {
      const instanceData = {
        instanceName: "proxy-instance-1",
        instanceType: "standard",
        priority: 100,
        weight: 100,
      };

      const mockInstance = {
        id: instanceId1,
        proxy_id: proxyId,
        user_id: userId,
        instance_name: "proxy-instance-1",
        instance_type: "standard",
        status: "unknown",
        priority: 100,
        weight: 100,
        health_status: "unknown",
        last_health_check: null,
        consecutive_failures: 0,
        total_requests: 0,
        successful_requests: 0,
        failed_requests: 0,
        average_latency_ms: 0,
        error_rate: 0,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockInstance] });

      const result = await service.registerProxyInstance(
        proxyId,
        userId,
        instanceData,
      );

      expect(result).toBeDefined();
      expect(result.instanceName).toBe("proxy-instance-1");
      expect(result.priority).toBe(100);
    });

    it("should get all proxy instances", async () => {
      const mockInstances = [
        {
          id: instanceId1,
          proxy_id: proxyId,
          user_id: userId,
          instance_name: "proxy-instance-1",
          instance_type: "standard",
          status: "running",
          priority: 100,
          weight: 100,
          health_status: "healthy",
          last_health_check: new Date(),
          consecutive_failures: 0,
          total_requests: 1000,
          successful_requests: 950,
          failed_requests: 50,
          average_latency_ms: 50,
          error_rate: 0.05,
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        },
        {
          id: instanceId2,
          proxy_id: proxyId,
          user_id: userId,
          instance_name: "proxy-instance-2",
          instance_type: "standard",
          status: "running",
          priority: 200,
          weight: 100,
          health_status: "healthy",
          last_health_check: new Date(),
          consecutive_failures: 0,
          total_requests: 800,
          successful_requests: 780,
          failed_requests: 20,
          average_latency_ms: 55,
          error_rate: 0.025,
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        },
      ];

      mockDb.query.mockResolvedValueOnce({ rows: mockInstances });

      const result = await service.getProxyInstances(proxyId);

      expect(result).toHaveLength(2);
      expect(result[0].instanceName).toBe("proxy-instance-1");
      expect(result[1].instanceName).toBe("proxy-instance-2");
    });

    it("should update instance health status", async () => {
      const mockInstance = {
        id: instanceId1,
        proxy_id: proxyId,
        user_id: userId,
        instance_name: "proxy-instance-1",
        instance_type: "standard",
        status: "running",
        priority: 100,
        weight: 100,
        health_status: "unhealthy",
        last_health_check: new Date(),
        consecutive_failures: 1,
        total_requests: 1000,
        successful_requests: 950,
        failed_requests: 50,
        average_latency_ms: 50,
        error_rate: 0.05,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      // First query to get current instance
      mockDb.query.mockResolvedValueOnce({ rows: [mockInstance] });
      // Second query to update instance
      mockDb.query.mockResolvedValueOnce({ rows: [mockInstance] });
      // Third query to record metrics
      mockDb.query.mockResolvedValueOnce({ rows: [{ id: uuidv4() }] });

      const result = await service.updateInstanceHealth(
        instanceId1,
        "unhealthy",
        {
          cpuPercent: 85,
          memoryPercent: 90,
        },
      );

      expect(result).toBeDefined();
      expect(result.healthStatus).toBe("unhealthy");
    });

    it("should increment consecutive failures on unhealthy status", async () => {
      const currentInstance = {
        id: instanceId1,
        proxy_id: proxyId,
        user_id: userId,
        instance_name: "proxy-instance-1",
        instance_type: "standard",
        status: "running",
        priority: 100,
        weight: 100,
        health_status: "healthy",
        last_health_check: new Date(),
        consecutive_failures: 0,
        total_requests: 1000,
        successful_requests: 950,
        failed_requests: 50,
        average_latency_ms: 50,
        error_rate: 0.05,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      const updatedInstance = {
        ...currentInstance,
        health_status: "unhealthy",
        consecutive_failures: 1,
      };

      mockDb.query.mockResolvedValueOnce({ rows: [currentInstance] });
      mockDb.query.mockResolvedValueOnce({ rows: [updatedInstance] });

      const result = await service.updateInstanceHealth(
        instanceId1,
        "unhealthy",
      );

      expect(result.consecutiveFailures).toBe(1);
    });

    it("should reset consecutive failures on healthy status", async () => {
      const currentInstance = {
        id: instanceId1,
        proxy_id: proxyId,
        user_id: userId,
        instance_name: "proxy-instance-1",
        instance_type: "standard",
        status: "running",
        priority: 100,
        weight: 100,
        health_status: "unhealthy",
        last_health_check: new Date(),
        consecutive_failures: 3,
        total_requests: 1000,
        successful_requests: 950,
        failed_requests: 50,
        average_latency_ms: 50,
        error_rate: 0.05,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      const updatedInstance = {
        ...currentInstance,
        health_status: "healthy",
        consecutive_failures: 0,
      };

      mockDb.query.mockResolvedValueOnce({ rows: [currentInstance] });
      mockDb.query.mockResolvedValueOnce({ rows: [updatedInstance] });

      const result = await service.updateInstanceHealth(instanceId1, "healthy");

      expect(result.consecutiveFailures).toBe(0);
    });
  });

  describe("Failover Evaluation", () => {
    it("should evaluate failover when active instance is unhealthy", async () => {
      const mockConfig = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        failover_strategy: "priority",
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        unhealthy_threshold: 3,
        healthy_threshold: 2,
        max_recovery_attempts: 3,
        recovery_backoff_seconds: 5,
        enable_auto_failover: true,
        enable_auto_recovery: true,
        enable_load_balancing: false,
        load_balancing_algorithm: "round_robin",
        created_at: new Date(),
        updated_at: new Date(),
      };

      const mockInstances = [
        {
          id: instanceId1,
          proxy_id: proxyId,
          user_id: userId,
          instance_name: "proxy-instance-1",
          instance_type: "standard",
          status: "running",
          priority: 100,
          weight: 100,
          health_status: "unhealthy",
          last_health_check: new Date(),
          consecutive_failures: 3,
          total_requests: 1000,
          successful_requests: 950,
          failed_requests: 50,
          average_latency_ms: 50,
          error_rate: 0.05,
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        },
        {
          id: instanceId2,
          proxy_id: proxyId,
          user_id: userId,
          instance_name: "proxy-instance-2",
          instance_type: "standard",
          status: "running",
          priority: 200,
          weight: 100,
          health_status: "healthy",
          last_health_check: new Date(),
          consecutive_failures: 0,
          total_requests: 800,
          successful_requests: 780,
          failed_requests: 20,
          average_latency_ms: 55,
          error_rate: 0.025,
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        },
      ];

      mockDb.query.mockResolvedValueOnce({ rows: [mockConfig] });
      mockDb.query.mockResolvedValueOnce({ rows: mockInstances });

      service.activeInstances.set(proxyId, instanceId1);

      const result = await service.evaluateFailover(proxyId, userId);

      expect(result.shouldFailover).toBe(true);
      expect(result.sourceInstanceId).toBe(instanceId1);
      expect(result.targetInstanceId).toBe(instanceId2);
    });

    it("should not failover if auto failover is disabled", async () => {
      const mockConfig = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        failover_strategy: "priority",
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        unhealthy_threshold: 3,
        healthy_threshold: 2,
        max_recovery_attempts: 3,
        recovery_backoff_seconds: 5,
        enable_auto_failover: false,
        enable_auto_recovery: true,
        enable_load_balancing: false,
        load_balancing_algorithm: "round_robin",
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockConfig] });

      const result = await service.evaluateFailover(proxyId, userId);

      expect(result.shouldFailover).toBe(false);
      expect(result.reason).toBe("Auto failover is disabled");
    });

    it("should not failover if no backup instance is available", async () => {
      const mockConfig = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        failover_strategy: "priority",
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        unhealthy_threshold: 3,
        healthy_threshold: 2,
        max_recovery_attempts: 3,
        recovery_backoff_seconds: 5,
        enable_auto_failover: true,
        enable_auto_recovery: true,
        enable_load_balancing: false,
        load_balancing_algorithm: "round_robin",
        created_at: new Date(),
        updated_at: new Date(),
      };

      const mockInstances = [
        {
          id: instanceId1,
          proxy_id: proxyId,
          user_id: userId,
          instance_name: "proxy-instance-1",
          instance_type: "standard",
          status: "running",
          priority: 100,
          weight: 100,
          health_status: "unhealthy",
          last_health_check: new Date(),
          consecutive_failures: 3,
          total_requests: 1000,
          successful_requests: 950,
          failed_requests: 50,
          average_latency_ms: 50,
          error_rate: 0.05,
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        },
      ];

      mockDb.query.mockResolvedValueOnce({ rows: [mockConfig] });
      mockDb.query.mockResolvedValueOnce({ rows: mockInstances });

      service.activeInstances.set(proxyId, instanceId1);

      const result = await service.evaluateFailover(proxyId, userId);

      expect(result.shouldFailover).toBe(false);
    });
  });

  describe("Failover Execution", () => {
    it("should execute failover and create event", async () => {
      const mockEvent = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        event_type: "failover",
        source_instance_id: instanceId1,
        target_instance_id: instanceId2,
        reason: "Instance unhealthy",
        status: "in_progress",
        error_message: null,
        duration_ms: null,
        created_at: new Date(),
        completed_at: null,
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockEvent] });

      const result = await service.executeFailover(
        proxyId,
        userId,
        instanceId1,
        instanceId2,
        "Instance unhealthy",
      );

      expect(result).toBeDefined();
      expect(result.eventType).toBe("failover");
      expect(result.status).toBe("in_progress");
      expect(service.activeInstances.get(proxyId)).toBe(instanceId2);
    });

    it("should complete failover event", async () => {
      const eventId = uuidv4();
      const mockEvent = {
        id: eventId,
        proxy_id: proxyId,
        user_id: userId,
        event_type: "failover",
        source_instance_id: instanceId1,
        target_instance_id: instanceId2,
        reason: "Instance unhealthy",
        status: "completed",
        error_message: null,
        duration_ms: 1500,
        created_at: new Date(),
        completed_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockEvent] });

      const result = await service.completeFailoverEvent(
        eventId,
        "completed",
        null,
        1500,
      );

      expect(result).toBeDefined();
      expect(result.status).toBe("completed");
      expect(result.durationMs).toBe(1500);
    });

    it("should get failover events", async () => {
      const mockEvents = [
        {
          id: uuidv4(),
          proxy_id: proxyId,
          user_id: userId,
          event_type: "failover",
          source_instance_id: instanceId1,
          target_instance_id: instanceId2,
          reason: "Instance unhealthy",
          status: "completed",
          error_message: null,
          duration_ms: 1500,
          created_at: new Date(),
          completed_at: new Date(),
        },
      ];

      mockDb.query.mockResolvedValueOnce({ rows: mockEvents });

      const result = await service.getFailoverEvents(proxyId);

      expect(result).toHaveLength(1);
      expect(result[0].eventType).toBe("failover");
    });
  });

  describe("Redundancy Status", () => {
    it("should update redundancy status", async () => {
      const mockStatus = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        total_instances: 2,
        healthy_instances: 2,
        unhealthy_instances: 0,
        active_instance_id: instanceId1,
        backup_instance_ids: [instanceId2],
        last_failover_at: null,
        last_failover_reason: null,
        redundancy_level: "dual",
        is_degraded: false,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockStatus] });

      const result = await service.updateRedundancyStatus(proxyId, userId, {
        totalInstances: 2,
        healthyInstances: 2,
        unhealthyInstances: 0,
        activeInstanceId: instanceId1,
        backupInstanceIds: [instanceId2],
        redundancyLevel: "dual",
        isDegraded: false,
      });

      expect(result).toBeDefined();
      expect(result.redundancyLevel).toBe("dual");
      expect(result.isDegraded).toBe(false);
    });

    it("should get redundancy status", async () => {
      const mockStatus = {
        id: uuidv4(),
        proxy_id: proxyId,
        user_id: userId,
        total_instances: 2,
        healthy_instances: 1,
        unhealthy_instances: 1,
        active_instance_id: instanceId1,
        backup_instance_ids: [instanceId2],
        last_failover_at: new Date(),
        last_failover_reason: "Instance failure",
        redundancy_level: "dual",
        is_degraded: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockStatus] });

      const result = await service.getRedundancyStatus(proxyId);

      expect(result).toBeDefined();
      expect(result.isDegraded).toBe(true);
      expect(result.healthyInstances).toBe(1);
    });
  });

  describe("Error Handling", () => {
    it("should throw error if proxyId is missing", async () => {
      await expect(
        service.createFailoverConfiguration(null, userId),
      ).rejects.toThrow("proxyId and userId are required");
    });

    it("should throw error if userId is missing", async () => {
      await expect(
        service.createFailoverConfiguration(proxyId, null),
      ).rejects.toThrow("proxyId and userId are required");
    });

    it("should throw error if instanceData is missing", async () => {
      await expect(
        service.registerProxyInstance(proxyId, userId, null),
      ).rejects.toThrow("instanceData with instanceName is required");
    });

    it("should throw error if invalid health status", async () => {
      await expect(
        service.updateInstanceHealth(instanceId1, "invalid"),
      ).rejects.toThrow("healthStatus must be healthy, unhealthy, or unknown");
    });
  });
});
