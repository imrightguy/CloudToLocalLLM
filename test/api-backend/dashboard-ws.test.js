import { jest, describe, it, expect, beforeEach } from '@jest/globals';

const mockGetPool = jest.fn();
jest.unstable_mockModule(
  '../../services/api-backend/database/db-pool.js',
  () => ({
    getPool: mockGetPool,
  }),
);

const { default: dashboardWSManager } = await import(
  '../../services/api-backend/websocket/dashboard-ws.js'
);

describe('DashboardWebSocketManager', () => {
  let mockLogger;

  beforeEach(() => {
    jest.clearAllMocks();
    mockLogger = { info: jest.fn(), error: jest.fn() };
    dashboardWSManager.clients = new Map();
    dashboardWSManager.logger = mockLogger;
  });

  describe('broadcast', () => {
    it('should send to specific user clients with open connections', () => {
      const mockWs = { readyState: 1, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([mockWs]));

      dashboardWSManager.broadcast({ type: 'test' }, 'user1');

      expect(mockWs.send).toHaveBeenCalledWith('{"type":"test"}');
    });

    it('should skip non-open connections for specific user', () => {
      const mockWs = { readyState: 0, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([mockWs]));

      dashboardWSManager.broadcast({ type: 'test' }, 'user1');

      expect(mockWs.send).not.toHaveBeenCalled();
    });

    it('should broadcast to all users when no target specified', () => {
      const mockWs1 = { readyState: 1, send: jest.fn() };
      const mockWs2 = { readyState: 1, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([mockWs1]));
      dashboardWSManager.clients.set('user2', new Set([mockWs2]));

      dashboardWSManager.broadcast({ type: 'test' });

      expect(mockWs1.send).toHaveBeenCalledWith('{"type":"test"}');
      expect(mockWs2.send).toHaveBeenCalledWith('{"type":"test"}');
    });

    it('should skip closed connections on global broadcast', () => {
      const open = { readyState: 1, send: jest.fn() };
      const closed = { readyState: 3, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([open, closed]));

      dashboardWSManager.broadcast({ type: 'test' });

      expect(open.send).toHaveBeenCalled();
      expect(closed.send).not.toHaveBeenCalled();
    });

    it('should handle unknown target user gracefully', () => {
      expect(() =>
        dashboardWSManager.broadcast({ type: 'test' }, 'unknown'),
      ).not.toThrow();
    });

    it('should handle empty clients map', () => {
      expect(() =>
        dashboardWSManager.broadcast({ type: 'test' }),
      ).not.toThrow();
    });

    it('should skip connecting state (readyState 0)', () => {
      const mockWs = { readyState: 0, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([mockWs]));

      dashboardWSManager.broadcast({ type: 'test' }, 'user1');

      expect(mockWs.send).not.toHaveBeenCalled();
    });

    it('should skip closing state (readyState 2)', () => {
      const mockWs = { readyState: 2, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([mockWs]));

      dashboardWSManager.broadcast({ type: 'test' }, 'user1');

      expect(mockWs.send).not.toHaveBeenCalled();
    });

    it('should send complex data objects', () => {
      const mockWs = { readyState: 1, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([mockWs]));

      const data = {
        type: 'agent_update',
        agent: { id: 1, name: 'Zoidbot', status: 'active' },
        timestamp: 1234567890,
      };
      dashboardWSManager.broadcast(data, 'user1');

      expect(mockWs.send).toHaveBeenCalledWith(JSON.stringify(data));
    });

    it('should broadcast to multiple clients of same user', () => {
      const ws1 = { readyState: 1, send: jest.fn() };
      const ws2 = { readyState: 1, send: jest.fn() };
      const ws3 = { readyState: 3, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([ws1, ws2, ws3]));

      dashboardWSManager.broadcast({ type: 'update' }, 'user1');

      expect(ws1.send).toHaveBeenCalled();
      expect(ws2.send).toHaveBeenCalled();
      expect(ws3.send).not.toHaveBeenCalled();
    });

    it('should only broadcast to target user in multi-user scenario', () => {
      const ws1 = { readyState: 1, send: jest.fn() };
      const ws2 = { readyState: 1, send: jest.fn() };
      dashboardWSManager.clients.set('user1', new Set([ws1]));
      dashboardWSManager.clients.set('user2', new Set([ws2]));

      dashboardWSManager.broadcast({ type: 'private' }, 'user1');

      expect(ws1.send).toHaveBeenCalledWith('{"type":"private"}');
      expect(ws2.send).not.toHaveBeenCalled();
    });
  });

  describe('sendAgentList', () => {
    it('should query agents and send to ws', async () => {
      const mockWs = { send: jest.fn() };
      mockGetPool.mockReturnValue({
        query: jest.fn().mockResolvedValue({
          rows: [{ id: 1, name: 'agent1' }],
        }),
      });

      await dashboardWSManager.sendAgentList(mockWs, 'user1');

      expect(mockGetPool).toHaveBeenCalled();
      expect(mockWs.send).toHaveBeenCalledWith(
        '{"type":"agent_list","agents":[{"id":1,"name":"agent1"}]}',
      );
    });

    it('should handle query errors gracefully', async () => {
      const mockWs = { send: jest.fn() };
      mockGetPool.mockReturnValue({
        query: jest.fn().mockRejectedValue(new Error('db error')),
      });

      await dashboardWSManager.sendAgentList(mockWs, 'user1');

      expect(mockWs.send).not.toHaveBeenCalled();
      expect(mockLogger.error).toHaveBeenCalledWith(
        'Dashboard WS: Failed to send agent list',
        { error: 'db error' },
      );
    });

    it('should query with correct user_id parameter', async () => {
      const mockWs = { send: jest.fn() };
      const mockQuery = jest.fn().mockResolvedValue({ rows: [] });
      mockGetPool.mockReturnValue({ query: mockQuery });

      await dashboardWSManager.sendAgentList(mockWs, 'user123');

      expect(mockQuery).toHaveBeenCalledWith(
        'SELECT * FROM agents WHERE user_id = $1 OR user_id IS NULL',
        ['user123'],
      );
    });

    it('should send empty agent list when no agents found', async () => {
      const mockWs = { send: jest.fn() };
      mockGetPool.mockReturnValue({
        query: jest.fn().mockResolvedValue({ rows: [] }),
      });

      await dashboardWSManager.sendAgentList(mockWs, 'user1');

      expect(mockWs.send).toHaveBeenCalledWith(
        '{"type":"agent_list","agents":[]}',
      );
    });

    it('should send multiple agents in list', async () => {
      const mockWs = { send: jest.fn() };
      const agents = [
        { id: 1, name: 'agent1', status: 'active' },
        { id: 2, name: 'agent2', status: 'idle' },
        { id: 3, name: 'global-agent', user_id: null },
      ];
      mockGetPool.mockReturnValue({
        query: jest.fn().mockResolvedValue({ rows: agents }),
      });

      await dashboardWSManager.sendAgentList(mockWs, 'user1');

      expect(mockWs.send).toHaveBeenCalledWith(
        JSON.stringify({ type: 'agent_list', agents }),
      );
    });

    it('should log connection errors without throwing', async () => {
      const mockWs = { send: jest.fn() };
      mockGetPool.mockReturnValue({
        query: jest.fn().mockRejectedValue(new Error('connection refused')),
      });

      await expect(
        dashboardWSManager.sendAgentList(mockWs, 'user1'),
      ).resolves.not.toThrow();

      expect(mockLogger.error).toHaveBeenCalledWith(
        'Dashboard WS: Failed to send agent list',
        { error: 'connection refused' },
      );
    });
  });

  describe('client management', () => {
    it('should start with empty clients map', () => {
      expect(dashboardWSManager.clients.size).toBe(0);
    });

    it('should allow setting clients directly for testing', () => {
      const mockWs = { readyState: 1 };
      dashboardWSManager.clients.set('user1', new Set([mockWs]));

      expect(dashboardWSManager.clients.get('user1').size).toBe(1);
    });

    it('should support removing individual clients', () => {
      const ws1 = { readyState: 1 };
      const ws2 = { readyState: 1 };
      const clientSet = new Set([ws1, ws2]);
      dashboardWSManager.clients.set('user1', clientSet);

      clientSet.delete(ws1);

      expect(clientSet.size).toBe(1);
      expect(clientSet.has(ws2)).toBe(true);
    });

    it('should allow cleaning up empty user entries', () => {
      const clientSet = new Set();
      dashboardWSManager.clients.set('user1', clientSet);

      dashboardWSManager.clients.delete('user1');

      expect(dashboardWSManager.clients.has('user1')).toBe(false);
    });
  });
});
