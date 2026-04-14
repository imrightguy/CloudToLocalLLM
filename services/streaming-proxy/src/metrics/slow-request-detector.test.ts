/**
 * Slow Request Detector Tests
 * 
 * Tests for slow request detection, logging, and alerting functionality
 */

import { SlowRequestDetector } from './slow-request-detector';
import { ConsoleLogger } from '../utils/logger';

describe('SlowRequestDetector', () => {
  let detector: SlowRequestDetector;
  let loggedWarnings: any[] = [];
  let mockLogger: ConsoleLogger;

  beforeEach(() => {
    // Create mock logger to capture warnings
    loggedWarnings = [];
    mockLogger = {
      warn: (message: string, metadata?: any) => {
        loggedWarnings.push({ message, metadata });
      },
      info: () => {},
      debug: () => {},
      error: () => {},
    } as any;

    detector = new SlowRequestDetector(
      {
        slowThresholdMs: 5000,
        alertThresholdRate: 0.1,
        windowMs: 300000,
        maxHistorySize: 1000,
      },
      mockLogger
    );
  });

  describe('trackRequest', () => {
    it('should log slow requests exceeding threshold', () => {
      detector.trackRequest('user1', 'req-1', 6000, '/api/test');

      const slowLogs = loggedWarnings.filter(w => w.message === 'Slow request detected');
      expect(slowLogs.length).toBe(1);
      expect(slowLogs[0].metadata).toEqual({
        userId: 'user1',
        requestId: 'req-1',
        duration: 6000,
        endpoint: '/api/test',
        threshold: 5000,
      });
    });

    it('should not log requests below threshold', () => {
      detector.trackRequest('user1', 'req-1', 3000, '/api/test');

      expect(loggedWarnings.length).toBe(0);
    });

    it('should include all required fields in log', () => {
      detector.trackRequest('user123', 'request-abc', 7500, '/api/endpoint');

      const warning = loggedWarnings[0];
      expect(warning.metadata.userId).toBe('user123');
      expect(warning.metadata.requestId).toBe('request-abc');
      expect(warning.metadata.duration).toBe(7500);
      expect(warning.metadata.endpoint).toBe('/api/endpoint');
    });

    it('should handle requests without endpoint', () => {
      detector.trackRequest('user1', 'req-1', 6000);

      const slowLogs = loggedWarnings.filter(w => w.message === 'Slow request detected');
      expect(slowLogs.length).toBe(1);
      expect(slowLogs[0].metadata.endpoint).toBeUndefined();
    });
  });

  describe('getSlowRequestRate', () => {
    it('should calculate slow request rate correctly', () => {
      // Track 10 requests, 2 are slow
      for (let i = 0; i < 8; i++) {
        detector.trackRequest('user1', `req-${i}`, 3000);
      }
      for (let i = 8; i < 10; i++) {
        detector.trackRequest('user1', `req-${i}`, 6000);
      }

      const rate = detector.getSlowRequestRate();
      // Rate should be approximately 0.2 (2 slow out of 10)
      expect(rate).toBeGreaterThan(0.1);
    });

    it('should return 0 when no requests tracked', () => {
      const rate = detector.getSlowRequestRate();
      expect(rate).toBe(0);
    });
  });

  describe('getSlowRequestCount', () => {
    it('should count slow requests in window', () => {
      detector.trackRequest('user1', 'req-1', 6000);
      detector.trackRequest('user1', 'req-2', 7000);
      detector.trackRequest('user1', 'req-3', 3000);

      const count = detector.getSlowRequestCount();
      expect(count).toBe(2);
    });
  });

  describe('getSlowRequestsByUser', () => {
    it('should filter slow requests by user', () => {
      detector.trackRequest('user1', 'req-1', 6000);
      detector.trackRequest('user2', 'req-2', 7000);
      detector.trackRequest('user1', 'req-3', 3000);

      const user1Slow = detector.getSlowRequestsByUser('user1');
      expect(user1Slow.length).toBe(1);
      expect(user1Slow[0].requestId).toBe('req-1');
    });
  });

  describe('getStatistics', () => {
    it('should calculate statistics correctly', () => {
      detector.trackRequest('user1', 'req-1', 5000);
      detector.trackRequest('user1', 'req-2', 7000);
      detector.trackRequest('user2', 'req-3', 6000);

      const stats = detector.getStatistics();

      expect(stats.totalSlowRequests).toBe(3);
      expect(stats.averageDuration).toBe(6000);
      expect(stats.maxDuration).toBe(7000);
      expect(stats.slowestRequest?.requestId).toBe('req-2');
      expect(stats.slowRequestsByUser['user1']).toBe(2);
      expect(stats.slowRequestsByUser['user2']).toBe(1);
    });

    it('should return empty stats when no slow requests', () => {
      const stats = detector.getStatistics();

      expect(stats.totalSlowRequests).toBe(0);
      expect(stats.slowRequestRate).toBe(0);
      expect(stats.averageDuration).toBe(0);
      expect(stats.maxDuration).toBe(0);
      expect(stats.slowestRequest).toBeNull();
    });
  });

  describe('exportPrometheusMetrics', () => {
    it('should export metrics in Prometheus format', () => {
      detector.trackRequest('user1', 'req-1', 6000);
      detector.trackRequest('user1', 'req-2', 7000);

      const metrics = detector.exportPrometheusMetrics();

      expect(metrics).toContain('tunnel_slow_requests_total');
      expect(metrics).toContain('tunnel_slow_request_rate');
      expect(metrics).toContain('tunnel_slow_request_duration_avg_ms');
      expect(metrics).toContain('tunnel_slow_request_duration_max_ms');
      expect(metrics).toContain('tunnel_slow_requests_by_user_total');
    });

    it('should include correct metric values', () => {
      detector.trackRequest('user1', 'req-1', 5000);
      detector.trackRequest('user1', 'req-2', 7000);

      const metrics = detector.exportPrometheusMetrics();

      expect(metrics).toContain('tunnel_slow_requests_total 2');
      expect(metrics).toContain('tunnel_slow_request_duration_avg_ms 6000');
      expect(metrics).toContain('tunnel_slow_request_duration_max_ms 7000');
    });
  });

  describe('alert mechanism', () => {
    it('should alert when slow request rate exceeds threshold', () => {
      // Create detector with lower threshold for testing
      const testDetector = new SlowRequestDetector(
        {
          slowThresholdMs: 1000,
          alertThresholdRate: 0.3, // 30%
          windowMs: 300000,
          maxHistorySize: 1000,
        },
        mockLogger
      );

      // Track 10 requests, 4 are slow (40% > 30% threshold)
      for (let i = 0; i < 6; i++) {
        testDetector.trackRequest('user1', `req-${i}`, 500);
      }
      for (let i = 6; i < 10; i++) {
        testDetector.trackRequest('user1', `req-${i}`, 2000);
      }

      // Should have logged slow requests and alert
      const slowRequestLogs = loggedWarnings.filter(
        w => w.message === 'Slow request detected'
      );
      expect(slowRequestLogs.length).toBe(4);

      // Should have alert
      const alerts = loggedWarnings.filter(
        w => w.message === 'High slow request rate detected!'
      );
      expect(alerts.length).toBeGreaterThan(0);
    });

    it('should respect alert cooldown', () => {
      const testDetector = new SlowRequestDetector(
        {
          slowThresholdMs: 1000,
          alertThresholdRate: 0.3,
          windowMs: 300000,
          maxHistorySize: 1000,
        },
        mockLogger
      );

      // Track requests to trigger alert
      for (let i = 0; i < 10; i++) {
        testDetector.trackRequest('user1', `req-${i}`, 2000);
      }

      const firstAlerts = loggedWarnings.filter(
        w => w.message === 'High slow request rate detected!'
      );

      // Clear logs
      loggedWarnings = [];

      // Track more requests immediately
      for (let i = 10; i < 20; i++) {
        testDetector.trackRequest('user1', `req-${i}`, 2000);
      }

      const secondAlerts = loggedWarnings.filter(
        w => w.message === 'High slow request rate detected!'
      );

      // Should not alert again due to cooldown
      expect(secondAlerts.length).toBe(0);
    });
  });

  describe('cleanup', () => {
    it('should remove old records outside window', () => {
      detector.trackRequest('user1', 'req-1', 6000);

      // Simulate time passing by manually manipulating the timestamp
      const oldRecord = detector.getSlowRequests()[0];
      oldRecord.timestamp = new Date(Date.now() - 400000); // 400 seconds ago, outside 5-minute window

      detector.cleanup();

      const remaining = detector.getSlowRequests();
      expect(remaining.length).toBe(0);
    });
  });

  describe('reset', () => {
    it('should clear all statistics', () => {
      detector.trackRequest('user1', 'req-1', 6000);
      detector.trackRequest('user1', 'req-2', 7000);

      detector.reset();

      const stats = detector.getStatistics();
      expect(stats.totalSlowRequests).toBe(0);
      expect(stats.slowRequestRate).toBe(0);
    });
  });
});
