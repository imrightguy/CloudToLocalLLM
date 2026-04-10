/**


 * Tunnel Metrics Aggregation Property-Based Tests
 *
 * Property-based tests for tunnel metrics aggregation consistency
 *
 * **Feature: api-backend-enhancement, Property 7: Metrics aggregation consistency**
 * **Validates: Requirements 4.6**
 *
 * Property 7: Metrics aggregation consistency
 * *For any* sequence of tunnel requests with varying latencies and success/failure outcomes,
 * the aggregated metrics should maintain mathematical consistency:
 * - requestCount = successCount + errorCount
 * - averageLatency = totalLatency / requestCount
 * - successRate = (successCount / requestCount) * 100
 * - minLatency <= averageLatency <= maxLatency
 *
 * @fileoverview Property-based tests for tunnel metrics aggregation
 * @version 1.0.0
 */

import { describe, it, expect, beforeEach } from "@jest/globals";
import { TunnelHealthService } from "../../services/api-backend/services/tunnel-health-service.js";

describe("Tunnel Metrics Aggregation Property-Based Tests", () => {
  let tunnelHealthService;

  beforeEach(() => {
    // Initialize service for each test
    tunnelHealthService = new TunnelHealthService();
    // No need to initialize pool for in-memory metrics tests
  });

  /**
   * Property 7: Metrics aggregation consistency
   *
   * For any sequence of tunnel requests with varying latencies and success/failure outcomes,
   * the aggregated metrics should maintain mathematical consistency.
   *
   * Invariants:
   * 1. requestCount = successCount + errorCount
   * 2. averageLatency = totalLatency / requestCount
   * 3. successRate = (successCount / requestCount) * 100
   * 4. minLatency <= averageLatency <= maxLatency
   * 5. successRate is between 0 and 100
   *
   * Validates: Requirements 4.6
   */
  it("should maintain mathematical consistency in aggregated metrics", () => {
    // Test with multiple random request sequences
    for (let testRun = 0; testRun < 50; testRun++) {
      const tunnelId = `tunnel-metrics-${Date.now()}-${Math.random()}`;

      // Generate random request sequence
      const requestCount = Math.floor(Math.random() * 100) + 1; // 1-100 requests
      let totalLatency = 0;
      let successCount = 0;
      let errorCount = 0;
      let minLatency = Infinity;
      let maxLatency = 0;

      for (let i = 0; i < requestCount; i++) {
        const latency = Math.floor(Math.random() * 1000) + 1; // 1-1000ms
        const success = Math.random() > 0.3; // 70% success rate

        tunnelHealthService.recordRequestMetrics(tunnelId, {
          latency,
          success,
          statusCode: success ? 200 : 500,
        });

        totalLatency += latency;
        if (success) {
          successCount++;
        } else {
          errorCount++;
        }
        minLatency = Math.min(minLatency, latency);
        maxLatency = Math.max(maxLatency, latency);
      }

      // Get aggregated metrics
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Invariant 1: requestCount = successCount + errorCount
      expect(metrics.requestCount).toBe(successCount + errorCount);
      expect(metrics.requestCount).toBe(requestCount);

      // Invariant 2: averageLatency = totalLatency / requestCount
      const expectedAverageLatency = totalLatency / requestCount;
      expect(metrics.averageLatency).toBeCloseTo(expectedAverageLatency, 0);

      // Invariant 3: successRate = (successCount / requestCount) * 100
      const expectedSuccessRate = (successCount / requestCount) * 100;
      expect(metrics.successRate).toBeCloseTo(expectedSuccessRate, 1);

      // Invariant 4: minLatency <= averageLatency <= maxLatency
      expect(metrics.minLatency).toBeLessThanOrEqual(metrics.averageLatency);
      expect(metrics.averageLatency).toBeLessThanOrEqual(metrics.maxLatency);

      // Invariant 5: successRate is between 0 and 100
      expect(metrics.successRate).toBeGreaterThanOrEqual(0);
      expect(metrics.successRate).toBeLessThanOrEqual(100);

      // Additional checks
      expect(metrics.successCount).toBe(successCount);
      expect(metrics.errorCount).toBe(errorCount);
      expect(metrics.minLatency).toBe(minLatency);
      expect(metrics.maxLatency).toBe(maxLatency);
    }
  });

  /**
   * Property: Metrics should be retrievable after recording
   *
   * For any tunnel with recorded metrics, retrieving metrics should return
   * the exact values that were recorded.
   *
   * Validates: Requirements 4.6
   */
  it("should preserve metrics consistency through retrieval", () => {
    // Test with multiple random scenarios
    for (let testRun = 0; testRun < 20; testRun++) {
      const tunnelId = `tunnel-retrieve-${Date.now()}-${Math.random()}`;

      // Record random metrics
      const requestCount = Math.floor(Math.random() * 50) + 1;
      let expectedTotalLatency = 0;
      let expectedSuccessCount = 0;
      let expectedErrorCount = 0;
      let expectedMinLatency = Infinity;
      let expectedMaxLatency = 0;

      for (let i = 0; i < requestCount; i++) {
        const latency = Math.floor(Math.random() * 1000) + 1;
        const success = Math.random() > 0.3;

        tunnelHealthService.recordRequestMetrics(tunnelId, {
          latency,
          success,
          statusCode: success ? 200 : 500,
        });

        expectedTotalLatency += latency;
        if (success) {
          expectedSuccessCount++;
        } else {
          expectedErrorCount++;
        }
        expectedMinLatency = Math.min(expectedMinLatency, latency);
        expectedMaxLatency = Math.max(expectedMaxLatency, latency);
      }

      // Get metrics
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Verify metrics are preserved
      expect(metrics.requestCount).toBe(requestCount);
      expect(metrics.successCount).toBe(expectedSuccessCount);
      expect(metrics.errorCount).toBe(expectedErrorCount);
      expect(metrics.successRate).toBeCloseTo(
        (expectedSuccessCount / requestCount) * 100,
        1,
      );
      expect(metrics.averageLatency).toBeCloseTo(
        expectedTotalLatency / requestCount,
        0,
      );
      expect(metrics.minLatency).toBe(expectedMinLatency);
      expect(metrics.maxLatency).toBe(expectedMaxLatency);
    }
  });

  /**
   * Property: All-success requests should have 100% success rate
   *
   * For any tunnel where all requests are successful, the success rate
   * should be exactly 100%.
   *
   * Validates: Requirements 4.6
   */
  it("should calculate 100% success rate for all successful requests", () => {
    // Test with multiple scenarios
    for (let testRun = 0; testRun < 20; testRun++) {
      const tunnelId = `tunnel-success-${Date.now()}-${Math.random()}`;

      // Record only successful requests
      const requestCount = Math.floor(Math.random() * 50) + 1;
      for (let i = 0; i < requestCount; i++) {
        const latency = Math.floor(Math.random() * 1000) + 1;

        tunnelHealthService.recordRequestMetrics(tunnelId, {
          latency,
          success: true,
          statusCode: 200,
        });
      }

      // Get metrics
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Verify 100% success rate
      expect(metrics.successRate).toBe(100);
      expect(metrics.successCount).toBe(requestCount);
      expect(metrics.errorCount).toBe(0);
      expect(metrics.requestCount).toBe(requestCount);
    }
  });

  /**
   * Property: All-failure requests should have 0% success rate
   *
   * For any tunnel where all requests fail, the success rate should be 0%.
   *
   * Validates: Requirements 4.6
   */
  it("should calculate 0% success rate for all failed requests", () => {
    // Test with multiple scenarios
    for (let testRun = 0; testRun < 20; testRun++) {
      const tunnelId = `tunnel-failure-${Date.now()}-${Math.random()}`;

      // Record only failed requests
      const requestCount = Math.floor(Math.random() * 50) + 1;
      for (let i = 0; i < requestCount; i++) {
        const latency = Math.floor(Math.random() * 1000) + 1;

        tunnelHealthService.recordRequestMetrics(tunnelId, {
          latency,
          success: false,
          statusCode: 500,
        });
      }

      // Get metrics
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Verify 0% success rate
      expect(metrics.successRate).toBe(0);
      expect(metrics.successCount).toBe(0);
      expect(metrics.errorCount).toBe(requestCount);
      expect(metrics.requestCount).toBe(requestCount);
    }
  });

  /**
   * Property: Single request metrics should be consistent
   *
   * For any tunnel with a single request, the metrics should reflect
   * that single request exactly.
   *
   * Validates: Requirements 4.6
   */
  it("should handle single request metrics correctly", () => {
    // Test with multiple single request scenarios
    for (let testRun = 0; testRun < 20; testRun++) {
      const tunnelId = `tunnel-single-${Date.now()}-${Math.random()}`;

      const latency = Math.floor(Math.random() * 1000) + 1;
      const success = Math.random() > 0.5;

      // Record single request
      tunnelHealthService.recordRequestMetrics(tunnelId, {
        latency,
        success,
        statusCode: success ? 200 : 500,
      });

      // Get metrics
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Verify single request metrics
      expect(metrics.requestCount).toBe(1);
      expect(metrics.successCount).toBe(success ? 1 : 0);
      expect(metrics.errorCount).toBe(success ? 0 : 1);
      expect(metrics.averageLatency).toBe(latency);
      expect(metrics.minLatency).toBe(latency);
      expect(metrics.maxLatency).toBe(latency);
      expect(metrics.successRate).toBe(success ? 100 : 0);
    }
  });

  /**
   * Property: Empty metrics should have zero values
   *
   * For any tunnel with no recorded requests, all metrics should be zero.
   *
   * Validates: Requirements 4.6
   */
  it("should return zero metrics for tunnels with no requests", () => {
    // Test with multiple tunnels
    for (let testRun = 0; testRun < 10; testRun++) {
      const tunnelId = `tunnel-empty-${Date.now()}-${Math.random()}`;

      // Get metrics without recording any requests
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Verify all metrics are zero
      expect(metrics.requestCount).toBe(0);
      expect(metrics.successCount).toBe(0);
      expect(metrics.errorCount).toBe(0);
      expect(metrics.successRate).toBe(0);
      expect(metrics.averageLatency).toBe(0);
      expect(metrics.minLatency).toBe(0);
      expect(metrics.maxLatency).toBe(0);
    }
  });

  /**
   * Property: Latency bounds should be consistent
   *
   * For any tunnel with recorded requests, the minimum latency should be
   * less than or equal to the maximum latency.
   *
   * Validates: Requirements 4.6
   */
  it("should maintain consistent latency bounds", () => {
    // Test with multiple scenarios
    for (let testRun = 0; testRun < 30; testRun++) {
      const tunnelId = `tunnel-latency-${Date.now()}-${Math.random()}`;

      // Record random requests
      const requestCount = Math.floor(Math.random() * 100) + 1;
      const latencies = [];

      for (let i = 0; i < requestCount; i++) {
        const latency = Math.floor(Math.random() * 1000) + 1;
        latencies.push(latency);

        tunnelHealthService.recordRequestMetrics(tunnelId, {
          latency,
          success: Math.random() > 0.3,
          statusCode: Math.random() > 0.3 ? 200 : 500,
        });
      }

      // Get metrics
      const metrics = tunnelHealthService.getAggregatedMetrics(tunnelId);

      // Calculate expected bounds
      const expectedMinLatency = Math.min(...latencies);
      const expectedMaxLatency = Math.max(...latencies);

      // Verify bounds
      expect(metrics.minLatency).toBe(expectedMinLatency);
      expect(metrics.maxLatency).toBe(expectedMaxLatency);
      expect(metrics.minLatency).toBeLessThanOrEqual(metrics.maxLatency);
    }
  });

  /**
   * Property: Metrics should accumulate correctly
   *
   * For any tunnel, recording multiple requests should produce cumulative metrics
   * that maintain mathematical consistency.
   *
   * Validates: Requirements 4.6
   */
  it("should accumulate metrics correctly for repeated recordings", () => {
    const tunnelId = `tunnel-accumulate-${Date.now()}-${Math.random()}`;

    // Record first batch
    tunnelHealthService.recordRequestMetrics(tunnelId, {
      latency: 100,
      success: true,
      statusCode: 200,
    });

    tunnelHealthService.recordRequestMetrics(tunnelId, {
      latency: 200,
      success: true,
      statusCode: 200,
    });

    const metricsAfterFirstBatch =
      tunnelHealthService.getAggregatedMetrics(tunnelId);

    // Record second batch
    tunnelHealthService.recordRequestMetrics(tunnelId, {
      latency: 150,
      success: false,
      statusCode: 500,
    });

    tunnelHealthService.recordRequestMetrics(tunnelId, {
      latency: 250,
      success: true,
      statusCode: 200,
    });

    const metricsAfterSecondBatch =
      tunnelHealthService.getAggregatedMetrics(tunnelId);

    // Verify accumulation
    expect(metricsAfterSecondBatch.requestCount).toBe(
      metricsAfterFirstBatch.requestCount + 2,
    );
    expect(metricsAfterSecondBatch.successCount).toBe(
      metricsAfterFirstBatch.successCount + 1,
    );
    expect(metricsAfterSecondBatch.errorCount).toBe(
      metricsAfterFirstBatch.errorCount + 1,
    );

    // Verify consistency
    expect(metricsAfterSecondBatch.requestCount).toBe(
      metricsAfterSecondBatch.successCount + metricsAfterSecondBatch.errorCount,
    );
  });
});
