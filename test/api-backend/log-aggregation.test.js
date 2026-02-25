/**
 * Unit Tests for Log Aggregation Support
 *
 * Tests log formatting for Loki and ELK compatibility,
 * log batching, routing, and aggregation system integration.
 *
 * **Feature: api-backend-enhancement, Property 11: Metrics consistency**
 * **Validates: Requirements 8.9**
 */

import {
  logAggregationConfig,
  formatForLoki,
  formatForELK,
  LogBatcher,
  LogRouter,
  createStructuredLogEntry,
  getCorrelationId,
  getUserIdFromRequest,
} from '../../services/api-backend/utils/log-aggregation.js';

describe('Log Aggregation Support', () => {
  describe('Log Aggregation Configuration', () => {
    test('should have default Loki configuration', () => {
      expect(logAggregationConfig.loki).toBeDefined();
      expect(logAggregationConfig.loki.url).toBeDefined();
      expect(logAggregationConfig.loki.labels).toBeDefined();
      expect(logAggregationConfig.loki.labels.service).toBe('cloudtolocalllm-api');
    });

    test('should have default ELK configuration', () => {
      expect(logAggregationConfig.elk).toBeDefined();
      expect(logAggregationConfig.elk.hosts).toBeDefined();
      expect(logAggregationConfig.elk.index).toBeDefined();
    });

    test('should have routing configuration', () => {
      expect(logAggregationConfig.routing).toBeDefined();
      expect(typeof logAggregationConfig.routing.errorToSentry).toBe('boolean');
      expect(typeof logAggregationConfig.routing.errorToFile).toBe('boolean');
    });
  });

  describe('Loki Log Formatting', () => {
    test('should format log entry for Loki with required fields', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'info',
        message: 'Test log message',
        correlationId: 'corr-123',
        userId: 'user-456',
      };

      const formatted = formatForLoki(logEntry);

      expect(formatted).toHaveProperty('timestamp');
      expect(formatted).toHaveProperty('stream');
      expect(formatted).toHaveProperty('values');
      expect(formatted.stream.level).toBe('info');
      expect(formatted.stream.service).toBe('cloudtolocalllm-api');
    });

    test('should include correlation ID in Loki stream labels', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'error',
        message: 'Error occurred',
        correlationId: 'corr-789',
      };

      const formatted = formatForLoki(logEntry);

      expect(formatted.stream.correlationId).toBe('corr-789');
    });

    test('should include user ID in Loki stream labels', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'warn',
        message: 'Warning message',
        userId: 'user-123',
      };

      const formatted = formatForLoki(logEntry);

      expect(formatted.stream.userId).toBe('user-123');
    });

    test('should convert timestamp to nanoseconds for Loki', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00.000Z',
        level: 'info',
        message: 'Test',
      };

      const formatted = formatForLoki(logEntry);

      expect(formatted.timestamp).toBeGreaterThan(0);
      expect(typeof formatted.timestamp).toBe('number');
    });

    test('should include metadata in Loki log values', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'info',
        message: 'Test',
        customField: 'customValue',
      };

      const formatted = formatForLoki(logEntry);

      expect(formatted.values).toHaveLength(1);
      const logValue = JSON.parse(formatted.values[0][1]);
      expect(logValue.customField).toBe('customValue');
    });
  });

  describe('ELK Log Formatting', () => {
    test('should format log entry for ELK with required fields', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'info',
        message: 'Test log message',
        correlationId: 'corr-123',
        userId: 'user-456',
      };

      const formatted = formatForELK(logEntry);

      expect(formatted).toHaveProperty('@timestamp');
      expect(formatted).toHaveProperty('level');
      expect(formatted).toHaveProperty('message');
      expect(formatted).toHaveProperty('service');
      expect(formatted.level).toBe('info');
      expect(formatted.message).toBe('Test log message');
    });

    test('should format timestamp as ISO string for ELK', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'info',
        message: 'Test',
      };

      const formatted = formatForELK(logEntry);

      expect(formatted['@timestamp']).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    });

    test('should include correlation ID in ELK log', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'error',
        message: 'Error',
        correlationId: 'corr-999',
      };

      const formatted = formatForELK(logEntry);

      expect(formatted.correlationId).toBe('corr-999');
    });

    test('should include stack trace in ELK log', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'error',
        message: 'Error',
        stack: 'Error: Test\n  at test.js:1:1',
      };

      const formatted = formatForELK(logEntry);

      expect(formatted.stack).toBe('Error: Test\n  at test.js:1:1');
    });

    test('should include metadata in ELK log', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'info',
        message: 'Test',
        customField: 'customValue',
        anotherField: 123,
      };

      const formatted = formatForELK(logEntry);

      expect(formatted.metadata.customField).toBe('customValue');
      expect(formatted.metadata.anotherField).toBe(123);
    });
  });

  describe('Log Batching', () => {
    test('should create log batcher with default configuration', () => {
      const batcher = new LogBatcher();

      expect(batcher.batchSize).toBe(100);
      expect(batcher.batchTimeout).toBe(5000);
      expect(batcher.batch).toEqual([]);
    });

    test('should add logs to batch', () => {
      const batcher = new LogBatcher({ batchSize: 10 });
      const logEntry = { level: 'info', message: 'Test' };

      batcher.add(logEntry);

      expect(batcher.batch).toHaveLength(1);
      expect(batcher.batch[0]).toEqual(logEntry);
    });

    test('should flush batch when size limit reached', (done) => {
      const batcher = new LogBatcher({
        batchSize: 2,
        onFlush: (logs) => {
          expect(logs).toHaveLength(2);
          done();
        },
      });

      batcher.add({ level: 'info', message: 'Log 1' });
      batcher.add({ level: 'info', message: 'Log 2' });
    });

    test('should flush batch after timeout', (done) => {
      const batcher = new LogBatcher({
        batchSize: 100,
        batchTimeout: 100,
        onFlush: (logs) => {
          expect(logs).toHaveLength(1);
          done();
        },
      });

      batcher.add({ level: 'info', message: 'Test' });
    });

    test('should clear batch after flush', (done) => {
      const batcher = new LogBatcher({
        batchSize: 1,
        onFlush: () => {
          expect(batcher.batch).toHaveLength(0);
          done();
        },
      });

      batcher.add({ level: 'info', message: 'Test' });
    });

    test('should not flush empty batch', (done) => {
      let flushCalled = false;
      const batcher = new LogBatcher({
        batchSize: 100,
        batchTimeout: 50,
        onFlush: () => {
          flushCalled = true;
        },
      });

      setTimeout(() => {
        expect(flushCalled).toBe(false);
        done();
      }, 100);
    });

    test('should destroy batcher and flush remaining logs', (done) => {
      const batcher = new LogBatcher({
        batchSize: 100,
        onFlush: (logs) => {
          expect(logs).toHaveLength(1);
          done();
        },
      });

      batcher.add({ level: 'info', message: 'Test' });
      batcher.destroy();
    });
  });

  describe('Log Router', () => {
    test('should create log router with default configuration', () => {
      const router = new LogRouter();

      expect(router.config).toBeDefined();
      expect(router.config.errorToSentry).toBeDefined();
      expect(router.config.errorToFile).toBeDefined();
    });

    test('should determine destinations for error level', () => {
      const router = new LogRouter({
        errorToSentry: true,
        errorToFile: true,
        infoToConsole: true,
      });

      const destinations = router.getDestinations('error');

      expect(destinations).toContain('sentry');
      expect(destinations).toContain('file');
    });

    test('should determine destinations for warn level', () => {
      const router = new LogRouter({
        warningToFile: true,
        infoToConsole: true,
      });

      const destinations = router.getDestinations('warn');

      expect(destinations).toContain('file');
    });

    test('should determine destinations for info level', () => {
      const router = new LogRouter({
        infoToConsole: true,
      });

      const destinations = router.getDestinations('info');

      expect(destinations).toContain('console');
    });

    test('should check if destination is enabled', () => {
      const router = new LogRouter({
        errorToSentry: true,
        errorToFile: false,
        warningToFile: false,
      });

      expect(router.isDestinationEnabled('sentry')).toBe(true);
      expect(router.isDestinationEnabled('file')).toBe(false);
    });

    test('should return false for unknown destination', () => {
      const router = new LogRouter();

      expect(router.isDestinationEnabled('unknown')).toBe(false);
    });
  });

  describe('Structured Log Entry Creation', () => {
    test('should create structured log entry with all fields', () => {
      const logEntry = createStructuredLogEntry({
        level: 'error',
        message: 'Test error',
        correlationId: 'corr-123',
        userId: 'user-456',
        stack: 'Error stack',
      });

      expect(logEntry.level).toBe('error');
      expect(logEntry.message).toBe('Test error');
      expect(logEntry.correlationId).toBe('corr-123');
      expect(logEntry.userId).toBe('user-456');
      expect(logEntry.stack).toBe('Error stack');
      expect(logEntry.timestamp).toBeDefined();
    });

    test('should create structured log entry with default values', () => {
      const logEntry = createStructuredLogEntry();

      expect(logEntry.level).toBe('info');
      expect(logEntry.message).toBe('');
      expect(logEntry.correlationId).toBeNull();
      expect(logEntry.userId).toBeNull();
      expect(logEntry.timestamp).toBeDefined();
    });

    test('should include additional metadata in structured log entry', () => {
      const logEntry = createStructuredLogEntry({
        level: 'info',
        message: 'Test',
        customField: 'customValue',
        anotherField: 123,
      });

      expect(logEntry.customField).toBe('customValue');
      expect(logEntry.anotherField).toBe(123);
    });
  });

  describe('Request Context Extraction', () => {
    test('should extract correlation ID from x-correlation-id header', () => {
      const req = {
        headers: {
          'x-correlation-id': 'corr-123',
        },
      };

      const correlationId = getCorrelationId(req);

      expect(correlationId).toBe('corr-123');
    });

    test('should extract correlation ID from x-request-id header', () => {
      const req = {
        headers: {
          'x-request-id': 'req-456',
        },
      };

      const correlationId = getCorrelationId(req);

      expect(correlationId).toBe('req-456');
    });

    test('should prefer x-correlation-id over x-request-id', () => {
      const req = {
        headers: {
          'x-correlation-id': 'corr-123',
          'x-request-id': 'req-456',
        },
      };

      const correlationId = getCorrelationId(req);

      expect(correlationId).toBe('corr-123');
    });

    test('should extract correlation ID from req.id', () => {
      const req = {
        headers: {},
        id: 'req-789',
      };

      const correlationId = getCorrelationId(req);

      expect(correlationId).toBe('req-789');
    });

    test('should return null if no correlation ID found', () => {
      const req = {
        headers: {},
      };

      const correlationId = getCorrelationId(req);

      expect(correlationId).toBeNull();
    });

    test('should extract user ID from req.userId', () => {
      const req = {
        userId: 'user-123',
      };

      const userId = getUserIdFromRequest(req);

      expect(userId).toBe('user-123');
    });

    test('should extract user ID from req.user.id', () => {
      const req = {
        user: {
          id: 'user-456',
        },
      };

      const userId = getUserIdFromRequest(req);

      expect(userId).toBe('user-456');
    });

    test('should return null if no user ID found', () => {
      const req = {};

      const userId = getUserIdFromRequest(req);

      expect(userId).toBeNull();
    });
  });

  describe('Log Format Consistency', () => {
    test('should maintain consistency between Loki and ELK formats', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'error',
        message: 'Test error',
        correlationId: 'corr-123',
        userId: 'user-456',
      };

      const lokiFormatted = formatForLoki(logEntry);
      const elkFormatted = formatForELK(logEntry);

      // Both should contain the same core information
      expect(lokiFormatted.stream.level).toBe(elkFormatted.level);
      expect(lokiFormatted.stream.correlationId).toBe(elkFormatted.correlationId);
      expect(lokiFormatted.stream.userId).toBe(elkFormatted.userId);
    });

    test('should handle missing optional fields gracefully', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'info',
        message: 'Test',
      };

      const lokiFormatted = formatForLoki(logEntry);
      const elkFormatted = formatForELK(logEntry);

      expect(lokiFormatted).toBeDefined();
      expect(elkFormatted).toBeDefined();
      expect(lokiFormatted.stream).toBeDefined();
      expect(elkFormatted).toBeDefined();
    });

    test('should preserve all metadata fields in both formats', () => {
      const logEntry = {
        timestamp: '2024-01-15T10:30:00Z',
        level: 'warn',
        message: 'Test',
        customField1: 'value1',
        customField2: 'value2',
      };

      const lokiFormatted = formatForLoki(logEntry);
      const elkFormatted = formatForELK(logEntry);

      const lokiLog = JSON.parse(lokiFormatted.values[0][1]);
      expect(lokiLog.customField1).toBe('value1');
      expect(lokiLog.customField2).toBe('value2');

      expect(elkFormatted.metadata.customField1).toBe('value1');
      expect(elkFormatted.metadata.customField2).toBe('value2');
    });
  });
});
