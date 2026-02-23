/**
 * Tailscale Relay Server Template
 * WebSocket relay for Tailscale tunnel connections to local LLM providers
 *
 * Usage:
 *   PORT=3002 JWT_SECRET=your-secret node relay-server.js
 *
 * Environment Variables:
 *   PORT - Server port (default: 3002)
 *   JWT_SECRET - Secret key for JWT verification (required)
 *   TARGET_PORT - Target service port (default: 11434 for Ollama)
 */

import express from 'express';
import http from 'http';
import { WebSocketServer } from 'ws';
import fetch from 'node-fetch';
import jwt from 'jsonwebtoken';

const app = express();
const server = http.createServer(app);

const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'changeme-in-production';
const TARGET_PORT = process.env.TARGET_PORT || 11434;

// Request tracking
const activeConnections = new Map();

app.get('/health', (req, res) => {
  res.send({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    activeConnections: activeConnections.size
  });
});

app.get('/status', (req, res) => {
  res.send({
    activeConnections: activeConnections.size,
    connections: Array.from(activeConnections.keys())
  });
});

// WebSocket server for Tailscale connections
const wss = new WebSocketServer({
  server,
  path: '/tailscale/ws'
});

wss.on('connection', async (ws, req) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const token = url.searchParams.get('token');
  const targetIp = url.searchParams.get('targetIp');

  if (!token || !targetIp) {
    ws.close(1008, 'Missing token or targetIp');
    return;
  }

  let connectionId = null;

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const userId = decoded.sub || decoded.userId;
    connectionId = `${userId}-${Date.now()}`;

    activeConnections.set(connectionId, {
      userId,
      targetIp,
      connectedAt: new Date().toISOString()
    });

    console.log(`[${new Date().toISOString()}] Relay: ${connectionId} → ${targetIp}`);

    // Send connection confirmation
    ws.send(JSON.stringify({
      type: 'connected',
      connectionId,
      targetIp,
      targetPort: TARGET_PORT
    }));

    ws.on('message', async (message) => {
      try {
        const targetUrl = `http://${targetIp}:${TARGET_PORT}/api/generate`;
        const response = await fetch(targetUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: message
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.buffer();
        ws.send(data);
      } catch (error) {
        console.error(`[${new Date().toISOString()}] Relay error to ${targetIp}:`, error.message);
        ws.send(JSON.stringify({
          type: 'error',
          error: 'Forward failed',
          details: error.message,
          targetIp,
          targetPort: TARGET_PORT
        }));
      }
    });

    ws.on('close', () => {
      activeConnections.delete(connectionId);
      console.log(`[${new Date().toISOString()}] Relay: Disconnected ${connectionId}`);
    });

    ws.on('error', (error) => {
      console.error(`[${new Date().toISOString()}] WebSocket error for ${connectionId}:`, error.message);
      activeConnections.delete(connectionId);
    });

  } catch (error) {
    console.error('Relay auth failed:', error.message);
    ws.close(1008, 'Authentication failed');
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  wss.clients.forEach(ws => ws.close(1001, 'Server shutdown'));
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

server.listen(PORT, () => {
  console.log(`Tailscale Relay listening on port ${PORT}`);
  console.log(`WebSocket path: /tailscale/ws?token=<jwt>&targetIp=<ip>`);
  console.log(`Target port: ${TARGET_PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
