/**


 * Metrics Consistency Property-Based Tests
 *
 * Property 11: Metrics consistency
 * Validates: Requirements 8.1, 8.2
 *
 * Property: For any sequence of metric values, the collected metrics should
 * maintain consistency between individual values and aggregated statistics.
 *
 * Feature: api-backend-enhancement, Property 11: Metrics consistency
 */

import { describe, it, expect } from "@jest/globals";
import AlertTriggeringService from "../../services/api-backend/services/alert-triggering-service.js";

describe("Property 11: Metrics Consistency", () => {
  /**
   * Property: For any sequence of metric values, the average should be
   * correctly calculated as sum / count
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain average consistency across metric values", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 1;
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const stats = service.getMetricStats("testMetric");
      const expectedAverage = values.reduce((a, b) => a + b, 0) / values.length;

      expect(Math.abs(stats.average - expectedAverage)).toBeLessThan(0.01);
    }
  });

  /**
   * Property: For any sequence of metric values, the max should be >= all values
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain max consistency across metric values", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 1;
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const stats = service.getMetricStats("testMetric");

      values.forEach((value) => {
        expect(stats.max).toBeGreaterThanOrEqual(value);
      });

      expect(stats.max).toBe(Math.max(...values));
    }
  });

  /**
   * Property: For any sequence of metric values, the min should be <= all values
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain min consistency across metric values", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 1;
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const stats = service.getMetricStats("testMetric");

      values.forEach((value) => {
        expect(stats.min).toBeLessThanOrEqual(value);
      });

      expect(stats.min).toBe(Math.min(...values));
    }
  });

  /**
   * Property: For any sequence of metric values, the latest should equal
   * the last recorded value
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain latest value consistency", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 1;
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const stats = service.getMetricStats("testMetric");

      expect(stats.latest).toBe(values[values.length - 1]);
    }
  });

  /**
   * Property: For any sequence of metric values, the count should equal
   * the number of recorded values (up to buffer size)
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain count consistency", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 1;
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const stats = service.getMetricStats("testMetric");

      expect(stats.count).toBeLessThanOrEqual(values.length);
      expect(stats.count).toBeLessThanOrEqual(service.bufferSize);
    }
  });

  /**
   * Property: For any sequence of metric values, the sum of all values
   * should equal average * count
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain sum consistency (average * count)", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 1;
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const stats = service.getMetricStats("testMetric");
      const expectedSum = values.reduce((a, b) => a + b, 0);
      const calculatedSum = stats.average * stats.count;

      expect(Math.abs(calculatedSum - expectedSum)).toBeLessThan(0.01);
    }
  });

  /**
   * Property: For any two sequences of metrics, if one is a prefix of the other,
   * the statistics should be consistent (monotonic properties)
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain monotonic consistency for metric sequences", () => {
    for (let run = 0; run < 20; run++) {
      const length1 = Math.floor(Math.random() * 25) + 1;
      const length2 = Math.floor(Math.random() * 25) + 1;
      const values1 = Array.from({ length: length1 }, () =>
        Math.floor(Math.random() * 10000),
      );
      const values2 = Array.from({ length: length2 }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service1 = new AlertTriggeringService();
      const service2 = new AlertTriggeringService();

      values1.forEach((value) => {
        service1.recordMetric("testMetric", value);
      });

      values1.forEach((value) => {
        service2.recordMetric("testMetric", value);
      });
      values2.forEach((value) => {
        service2.recordMetric("testMetric", value);
      });

      const stats1 = service1.getMetricStats("testMetric");
      const stats2 = service2.getMetricStats("testMetric");

      // Count should increase
      expect(stats2.count).toBeGreaterThanOrEqual(stats1.count);

      // Max should not decrease
      expect(stats2.max).toBeGreaterThanOrEqual(stats1.max);

      // Min should not increase
      expect(stats2.min).toBeLessThanOrEqual(stats1.min);
    }
  });

  /**
   * Property: For any metric value, recording it multiple times should
   * result in average equal to that value
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain consistency for identical metric values", () => {
    for (let run = 0; run < 20; run++) {
      const value = Math.floor(Math.random() * 10000);
      const count = Math.floor(Math.random() * 50) + 1;

      const service = new AlertTriggeringService();

      for (let i = 0; i < count; i++) {
        service.recordMetric("testMetric", value);
      }

      const stats = service.getMetricStats("testMetric");

      expect(stats.average).toBe(value);
      expect(stats.max).toBe(value);
      expect(stats.min).toBe(value);
      expect(stats.latest).toBe(value);
    }
  });

  /**
   * Property: For any sequence of metrics, the timestamp should be
   * monotonically increasing
   *
   * Validates: Requirements 8.1, 8.2
   */
  it("should maintain timestamp consistency", () => {
    for (let run = 0; run < 20; run++) {
      const length = Math.floor(Math.random() * 50) + 2; // At least 2 values
      const values = Array.from({ length }, () =>
        Math.floor(Math.random() * 10000),
      );

      const service = new AlertTriggeringService();
      values.forEach((value) => {
        service.recordMetric("testMetric", value);
      });

      const buffer = service.metricsBuffer.get("testMetric");

      for (let i = 1; i < buffer.length; i++) {
        expect(buffer[i].timestamp).toBeGreaterThanOrEqual(
          buffer[i - 1].timestamp,
        );
      }
    }
  });
});
