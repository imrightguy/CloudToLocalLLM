import express from 'express';
import http from 'http';
import { WebSocketServer } from 'ws';
import fetch from 'node-fetch';
import jwt from 'jsonwebtoken';

const app = express();
const server = http.createServer(app);

const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'abc12d491e2bc24a60e9e276be8d5b1af62bf';

app.get('/health', (req, res) => {
  res.send({ status: 'healthy', timestamp: new Date().toISOString() });
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

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const userId = decoded.sub || decoded.userId;
    console.log(`Tailscale Relay: Connection for user ${userId} to ${targetIp}`);

    ws.on('message', async (message) => {
      try {
        // Forward request to local Ollama on the Tailscale device
        // Defaulting to Ollama port 11434
        const response = await fetch(`http://${targetIp}:11434/api/generate`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: message
        });

        const data = await response.buffer();
        ws.send(data);
      } catch (error) {
        console.error(`Tailscale Relay: Forward error to ${targetIp}`, error.message);
        ws.send(JSON.stringify({ error: 'Failed to forward to target device', details: error.message }));
      }
    });

  } catch (error) {
    console.error('Tailscale Relay: Auth failed', error.message);
    ws.close(1008, 'Authentication failed');
  }
});

server.listen(PORT, () => {
  console.log(`Tailscale Relay listening on port ${PORT}`);
});
