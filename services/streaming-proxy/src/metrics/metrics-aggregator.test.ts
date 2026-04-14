/**
 * Tests for Metrics Aggregator
 * 
 * Tests time-series aggregation, retention windows, and cleanup
 */

import { MetricsAggregator, RawMetricSnapshot, AggregatedMetric } from './metrics-aggregator';

describe('MetricsAggregator', () => {
  let aggregator: MetricsAggregator;

  beforeEach(() => {
    aggregator = new MetricsAggregator(3600);
  });

  describe('Raw Metrics Recording', () => {
    it('should record raw metric snapshots', () => {
      const snapshot: RawMetricSnapshot = {
        timestamp: new Date(),
        activeConnections: 10,
        requestCount: 100,
        successCount: 95,
        errorCount: 5,
        averageLatency: 50,
        p95Latency: 100,
        p99Latency: 150,
        bytesReceived: 1000,
        bytesSent: 2000,
        requestsPerSecond: 10,
        errorRate: 0.05,
        activeUsers: 5,
        memoryUsage: 100000000,
        cpuUsage: 0.5,
      };

      aggregator.recordMetric(snapshot);
      const metrics = aggregator.getRawMetrics();

      expect(metrics).toHaveLength(1);
      expect(metrics[0].activeConnections).toBe(10);
      expect(metrics[0].requestCount).toBe(100);
    });

    it('should trim raw metrics when exceeding max size', () => {
      const smallAggregator = new MetricsAggregator(5);

      for (let i = 0; i < 10; i++) {
        const snapshot: RawMetricSnapshot = {
          timestamp: new Date(Date.now() + i * 1000),
          activeConnections: i,
          requestCount: i * 10,
          successCount: i * 9,
          errorCount: i,
          averageLatency: 50,
          p95Latency: 100,
          p99Latency: 150,
          bytesReceived: 1000,
          bytesSent: 2000,
          requestsPerSecond: 10,
          errorRate: 0.05,
          activeUsers: 5,
          memoryUsage: 100000000,
          cpuUsage: 0.5,
        };
        smallAggregator.recordMetric(snapshot);
      }

      const metrics = smallAggregator.getRawMetrics();
      expect(metrics.length).toBeLessThanOrEqual(5);
    });
  });

  describe('Time Window Filtering', () => {
    it('should filter raw metrics by time window', () => {
      const now = Date.now();

      // Add metrics from different times
      for (let i = 0; i < 5; i++) {
        const snapshot: RawMetricSnapshot = {
          timestamp: new Date(now - (5 - i) * 600000), // 10 minutes apart
          activeConnections: i,
          requestCount: i * 10,
          successCount: i * 9,
          errorCount: i,
          averageLatency: 50,
          p95Latency: 100,
          p99Latency: 150,
          bytesReceived: 1000,
          bytesSent: 2000,
          requestsPerSecond: 10,
          errorRate: 0.05,
          activeUsers: 5,
          memoryUsage: 100000000,
          cpuUsage: 0.5,
        };
        aggregator.recordMetric(snapshot);
      }

      // Get metrics from last 15 minutes
      const recentMetrics = aggregator.getRawMetrics(900000);
      expect(recentMetrics.length).toBeGreaterThan(0);
      expect(recentMetrics.length).toBeLessThanOrEqual(5);
    });
  });

  describe('Aggregation', () => {
    it('should create hourly aggregates from raw metrics', () => {
      const now = Date.now();
      const hourStart = Math.floor(now / 3600000) * 3600000;

      // Add metrics for the current hour
      for (let i = 0; i < 60; i++) {
        const snapshot: RawMetricSnapshot = {
          timestamp: new Date(hourStart + i * 60000), // Every minute
          activeConnections: 10 + i,
          requestCount: 100 + i * 10,
          successCount: 95 + i * 9,
          errorCount: 5 + i,
          averageLatency: 50 + i,
          p95Latency: 100 + i,
          p99Latency: 150 + i,
          bytesReceived: 1000 + i * 100,
          bytesSent: 2000 + i * 100,
          requestsPerSecond: 10 + i,
          errorRate: 0.05,
          activeUsers: 5 + i,
          memoryUsage: 100000000,
          cpuUsage: 0.5,
        };
        aggregator.recordMetric(snapshot);
      }

      // Manually trigger aggregation
      (aggregator as any).aggregateToHourly();

      const hourlyAggregates = aggregator.getHourlyAggregates();
      expect(hourlyAggregates.length).toBeGreaterThan(0);

      const aggregate = hourlyAggregates[0];
      expect(aggregate.aggregationLevel).toBe('hourly');
      expect(aggregate.totalRequests).toBeGreaterThan(0);
      expect(aggregate.sampleCount).toBe(60);
    });

    it('should calculate correct aggregate values', () => {
      const now = Date.now();
      const hourStart = Math.floor(now / 3600000) * 3600000;

      // Add 3 metrics with known values
      const metrics: RawMetricSnapshot[] = [
        {
          timestamp: new Date(hourStart),
          activeConnections: 10,
          requestCount: 100,
          successCount: 90,
          errorCount: 10,
          averageLatency: 50,
          p95Latency: 100,
          p99Latency: 150,
          bytesReceived: 1000,
          bytesSent: 2000,
          requestsPerSecond: 10,
          errorRate: 0.1,
          activeUsers: 5,
          memoryUsage: 100000000,
          cpuUsage: 0.5,
        },
        {
          timestamp: new Date(hourStart + 600000),
          activeConnections: 20,
          requestCount: 200,
          successCount: 180,
          errorCount: 20,
          averageLatency: 60,
          p95Latency: 110,
          p99Latency: 160,
          bytesReceived: 2000,
          bytesSent: 4000,
          requestsPerSecond: 20,
          errorRate: 0.1,
          activeUsers: 10,
          memoryUsage: 200000000,
          cpuUsage: 1.0,
        },
        {
          timestamp: new Date(hourStart + 1200000),
          activeConnections: 30,
          requestCount: 300,
          successCount: 270,
          errorCount: 30,
          averageLatency: 70,
          p95Latency: 120,
          p99Latency: 170,
          bytesReceived: 3000,
          bytesSent: 6000,
          requestsPerSecond: 30,
          errorRate: 0.1,
          activeUsers: 15,
          memoryUsage: 300000000,
          cpuUsage: 1.5,
        },
      ];

      for (const metric of metrics) {
        aggregator.recordMetric(metric);
      }

      // Manually trigger aggregation
      (aggregator as any).aggregateToHourly();

      const hourlyAggregates = aggregator.getHourlyAggregates();
      const aggregate = hourlyAggregates[0];

      // Verify totals
      expect(aggregate.totalRequests).toBe(600); // 100 + 200 + 300
      expect(aggregate.totalSuccessful).toBe(540); // 90 + 180 + 270
      expect(aggregate.totalErrors).toBe(60); // 10 + 20 + 30
      expect(aggregate.totalBytesReceived).toBe(6000); // 1000 + 2000 + 3000
      expect(aggregate.totalBytesSent).toBe(12000); // 2000 + 4000 + 6000

      // Verify averages
      expect(aggregate.averageLatency).toBe(60); // (50 + 60 + 70) / 3
      expect(aggregate.averageActiveConnections).toBe(20); // (10 + 20 + 30) / 3
      expect(aggregate.peakActiveConnections).toBe(30);
      expect(aggregate.sampleCount).toBe(3);
    });
  });

  describe('Statistics', () => {
    it('should calculate statistics for raw metrics', () => {
      const now = Date.now();

      for (let i = 0; i < 10; i++) {
        const snapshot: RawMetricSnapshot = {
          timestamp: new Date(now - (9 - i) * 60000),
          activeConnections: 10,
          requestCount: 100,
          successCount: 90,
          errorCount: 10,
          averageLatency: 50,
          p95Latency: 100,
          p99Latency: 150,
          bytesReceived: 1000,
          bytesSent: 2000,
          requestsPerSecond: 10,
          errorRate: 0.1,
          activeUsers: 5,
          memoryUsage: 100000000,
          cpuUsage: 0.5,
        };
        aggregator.recordMetric(snapshot);
      }

      const stats = aggregator.getStatistics(600000, 'raw');

      expect(stats.count).toBe(10);
      expect(stats.totalRequests).toBe(1000); // 100 * 10
      expect(stats.averageRequests).toBe(100);
      expect(stats.averageLatency).toBe(50);
      expect(stats.averageErrorRate).toBeCloseTo(0.1);
    });

    it('should return empty statistics when no data', () => {
      const stats = aggregator.getStatistics(3600000, 'raw');

      expect(stats.count).toBe(0);
      expect(stats.totalRequests).toBe(0);
      expect(stats.averageRequests).toBe(0);
    });
  });

  describe('Reset', () => {
    it('should reset all data', () => {
      const snapshot: RawMetricSnapshot = {
        timestamp: new Date(),
        activeConnections: 10,
        requestCount: 100,
        successCount: 95,
        errorCount: 5,
        averageLatency: 50,
        p95Latency: 100,
        p99Latency: 150,
        bytesReceived: 1000,
        bytesSent: 2000,
        requestsPerSecond: 10,
        errorRate: 0.05,
        activeUsers: 5,
        memoryUsage: 100000000,
        cpuUsage: 0.5,
      };

      aggregator.recordMetric(snapshot);
      expect(aggregator.getRawMetrics()).toHaveLength(1);

      aggregator.reset();
      expect(aggregator.getRawMetrics()).toHaveLength(0);
      expect(aggregator.getHourlyAggregates()).toHaveLength(0);
      expect(aggregator.getDailyAggregates()).toHaveLength(0);
    });
  });
});
