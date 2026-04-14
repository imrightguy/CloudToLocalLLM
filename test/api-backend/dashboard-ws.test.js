import { jest, describe, it, expect, beforeEach } from '@jest/globals';

jest.unstable_mockModule('ws', () => ({
  WebSocketServer: jest.fn().mockImplementation(() => ({
    on: jest.fn(),
    handleUpgrade: jest.fn(),
    emit: jest.fn(),
  })),
}));

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
  });
});
