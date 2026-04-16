import { jest } from '@jest/globals';

const mockQuery = jest.fn();
const mockGetPool = jest.fn();
const mockClosePool = jest.fn();
const mockLogger = { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn() };

jest.unstable_mockModule('../../services/api-backend/logger.js', () => ({
  default: mockLogger,
}));

jest.unstable_mockModule('../../services/api-backend/database/db-pool.js', () => ({
  getPool: mockGetPool,
  closePool: mockClosePool,
}));

const { logAdminAction, auditMiddleware, queryAuditLogs, getAuditLogById, closeAuditDbPool } =
  await import('../../services/api-backend/utils/audit-logger.js');

describe('audit-logger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockQuery.mockReset();
    mockQuery.mockResolvedValue({ rows: [{ id: 'log-1', admin_user_id: 'admin-1' }] });
    mockGetPool.mockReturnValue({ query: mockQuery });
  });

  describe('logAdminAction', () => {
    const baseParams = {
      adminUserId: 'admin-1',
      adminRole: 'super_admin',
      action: 'user_suspended',
      resourceType: 'user',
      resourceId: 'user-42',
    };

    it('inserts audit log with required params and returns the row', async () => {
      const result = await logAdminAction(baseParams);
      expect(mockQuery).toHaveBeenCalledTimes(1);
      expect(mockQuery.mock.calls[0][1]).toEqual([
        'admin-1', 'super_admin', 'user_suspended', 'user', 'user-42',
        null, '{}', null, null,
      ]);
      expect(result).toEqual({ id: 'log-1', admin_user_id: 'admin-1' });
      expect(mockLogger.info).toHaveBeenCalledWith(
        expect.stringContaining('Admin action logged'),
        expect.objectContaining({ adminUserId: 'admin-1', action: 'user_suspended' }),
      );
    });

    it('passes optional params correctly', async () => {
      const params = {
        ...baseParams,
        affectedUserId: 'user-99',
        details: { reason: 'tos_violation' },
        ipAddress: '10.0.0.1',
        userAgent: 'TestAgent/1.0',
      };
      await logAdminAction(params);
      const args = mockQuery.mock.calls[0][1];
      expect(args[5]).toBe('user-99');
      expect(args[6]).toBe(JSON.stringify({ reason: 'tos_violation' }));
      expect(args[7]).toBe('10.0.0.1');
      expect(args[8]).toBe('TestAgent/1.0');
    });

    it('returns null and logs error on missing required params', async () => {
      const result = await logAdminAction({ adminUserId: 'admin-1' });
      expect(result).toBeNull();
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to log admin action'),
        expect.objectContaining({ error: 'Missing required audit log parameters' }),
      );
    });

    it('returns null and logs error when DB query fails', async () => {
      mockQuery.mockRejectedValue(new Error('DB connection lost'));
      const result = await logAdminAction(baseParams);
      expect(result).toBeNull();
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to log admin action'),
        expect.objectContaining({ error: 'DB connection lost' }),
      );
    });

    it('each missing required param returns null and logs error', async () => {
      const required = ['adminUserId', 'adminRole', 'action', 'resourceType', 'resourceId'];
      for (const field of required) {
        jest.clearAllMocks();
        mockQuery.mockReset();
        mockQuery.mockResolvedValue({ rows: [{ id: 'log-1' }] });
        mockGetPool.mockReturnValue({ query: mockQuery });
        const params = { ...baseParams, [field]: undefined };
        const result = await logAdminAction(params);
        expect(result).toBeNull();
        expect(mockLogger.error).toHaveBeenCalled();
      }
    });
  });

  describe('auditMiddleware', () => {
    function createMocks(overrides = {}) {
      const req = {
        adminUser: { id: 'admin-1' },
        adminRoles: ['super_admin'],
        params: { id: 'res-1', userId: 'user-42' },
        ip: '10.0.0.1',
        get: jest.fn((header) => (header === 'User-Agent' ? 'Test/1.0' : null)),
        ...overrides,
      };
      const res = {
        statusCode: 200,
        send: jest.fn(),
        get: jest.fn(),
        set: jest.fn(),
      };
      const next = jest.fn();
      return { req, res, next };
    }

    it('calls next and does not log on non-2xx status', async () => {
      const { req, res, next } = createMocks();
      res.statusCode = 404;
      const middleware = auditMiddleware({ action: 'test', resourceType: 'user' });
      middleware(req, res, next);
      expect(next).toHaveBeenCalled();
      await new Promise((r) => setTimeout(r, 50));
      expect(mockQuery).not.toHaveBeenCalled();
    });

    it('calls next immediately without waiting for audit log', () => {
      const { req, res, next } = createMocks();
      const middleware = auditMiddleware({ action: 'test_action', resourceType: 'user' });
      middleware(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    it('logs audit action on 2xx response', async () => {
      const { req, res, next } = createMocks();
      const middleware = auditMiddleware({ action: 'user_banned', resourceType: 'user' });
      middleware(req, res, next);

      res.send({ ok: true });

      await new Promise((r) => setTimeout(r, 200));
      expect(mockLogger.info).toHaveBeenCalledWith(
        expect.stringContaining('Admin action logged'),
        expect.objectContaining({ action: 'user_banned' }),
      );
    });

    it('does not log if adminUser is missing', async () => {
      const { req, res, next } = createMocks();
      delete req.adminUser;
      const middleware = auditMiddleware({ action: 'test', resourceType: 'user' });
      middleware(req, res, next);

      res.send({ ok: true });
      await new Promise((r) => setTimeout(r, 100));
      expect(mockQuery).not.toHaveBeenCalled();
    });

    it('does not log if resourceId is missing', async () => {
      const { req, res, next } = createMocks();
      delete req.params.id;
      delete req.params.userId;
      delete req.params.resourceId;
      const middleware = auditMiddleware({ action: 'test', resourceType: 'user' });
      middleware(req, res, next);

      res.send({ ok: true });
      await new Promise((r) => setTimeout(r, 100));
      expect(mockQuery).not.toHaveBeenCalled();
    });

    it('uses custom getResourceId function', async () => {
      const { req, res, next } = createMocks();
      const customGetId = jest.fn(() => 'custom-res-123');
      const middleware = auditMiddleware({
        action: 'test',
        resourceType: 'user',
        getResourceId: customGetId,
      });
      middleware(req, res, next);
      res.send({ ok: true });

      await new Promise((r) => setTimeout(r, 200));
      expect(customGetId).toHaveBeenCalledWith(req);
    });

    it('uses custom getAffectedUserId function', async () => {
      const { req, res, next } = createMocks();
      const customGetAffected = jest.fn(() => 'affected-999');
      const middleware = auditMiddleware({
        action: 'test',
        resourceType: 'user',
        getAffectedUserId: customGetAffected,
      });
      middleware(req, res, next);
      res.send({ ok: true });

      await new Promise((r) => setTimeout(r, 200));
      expect(customGetAffected).toHaveBeenCalledWith(req);
    });

    it('uses custom getDetails function', async () => {
      const { req, res, next } = createMocks();
      const customDetails = jest.fn(() => ({ foo: 'bar' }));
      const middleware = auditMiddleware({
        action: 'test',
        resourceType: 'user',
        getDetails: customDetails,
      });
      middleware(req, res, next);
      res.send({ ok: true });

      await new Promise((r) => setTimeout(r, 200));
      expect(customDetails).toHaveBeenCalledWith(req);
    });
  });

  describe('queryAuditLogs', () => {
    it('queries with no filters using defaults', async () => {
      mockQuery.mockResolvedValue({ rows: [{ id: '1' }] });
      const results = await queryAuditLogs();
      expect(mockQuery).toHaveBeenCalledTimes(1);
      const [sql, params] = mockQuery.mock.calls[0];
      expect(sql).toContain('SELECT * FROM admin_audit_logs');
      expect(sql).toContain('ORDER BY created_at DESC');
      expect(params).toEqual([100, 0]);
      expect(results).toEqual([{ id: '1' }]);
    });

    it('builds WHERE clause from all filters', async () => {
      mockQuery.mockResolvedValue({ rows: [] });
      await queryAuditLogs({
        adminUserId: 'admin-1',
        action: 'user_suspended',
        resourceType: 'user',
        affectedUserId: 'user-42',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      });
      const [sql, params] = mockQuery.mock.calls[0];
      expect(sql).toContain('WHERE');
      expect(sql).toContain('admin_user_id = $1');
      expect(sql).toContain('action = $2');
      expect(sql).toContain('resource_type = $3');
      expect(sql).toContain('affected_user_id = $4');
      expect(sql).toContain('created_at >= $5');
      expect(sql).toContain('created_at <= $6');
      expect(params).toEqual(['admin-1', 'user_suspended', 'user', 'user-42', '2025-01-01', '2025-12-31', 100, 0]);
    });

    it('applies custom limit and offset', async () => {
      mockQuery.mockResolvedValue({ rows: [] });
      await queryAuditLogs({ limit: 50, offset: 200 });
      const params = mockQuery.mock.calls[0][1];
      expect(params).toContain(50);
      expect(params).toContain(200);
    });

    it('throws and logs error on DB failure', async () => {
      mockQuery.mockRejectedValue(new Error('query failed'));
      await expect(queryAuditLogs({ action: 'test' })).rejects.toThrow('query failed');
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to query audit logs'),
        expect.objectContaining({ error: 'query failed' }),
      );
    });
  });

  describe('getAuditLogById', () => {
    it('returns the log entry when found', async () => {
      mockQuery.mockResolvedValue({ rows: [{ id: 'log-1', action: 'test' }] });
      const result = await getAuditLogById('log-1');
      expect(mockQuery).toHaveBeenCalledWith(
        'SELECT * FROM admin_audit_logs WHERE id = $1',
        ['log-1'],
      );
      expect(result).toEqual({ id: 'log-1', action: 'test' });
    });

    it('returns null when no log found', async () => {
      mockQuery.mockResolvedValue({ rows: [] });
      const result = await getAuditLogById('nonexistent');
      expect(result).toBeNull();
    });

    it('throws and logs error on DB failure', async () => {
      mockQuery.mockRejectedValue(new Error('connection refused'));
      await expect(getAuditLogById('log-1')).rejects.toThrow('connection refused');
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to get audit log'),
        expect.objectContaining({ logId: 'log-1' }),
      );
    });
  });

  describe('closeAuditDbPool', () => {
    it('delegates to closePool', async () => {
      await closeAuditDbPool();
      expect(mockClosePool).toHaveBeenCalledTimes(1);
    });
  });
});
