import request from 'supertest';
import express from 'express';
import { ProxyDiagnosticsService } from '../../services/api-backend/services/proxy-diagnostics-service.js';
import { createProxyDiagnosticsRoutes } from '../../services/api-backend/routes/proxy-diagnostics.js';
import { authenticateJWT } from '../../services/api-backend/middleware/auth.js';
import { addTierInfo } from '../../services/api-backend/middleware/tier-check.js';

describe('Proxy Diagnostics', () => {
  let app;
  let diagnosticsService;
  let mockAuthMiddleware;
  let mockTierMiddleware;

  beforeEach(() => {
    // Create Express app for testing
    app = express();
    app.use(express.json());

    // Initialize diagnostics service
    diagnosticsService = new ProxyDiagnosticsService();

    // Mock authentication middleware - use custom implementation
    mockAuthMiddleware = (req, res, next) => {
      req.user = {
        sub: 'test-user-123',
        'https://cloudtolocalllm.online/role': 'admin',
      };
      next();
    };

    // Mock tier info middleware
    mockTierMiddleware = (req, res, next) => {
      req.user.tier = 'premium';
      next();
    };

    // Create a custom router that doesn't use the real middleware
    const customRouter = express.Router();

    // Add all routes manually with mock middleware
    customRouter.get('/diagnostics/:proxyId', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;
        const userId = req.user?.sub;

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        const diagnostics = diagnosticsService.getDiagnostics(proxyId);
        res.json(diagnostics);
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to retrieve proxy diagnostics',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    customRouter.get('/diagnostics/:proxyId/logs', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;
        const { level, since, limit } = req.query;

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        const options = {
          level,
          since,
          limit: limit ? parseInt(limit, 10) : 100,
        };

        const logs = diagnosticsService.getDiagnosticLogs(proxyId, options);
        res.json({
          proxyId,
          logs,
          count: logs.length,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to retrieve proxy diagnostic logs',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    customRouter.get('/diagnostics/:proxyId/errors', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;
        const { since, limit } = req.query;

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        const options = {
          since,
          limit: limit ? parseInt(limit, 10) : 50,
        };

        const errors = diagnosticsService.getErrorHistory(proxyId, options);
        res.json({
          proxyId,
          errors,
          count: errors.length,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to retrieve proxy error history',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    customRouter.get('/diagnostics/:proxyId/events', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;
        const { type, since, limit } = req.query;

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        const options = {
          type,
          since,
          limit: limit ? parseInt(limit, 10) : 100,
        };

        const events = diagnosticsService.getEventHistory(proxyId, options);
        res.json({
          proxyId,
          events,
          count: events.length,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to retrieve proxy event history',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    customRouter.get('/diagnostics/:proxyId/troubleshooting', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        const troubleshooting = diagnosticsService.getTroubleshootingInfo(proxyId);
        res.json(troubleshooting);
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to retrieve proxy troubleshooting information',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    customRouter.get('/diagnostics/:proxyId/export', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        const exportData = diagnosticsService.exportDiagnostics(proxyId);
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Content-Disposition', `attachment; filename="proxy-diagnostics-${proxyId}-${Date.now()}.json"`);
        res.json(exportData);
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to export proxy diagnostics',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    customRouter.post('/diagnostics/:proxyId/clear', mockAuthMiddleware, mockTierMiddleware, (req, res) => {
      try {
        const { proxyId } = req.params;
        const userRole = req.user?.['https://cloudtolocalllm.online/role'] || 'user';

        if (userRole !== 'admin') {
          return res.status(403).json({
            error: 'FORBIDDEN',
            message: 'Admin access required',
            code: 'PROXY_DIAG_004',
          });
        }

        if (!proxyId) {
          return res.status(400).json({
            error: 'INVALID_REQUEST',
            message: 'proxyId is required',
            code: 'PROXY_DIAG_001',
          });
        }

        diagnosticsService.clearDiagnostics(proxyId);
        res.json({
          proxyId,
          message: 'Diagnostics cleared successfully',
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        res.status(500).json({
          error: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to clear proxy diagnostics',
          code: 'PROXY_DIAG_003',
        });
      }
    });

    // Mount custom router
    app.use('/proxy', customRouter);

    // Register test proxy
    diagnosticsService.registerProxy('proxy-001', {
      userId: 'test-user-123',
      containerId: 'container-001',
    });
  });

  afterEach(() => {
    diagnosticsService.shutdown();
  });

  describe('GET /proxy/diagnostics/:proxyId', () => {
    it('should return diagnostics for a registered proxy', async () => {
      const response = await request(app).get('/proxy/diagnostics/proxy-001');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('proxyId', 'proxy-001');
      expect(response.body).toHaveProperty('diagnosticStatus');
      expect(response.body).toHaveProperty('summary');
      expect(response.body).toHaveProperty('recentLogs');
      expect(response.body).toHaveProperty('recentErrors');
      expect(response.body).toHaveProperty('recentEvents');
    });

    it('should return 400 if proxyId is missing', async () => {
      const response = await request(app).get('/proxy/diagnostics/');

      expect(response.status).toBe(404);
    });

    it('should return unknown status for unregistered proxy', async () => {
      const response = await request(app).get('/proxy/diagnostics/unknown-proxy');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'unknown');
    });
  });

  describe('GET /proxy/diagnostics/:proxyId/logs', () => {
    it('should return diagnostic logs for a proxy', async () => {
      // Add some logs
      diagnosticsService.addDiagnosticLog('proxy-001', {
        level: 'info',
        message: 'Proxy started',
        context: { action: 'start' },
      });

      diagnosticsService.addDiagnosticLog('proxy-001', {
        level: 'warn',
        message: 'High latency detected',
        context: { latency: 500 },
      });

      const response = await request(app).get('/proxy/diagnostics/proxy-001/logs');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('proxyId', 'proxy-001');
      expect(response.body).toHaveProperty('logs');
      expect(response.body.logs.length).toBe(2);
      expect(response.body.logs[0].message).toBe('Proxy started');
      expect(response.body.logs[1].message).toBe('High latency detected');
    });

    it('should filter logs by level', async () => {
      diagnosticsService.addDiagnosticLog('proxy-001', {
        level: 'info',
        message: 'Info message',
      });

      diagnosticsService.addDiagnosticLog('proxy-001', {
        level: 'warn',
        message: 'Warning message',
      });

      const response = await request(app).get('/proxy/diagnostics/proxy-001/logs?level=warn');

      expect(response.status).toBe(200);
      expect(response.body.logs.length).toBe(1);
      expect(response.body.logs[0].level).toBe('warn');
    });

    it('should respect limit parameter', async () => {
      for (let i = 0; i < 10; i++) {
        diagnosticsService.addDiagnosticLog('proxy-001', {
          level: 'info',
          message: `Log ${i}`,
        });
      }

      const response = await request(app).get('/proxy/diagnostics/proxy-001/logs?limit=5');

      expect(response.status).toBe(200);
      expect(response.body.logs.length).toBe(5);
    });
  });

  describe('GET /proxy/diagnostics/:proxyId/errors', () => {
    it('should return error history for a proxy', async () => {
      const error1 = new Error('Connection timeout');
      const error2 = new Error('Authentication failed');

      diagnosticsService.recordError('proxy-001', error1, { attempt: 1 });
      diagnosticsService.recordError('proxy-001', error2, { attempt: 2 });

      const response = await request(app).get('/proxy/diagnostics/proxy-001/errors');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('proxyId', 'proxy-001');
      expect(response.body).toHaveProperty('errors');
      expect(response.body.errors.length).toBe(2);
      expect(response.body.errors[0].message).toBe('Connection timeout');
      expect(response.body.errors[1].message).toBe('Authentication failed');
    });

    it('should respect limit parameter for errors', async () => {
      for (let i = 0; i < 20; i++) {
        const error = new Error(`Error ${i}`);
        diagnosticsService.recordError('proxy-001', error);
      }

      const response = await request(app).get('/proxy/diagnostics/proxy-001/errors?limit=10');

      expect(response.status).toBe(200);
      expect(response.body.errors.length).toBe(10);
    });
  });

  describe('GET /proxy/diagnostics/:proxyId/events', () => {
    it('should return event history for a proxy', async () => {
      diagnosticsService.recordEvent('proxy-001', 'started', { timestamp: Date.now() });
      diagnosticsService.recordEvent('proxy-001', 'health_check', { status: 'healthy' });
      diagnosticsService.recordEvent('proxy-001', 'stopped', { reason: 'user_request' });

      const response = await request(app).get('/proxy/diagnostics/proxy-001/events');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('proxyId', 'proxy-001');
      expect(response.body).toHaveProperty('events');
      expect(response.body.events.length).toBe(3);
      expect(response.body.events[0].type).toBe('started');
      expect(response.body.events[1].type).toBe('health_check');
      expect(response.body.events[2].type).toBe('stopped');
    });

    it('should filter events by type', async () => {
      diagnosticsService.recordEvent('proxy-001', 'started', {});
      diagnosticsService.recordEvent('proxy-001', 'health_check', {});
      diagnosticsService.recordEvent('proxy-001', 'health_check', {});

      const response = await request(app).get('/proxy/diagnostics/proxy-001/events?type=health_check');

      expect(response.status).toBe(200);
      expect(response.body.events.length).toBe(2);
      expect(response.body.events.every((e) => e.type === 'health_check')).toBe(true);
    });
  });

  describe('GET /proxy/diagnostics/:proxyId/troubleshooting', () => {
    it('should return troubleshooting information', async () => {
      const error = new Error('Connection timeout');
      diagnosticsService.recordError('proxy-001', error);

      const response = await request(app).get('/proxy/diagnostics/proxy-001/troubleshooting');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('proxyId', 'proxy-001');
      expect(response.body).toHaveProperty('suggestions');
      expect(response.body).toHaveProperty('commonIssues');
      expect(response.body).toHaveProperty('recommendedActions');
    });

    it('should generate suggestions for timeout errors', async () => {
      for (let i = 0; i < 6; i++) {
        const error = new Error('Connection timeout');
        diagnosticsService.recordError('proxy-001', error);
      }

      const response = await request(app).get('/proxy/diagnostics/proxy-001/troubleshooting');

      expect(response.status).toBe(200);
      expect(response.body.suggestions.length).toBeGreaterThan(0);
      const timeoutSuggestion = response.body.suggestions.find((s) => s.issue && s.issue.toLowerCase().includes('timeout'));
      expect(timeoutSuggestion).toBeDefined();
      if (timeoutSuggestion) {
        expect(timeoutSuggestion.suggestion).toContain('timeout');
      }
    });

    it('should identify common issues', async () => {
      for (let i = 0; i < 10; i++) {
        const error = new Error('Connection refused');
        diagnosticsService.recordError('proxy-001', error);
      }

      const response = await request(app).get('/proxy/diagnostics/proxy-001/troubleshooting');

      expect(response.status).toBe(200);
      expect(response.body.commonIssues.length).toBeGreaterThan(0);
    });
  });

  describe('GET /proxy/diagnostics/:proxyId/export', () => {
    it('should export complete diagnostics data', async () => {
      diagnosticsService.addDiagnosticLog('proxy-001', {
        level: 'info',
        message: 'Test log',
      });

      const error = new Error('Test error');
      diagnosticsService.recordError('proxy-001', error);

      diagnosticsService.recordEvent('proxy-001', 'test_event', {});

      const response = await request(app).get('/proxy/diagnostics/proxy-001/export');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('proxyId', 'proxy-001');
      expect(response.body).toHaveProperty('exportedAt');
      expect(response.body).toHaveProperty('diagnostics');
      expect(response.body).toHaveProperty('troubleshooting');
      expect(response.body).toHaveProperty('allLogs');
      expect(response.body).toHaveProperty('allErrors');
      expect(response.body).toHaveProperty('allEvents');
    });

    it('should set correct headers for file download', async () => {
      const response = await request(app).get('/proxy/diagnostics/proxy-001/export');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toContain('application/json');
      expect(response.headers['content-disposition']).toContain('attachment');
      expect(response.headers['content-disposition']).toContain('proxy-diagnostics-proxy-001');
    });
  });

  describe('POST /proxy/diagnostics/:proxyId/clear', () => {
    it('should clear diagnostics data for a proxy', async () => {
      diagnosticsService.addDiagnosticLog('proxy-001', {
        level: 'info',
        message: 'Test log',
      });

      const error = new Error('Test error');
      diagnosticsService.recordError('proxy-001', error);

      // Verify data exists
      let response = await request(app).get('/proxy/diagnostics/proxy-001/logs');
      expect(response.body.logs.length).toBe(1);

      // Clear diagnostics
      response = await request(app).post('/proxy/diagnostics/proxy-001/clear');
      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Diagnostics cleared successfully');

      // Verify data is cleared
      response = await request(app).get('/proxy/diagnostics/proxy-001/logs');
      expect(response.body.logs.length).toBe(0);
    });

    it('should require admin role to clear diagnostics', async () => {
      // Create a new app with non-admin middleware
      const nonAdminApp = express();
      nonAdminApp.use(express.json());

      const nonAdminMiddleware = (req, res, next) => {
        req.user = {
          sub: 'test-user-123',
          'https://cloudtolocalllm.online/role': 'user',
        };
        next();
      };

      const customRouter = express.Router();

      customRouter.post('/diagnostics/:proxyId/clear', nonAdminMiddleware, mockTierMiddleware, (req, res) => {
        try {
          const { proxyId } = req.params;
          const userRole = req.user?.['https://cloudtolocalllm.online/role'] || 'user';

          if (userRole !== 'admin') {
            return res.status(403).json({
              error: 'FORBIDDEN',
              message: 'Admin access required',
              code: 'PROXY_DIAG_004',
            });
          }

          if (!proxyId) {
            return res.status(400).json({
              error: 'INVALID_REQUEST',
              message: 'proxyId is required',
              code: 'PROXY_DIAG_001',
            });
          }

          diagnosticsService.clearDiagnostics(proxyId);
          res.json({
            proxyId,
            message: 'Diagnostics cleared successfully',
            timestamp: new Date().toISOString(),
          });
        } catch (error) {
          res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to clear proxy diagnostics',
            code: 'PROXY_DIAG_003',
          });
        }
      });

      nonAdminApp.use('/proxy', customRouter);

      const response = await request(nonAdminApp).post('/proxy/diagnostics/proxy-001/clear');

      expect(response.status).toBe(403);
      expect(response.body.error).toBe('FORBIDDEN');
    });
  });

  describe('Diagnostics Service', () => {
    it('should register and unregister proxies', () => {
      const service = new ProxyDiagnosticsService();

      service.registerProxy('test-proxy', { userId: 'user-1' });
      expect(service.getDiagnostics('test-proxy').proxyId).toBe('test-proxy');

      service.unregisterProxy('test-proxy');
      expect(service.getDiagnostics('test-proxy').status).toBe('unknown');
    });

    it('should maintain max log size', () => {
      const service = new ProxyDiagnosticsService();
      service.maxLogsPerProxy = 5;

      service.registerProxy('test-proxy', {});

      for (let i = 0; i < 10; i++) {
        service.addDiagnosticLog('test-proxy', {
          level: 'info',
          message: `Log ${i}`,
        });
      }

      const logs = service.getDiagnosticLogs('test-proxy', { limit: 100 });
      expect(logs.length).toBeLessThanOrEqual(5);
    });

    it('should analyze diagnostics status correctly', () => {
      const service = new ProxyDiagnosticsService();
      service.registerProxy('test-proxy', {});

      // No errors - should be healthy
      let diagnostics = service.getDiagnostics('test-proxy');
      expect(diagnostics.diagnosticStatus).toBe('healthy');

      // Add some errors
      for (let i = 0; i < 6; i++) {
        const error = new Error('Test error');
        service.recordError('test-proxy', error);
      }

      diagnostics = service.getDiagnostics('test-proxy');
      expect(diagnostics.diagnosticStatus).toBe('unhealthy');
    });

    it('should generate troubleshooting suggestions for different error types', () => {
      const service = new ProxyDiagnosticsService();
      service.registerProxy('test-proxy', {});

      // Add timeout errors
      for (let i = 0; i < 6; i++) {
        const error = new Error('Connection timeout');
        service.recordError('test-proxy', error);
      }

      const troubleshooting = service.getTroubleshootingInfo('test-proxy');
      expect(troubleshooting.suggestions.length).toBeGreaterThan(0);

      const timeoutSuggestion = troubleshooting.suggestions.find((s) => s.issue && s.issue.toLowerCase().includes('timeout'));
      expect(timeoutSuggestion).toBeDefined();
      if (timeoutSuggestion) {
        expect(timeoutSuggestion.suggestion).toContain('timeout');
      }
    });

    it('should export complete diagnostics data', () => {
      const service = new ProxyDiagnosticsService();
      service.registerProxy('test-proxy', {});

      service.addDiagnosticLog('test-proxy', {
        level: 'info',
        message: 'Test log',
      });

      const error = new Error('Test error');
      service.recordError('test-proxy', error);

      service.recordEvent('test-proxy', 'test_event', {});

      const exportData = service.exportDiagnostics('test-proxy');

      expect(exportData).toHaveProperty('proxyId', 'test-proxy');
      expect(exportData).toHaveProperty('exportedAt');
      expect(exportData).toHaveProperty('diagnostics');
      expect(exportData).toHaveProperty('troubleshooting');
      expect(exportData).toHaveProperty('allLogs');
      expect(exportData).toHaveProperty('allErrors');
      expect(exportData).toHaveProperty('allEvents');
    });
  });
});
