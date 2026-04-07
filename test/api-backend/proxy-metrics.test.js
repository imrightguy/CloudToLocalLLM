import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from "@jest/globals";
import { ProxyMetricsService } from "../../services/api-backend/services/proxy-metrics-service.js";

describe("ProxyMetricsService", () => {
  let proxyMetricsService;
  let mockPool;

  beforeEach(() => {
    proxyMetricsService = new ProxyMetricsService();

    // Mock database pool
    mockPool = {
      query: jest.fn(),
      connect: jest.fn(),
    };

    proxyMetricsService.pool = mockPool;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("recordMetricsEvent", () => {
    it("should record a metrics event successfully", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const eventType = "request";
      const metrics = {
        requestCount: 100,
        successCount: 95,
        errorCount: 5,
        totalLatencyMs: 5000,
        minLatencyMs: 10,
        maxLatencyMs: 500,
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: "event-1", proxy_id: proxyId, event_type: eventType }],
      });

      const result = await proxyMetricsService.recordMetricsEvent(
        proxyId,
        userId,
        eventType,
        metrics,
      );

      expect(result).toBeDefined();
      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining("INSERT INTO proxy_metrics_events"),
        expect.arrayContaining([proxyId, userId, eventType]),
      );
    });

    it("should throw error for invalid event type", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const eventType = "invalid_type";

      await expect(
        proxyMetricsService.recordMetricsEvent(proxyId, userId, eventType, {}),
      ).rejects.toThrow("Invalid event type");
    });

    it("should accept valid event types", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const validEventTypes = ["request", "error", "connection", "latency"];

      mockPool.query.mockResolvedValue({
        rows: [{ id: "event-1" }],
      });

      for (const eventType of validEventTypes) {
        await proxyMetricsService.recordMetricsEvent(
          proxyId,
          userId,
          eventType,
          {},
        );
        expect(mockPool.query).toHaveBeenCalled();
      }

      expect(mockPool.query).toHaveBeenCalledTimes(validEventTypes.length);
    });

    it("should handle database errors gracefully", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const eventType = "request";

      mockPool.query.mockRejectedValueOnce(new Error("Database error"));

      await expect(
        proxyMetricsService.recordMetricsEvent(proxyId, userId, eventType, {}),
      ).rejects.toThrow("Database error");
    });
  });

  describe("getProxyMetricsDaily", () => {
    it("should retrieve daily metrics for a proxy", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const date = "2024-01-15";

      // Mock proxy ownership check
      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: proxyId }],
      });

      // Mock metrics retrieval
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            proxy_id: proxyId,
            date,
            request_count: 1000,
            success_count: 950,
            error_count: 50,
            average_latency_ms: 50,
            min_latency_ms: 10,
            max_latency_ms: 500,
            p95_latency_ms: 150,
            p99_latency_ms: 300,
            data_transferred_bytes: 1000000,
            data_received_bytes: 500000,
            peak_concurrent_connections: 100,
            average_concurrent_connections: 50,
            uptime_percentage: 99.5,
          },
        ],
      });

      const result = await proxyMetricsService.getProxyMetricsDaily(
        proxyId,
        userId,
        date,
      );

      expect(result).toBeDefined();
      expect(result.proxyId).toBe(proxyId);
      expect(result.date).toBe(date);
      expect(result.requestCount).toBe(1000);
      expect(result.successCount).toBe(950);
      expect(result.errorCount).toBe(50);
    });

    it("should return zero metrics if no data exists", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const date = "2024-01-15";

      // Mock proxy ownership check
      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: proxyId }],
      });

      // Mock empty metrics retrieval
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      const result = await proxyMetricsService.getProxyMetricsDaily(
        proxyId,
        userId,
        date,
      );

      expect(result).toBeDefined();
      expect(result.requestCount).toBe(0);
      expect(result.successCount).toBe(0);
      expect(result.errorCount).toBe(0);
      expect(result.uptimePercentage).toBe(100);
    });

    it("should throw error if proxy not found", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const date = "2024-01-15";

      // Mock proxy ownership check - no results
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        proxyMetricsService.getProxyMetricsDaily(proxyId, userId, date),
      ).rejects.toThrow("Proxy not found");
    });
  });

  describe("getProxyMetricsDailyRange", () => {
    it("should retrieve daily metrics for a date range", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const startDate = "2024-01-01";
      const endDate = "2024-01-31";

      // Mock proxy ownership check
      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: proxyId }],
      });

      // Mock metrics retrieval
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            proxy_id: proxyId,
            date: "2024-01-01",
            request_count: 1000,
            success_count: 950,
            error_count: 50,
            average_latency_ms: 50,
            min_latency_ms: 10,
            max_latency_ms: 500,
            p95_latency_ms: 150,
            p99_latency_ms: 300,
            data_transferred_bytes: 1000000,
            data_received_bytes: 500000,
            peak_concurrent_connections: 100,
            average_concurrent_connections: 50,
            uptime_percentage: 99.5,
          },
          {
            proxy_id: proxyId,
            date: "2024-01-02",
            request_count: 1100,
            success_count: 1050,
            error_count: 50,
            average_latency_ms: 45,
            min_latency_ms: 10,
            max_latency_ms: 450,
            p95_latency_ms: 140,
            p99_latency_ms: 280,
            data_transferred_bytes: 1100000,
            data_received_bytes: 550000,
            peak_concurrent_connections: 110,
            average_concurrent_connections: 55,
            uptime_percentage: 99.8,
          },
        ],
      });

      const result = await proxyMetricsService.getProxyMetricsDailyRange(
        proxyId,
        userId,
        startDate,
        endDate,
      );

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(2);
      expect(result[0].date).toBe("2024-01-01");
      expect(result[1].date).toBe("2024-01-02");
    });

    it("should return empty array if no data exists", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const startDate = "2024-01-01";
      const endDate = "2024-01-31";

      // Mock proxy ownership check
      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: proxyId }],
      });

      // Mock empty metrics retrieval
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      const result = await proxyMetricsService.getProxyMetricsDailyRange(
        proxyId,
        userId,
        startDate,
        endDate,
      );

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(0);
    });
  });

  describe("getProxyMetricsAggregation", () => {
    it("should retrieve aggregated metrics for a period", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const periodStart = "2024-01-01";
      const periodEnd = "2024-01-31";

      // Mock proxy ownership check
      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: proxyId }],
      });

      // Mock aggregation retrieval
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            proxy_id: proxyId,
            period_start: periodStart,
            period_end: periodEnd,
            total_request_count: 30000,
            total_success_count: 28500,
            total_error_count: 1500,
            average_latency_ms: 50,
            min_latency_ms: 10,
            max_latency_ms: 500,
            p95_latency_ms: 150,
            p99_latency_ms: 300,
            total_data_transferred_bytes: 30000000,
            total_data_received_bytes: 15000000,
            peak_concurrent_connections: 110,
            average_concurrent_connections: 55,
            average_uptime_percentage: 99.6,
          },
        ],
      });

      const result = await proxyMetricsService.getProxyMetricsAggregation(
        proxyId,
        userId,
        periodStart,
        periodEnd,
      );

      expect(result).toBeDefined();
      expect(result.proxyId).toBe(proxyId);
      expect(result.periodStart).toBe(periodStart);
      expect(result.periodEnd).toBe(periodEnd);
      expect(result.totalRequestCount).toBe(30000);
      expect(result.totalSuccessCount).toBe(28500);
      expect(result.totalErrorCount).toBe(1500);
    });

    it("should return zero aggregation if no data exists", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const periodStart = "2024-01-01";
      const periodEnd = "2024-01-31";

      // Mock proxy ownership check
      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: proxyId }],
      });

      // Mock empty aggregation retrieval
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      const result = await proxyMetricsService.getProxyMetricsAggregation(
        proxyId,
        userId,
        periodStart,
        periodEnd,
      );

      expect(result).toBeDefined();
      expect(result.totalRequestCount).toBe(0);
      expect(result.totalSuccessCount).toBe(0);
      expect(result.totalErrorCount).toBe(0);
      expect(result.averageUptimePercentage).toBe(100);
    });
  });

  describe("aggregateProxyMetrics", () => {
    it("should aggregate proxy metrics for a period", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const periodStart = "2024-01-01";
      const periodEnd = "2024-01-31";

      // Mock client
      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);

      // Mock BEGIN
      mockClient.query.mockResolvedValueOnce({});

      // Mock aggregation query
      mockClient.query.mockResolvedValueOnce({
        rows: [
          {
            total_request_count: 30000,
            total_success_count: 28500,
            total_error_count: 1500,
            average_latency_ms: 50,
            min_latency_ms: 10,
            max_latency_ms: 500,
            p95_latency_ms: 150,
            p99_latency_ms: 300,
            total_data_transferred_bytes: 30000000,
            total_data_received_bytes: 15000000,
            peak_concurrent_connections: 110,
            average_concurrent_connections: 55,
            average_uptime_percentage: 99.6,
          },
        ],
      });

      // Mock INSERT/UPDATE
      mockClient.query.mockResolvedValueOnce({
        rows: [
          {
            proxy_id: proxyId,
            period_start: periodStart,
            period_end: periodEnd,
          },
        ],
      });

      // Mock COMMIT
      mockClient.query.mockResolvedValueOnce({});

      const result = await proxyMetricsService.aggregateProxyMetrics(
        proxyId,
        userId,
        periodStart,
        periodEnd,
      );

      expect(result).toBeDefined();
      expect(mockClient.query).toHaveBeenCalledWith("BEGIN");
      expect(mockClient.query).toHaveBeenCalledWith("COMMIT");
      expect(mockClient.release).toHaveBeenCalled();
    });

    it("should rollback on error during aggregation", async () => {
      const proxyId = "proxy-123";
      const userId = "user-1";
      const periodStart = "2024-01-01";
      const periodEnd = "2024-01-31";

      // Mock client
      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);

      // Mock BEGIN
      mockClient.query.mockResolvedValueOnce({});

      // Mock error on aggregation query
      mockClient.query.mockRejectedValueOnce(new Error("Database error"));

      // Mock ROLLBACK
      mockClient.query.mockResolvedValueOnce({});

      await expect(
        proxyMetricsService.aggregateProxyMetrics(
          proxyId,
          userId,
          periodStart,
          periodEnd,
        ),
      ).rejects.toThrow("Database error");

      expect(mockClient.query).toHaveBeenCalledWith("ROLLBACK");
      expect(mockClient.release).toHaveBeenCalled();
    });
  });
});
