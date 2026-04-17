import { WebSocketServer } from 'ws';
import { getPool } from '../database/db-pool.js';
import jwt from 'jsonwebtoken';

class DashboardWebSocketManager {
  constructor() {
    this.clients = new Map(); // userId -> Set<WebSocket>
    this.wss = null;
    this.logger = null;
  }

  initialize(server, logger) {
    this.logger = logger;
    this.wss = new WebSocketServer({ noServer: true });

    this.wss.on('connection', (ws, req) => {
      const userId = req.userId;

      if (!this.clients.has(userId)) {
        this.clients.set(userId, new Set());
      }
      this.clients.get(userId).add(ws);

      this.logger.info(`Dashboard WS: Client connected for user ${userId}`);

      ws.on('close', () => {
        const userClients = this.clients.get(userId);
        if (userClients) {
          userClients.delete(ws);
          if (userClients.size === 0) {
            this.clients.delete(userId);
          }
        }
        this.logger.info(
          `Dashboard WS: Client disconnected for user ${userId}`,
        );
      });

      // Send initial agent list
      this.sendAgentList(ws, userId);
    });
  }

  async handleUpgrade(request, socket, head) {
    // Extract token from query string
    const url = new URL(request.url, `http://${request.headers.host}`);
    const token = url.searchParams.get('token');

    if (!token) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    try {
      const secret = process.env.JWT_SECRET;
      if (!secret) {
        throw new Error('JWT_SECRET not configured');
      }
      const decoded = jwt.verify(token, secret);
      request.userId = decoded.sub || decoded.userId || 'system';

      this.wss.handleUpgrade(request, socket, head, (ws) => {
        this.wss.emit('connection', ws, request);
      });
    } catch (error) {
      this.logger.error('Dashboard WS: Auth failed', { error: error.message });
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
    }
  }

  broadcast(data, targetUserId = null) {
    const message = JSON.stringify(data);

    if (targetUserId) {
      const userClients = this.clients.get(targetUserId);
      if (userClients) {
        userClients.forEach((ws) => {
          if (ws.readyState === 1) {
            ws.send(message);
          }
        });
      }
    } else {
      this.clients.forEach((userClients) => {
        userClients.forEach((ws) => {
          if (ws.readyState === 1) {
            ws.send(message);
          }
        });
      });
    }
  }

  async sendAgentList(ws, userId) {
    const pool = getPool();
    try {
      const result = await pool.query(
        'SELECT * FROM agents WHERE user_id = $1 OR user_id IS NULL',
        [userId],
      );
      ws.send(
        JSON.stringify({
          type: 'agent_list',
          agents: result.rows,
        }),
      );
    } catch (error) {
      this.logger.error('Dashboard WS: Failed to send agent list', {
        error: error.message,
      });
    }
  }
}

const dashboardWSManager = new DashboardWebSocketManager();
export default dashboardWSManager;
export { dashboardWSManager };
