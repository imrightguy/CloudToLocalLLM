import { WebSocketServer } from 'ws';
import logger from '../logger.js';

class DashboardWebSocketService {
  constructor() {
    this.wss = null;
    this.clients = new Map(); // userId -> Set of WS connections
    this.authService = null;
  }

  initialize(server, authService) {
    this.authService = authService;
    this.wss = new WebSocketServer({ noServer: true });

    this.wss.on('connection', (ws, req, userId) => {
      logger.info(`[DashboardWS] Client connected: ${userId}`);

      if (!this.clients.has(userId)) {
        this.clients.set(userId, new Set());
      }
      this.clients.get(userId).add(ws);

      ws.on('close', () => {
        logger.info(`[DashboardWS] Client disconnected: ${userId}`);
        const userConnections = this.clients.get(userId);
        if (userConnections) {
          userConnections.delete(ws);
          if (userConnections.size === 0) {
            this.clients.delete(userId);
          }
        }
      });

      ws.on('error', (error) => {
        logger.error(
          `[DashboardWS] Connection error for user ${userId}:`,
          error,
        );
      });

      // Send initial heartbeat
      ws.send(
        JSON.stringify({
          type: 'connected',
          timestamp: new Date().toISOString(),
        }),
      );
    });

    logger.info('[DashboardWS] Service initialized');
  }

  async handleUpgrade(request, socket, head) {
    const url = new URL(request.url, `http://${request.headers.host}`);
    const token = url.searchParams.get('token');

    if (!token) {
      logger.warn('[DashboardWS] Upgrade rejected: No token provided');
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    if (!this.authService) {
      logger.error('[DashboardWS] Auth service not available');
      socket.write('HTTP/1.1 503 Service Unavailable\r\n\r\n');
      socket.destroy();
      return;
    }

    try {
      const payload = await this.authService.validateTokenForWebSocket(token);
      const userId = payload.sub;

      this.wss.handleUpgrade(request, socket, head, (ws) => {
        this.wss.emit('connection', ws, request, userId);
      });
    } catch (error) {
      logger.warn('[DashboardWS] Upgrade rejected: Invalid token', {
        error: error.message,
      });
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
    }
  }

  /**
   * Broadcast an event to a specific user
   */
  broadcastToUser(userId, data) {
    const userConnections = this.clients.get(userId);
    if (userConnections) {
      const message = JSON.stringify(data);
      userConnections.forEach((ws) => {
        if (ws.readyState === 1) {
          // OPEN
          ws.send(message);
        }
      });
    }
  }

  /**
   * Broadcast an event to all connected users
   * Useful for system-wide notifications
   */
  broadcastToAll(data) {
    const message = JSON.stringify(data);
    this.clients.forEach((userConnections) => {
      userConnections.forEach((ws) => {
        if (ws.readyState === 1) {
          // OPEN
          ws.send(message);
        }
      });
    });
  }
}

export const dashboardWebSocketService = new DashboardWebSocketService();
